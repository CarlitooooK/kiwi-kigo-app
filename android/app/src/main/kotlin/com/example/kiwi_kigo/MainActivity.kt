package com.example.kiwi_kigo

import android.app.PendingIntent
import android.content.Intent
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Proxy

/**
 * Kigo Welcome — F10 access-control bridge.
 *
 * Exposes the Telpo F10 hardware (door relay via PosUtil) to Dart through a
 * MethodChannel. We call PosUtil **via reflection** on purpose:
 *
 * - On the real F10 device, `com.common.pos.api.util.PosUtil` is provided by
 *   the system firmware, so reflection resolves it at runtime.
 * - On emulators / non-F10 phones the class is absent; reflection fails
 *   gracefully and we report `hardwareAvailable = false` instead of crashing.
 *
 * This keeps a single APK that runs everywhere (dev laptop, CI, and the F10),
 * which is exactly what we need for a 4-day build with limited device access.
 */
class MainActivity : FlutterActivity() {
    private val channel = "kigo.welcome/f10_door"
    private val kioskChannel = "kigo.welcome/kiosk"
    private val nfcChannel = "kigo.welcome/f10_nfc"

    // NFC. The Telpo F10 has a DEDICATED NFC reader exposed via the system
    // service "nfcrd" (wrapped by com.common.face.api.NfcRd_Utils in
    // PosUtil.jar). On Telpo kiosk hardware the standard android.nfc.NfcAdapter
    // exists but does NOT route tag events through the Android NFC stack, so we
    // MUST use NfcRd_Utils (listener onSwipe). We keep NfcAdapter only as a
    // fallback for non-F10 devices (e.g. a phone/tablet used as an extra kiosk).
    private var nfcRdManager: Any? = null // com.common.face.api.NfcRd_Utils
    private var nfcRdListener: Any? = null // dynamic proxy of NfcRdlistener
    private var nfcRdOpen = false

    // Standard Android NFC fallback (non-Telpo devices only).
    private var nfcAdapter: NfcAdapter? = null
    private var nfcPendingIntent: PendingIntent? = null

    private var nfcSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(isPosUtilAvailable())

                    // Opens the door relay. Optional `holdMs` keeps it open then
                    // closes it automatically (visitor walks through, relay resets).
                    "openDoor" -> {
                        val holdMs = (call.argument<Number>("holdMs"))?.toLong() ?: 0L
                        openDoor(holdMs, result)
                    }

                    "closeDoor" -> {
                        val ret = setRelayPower(0)
                        if (ret == 0) result.success(true)
                        else result.error("RELAY_ERROR", "closeDoor returned $ret", null)
                    }

                    // Turns the F10 status LED on/off with a given brightness.
                    // On the F10, PosUtil maps setLedLight(x) → controlLedBright(3, x),
                    // where x is the brightness (0 = off). We pass a high value
                    // when on so the LED shines bright (1 was dim). `brightness`
                    // overrides the default when provided.
                    "setLed" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        val brightness = call.argument<Number>("brightness")?.toInt() ?: 255
                        val ret = setLedLight(if (on) brightness else 0)
                        if (ret >= 0) result.success(true)
                        else result.error("LED_ERROR", "setLedLight returned $ret", null)
                    }

                    // Color LED via PosUtil.controlLedBright(type, progress) — the
                    // OFFICIAL method per the F10 manual. type: 0=red 1=green
                    // 2=blue 3=white. progress = brightness (0 = off). This is the
                    // SAME safe call used for the white LED — NOT setColorLed
                    // (setColorLedJNI crashes the F10).
                    "setLedColor" -> {
                        val type = call.argument<Number>("type")?.toInt() ?: 3
                        val progress = call.argument<Number>("progress")?.toInt() ?: 0
                        val ret = controlLedBright(type, progress)
                        if (ret >= 0) result.success(true)
                        else result.error("LED_ERROR", "controlLedBright returned $ret", null)
                    }

                    else -> result.notImplemented()
                }
            }

        // Kiosk (lock task) channel — pins the app so a visitor can't leave it
        // without the operator unpinning (PRD: "no sale del modo kiosko sin
        // clave de operador"). On a device provisioned as device-owner this is
        // fully locked; otherwise Android shows the standard screen-pinning
        // confirmation. Degrades safely if unsupported.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kioskChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            startLockTask()
                            result.success(true)
                        } catch (e: Throwable) {
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        try {
                            stopLockTask()
                            result.success(true)
                        } catch (e: Throwable) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // NFC stream — emits the hex UID of any card tapped on the F10 while the
        // Welcome screen is listening. Uses foreground dispatch so the running
        // app receives the tag instead of Android's default handler.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, nfcChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    nfcSink = events
                }

                override fun onCancel(arguments: Any?) {
                    nfcSink = null
                }
            })

        setupNfc()
    }

    /**
     * Prepares NFC. This F10 unit exposes the STANDARD Android NfcAdapter
     * (service `android.nfc.INfcAdapter`; the proprietary `nfcrd` reader is NOT
     * present on this firmware), and the manual confirms "use android common
     * NFC API". So NfcAdapter + foreground dispatch is the primary path. We
     * still try the dedicated NfcRd_Utils reader as a secondary option for
     * other Telpo units that expose it instead.
     *
     * NOTE: NFC must be enabled in Android settings. If it's off, enable it
     * (`adb shell svc nfc enable`, or Settings → Connected devices → NFC).
     */
    private fun setupNfc() {
        // Primary: standard Android NfcAdapter (present + correct on this F10).
        try {
            nfcAdapter = NfcAdapter.getDefaultAdapter(this)
            if (nfcAdapter != null) {
                val intent = Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
                nfcPendingIntent = PendingIntent.getActivity(this, 0, intent, flags)
                Log.d("F10NFC", "NfcAdapter present (enabled=${nfcAdapter?.isEnabled})")
            }
        } catch (_: Throwable) {
            nfcAdapter = null
        }

        // Secondary: the dedicated reader, only if NfcAdapter is absent. On this
        // F10 the constructor throws (no `nfcrd` service) → we just skip it.
        if (nfcAdapter == null) {
            try {
                val cls = Class.forName("com.common.face.api.NfcRd_Utils")
                val ctor = cls.getConstructor(android.content.Context::class.java)
                nfcRdManager = ctor.newInstance(this)
                Log.d("F10NFC", "NfcRd_Utils constructed")
            } catch (t: Throwable) {
                nfcRdManager = null
                val cause = (t as? java.lang.reflect.InvocationTargetException)?.targetException
                    ?: t.cause ?: t
                Log.d("F10NFC", "NfcRd_Utils unavailable: ${cause.javaClass.name}: ${cause.message}")
            }
        }
    }

    /** Builds a dynamic proxy implementing com.common.face.api.NfcRdlistener,
     *  whose onSwipe(cardId, type) forwards the card id to Dart. */
    private fun buildNfcRdListener(): Any? {
        return try {
            val listenerIface = Class.forName("com.common.face.api.NfcRdlistener")
            Proxy.newProxyInstance(
                listenerIface.classLoader,
                arrayOf(listenerIface),
                InvocationHandler { proxy, method, args ->
                    when (method.name) {
                        "onSwipe" -> {
                            // Signature: onSwipe(String cardId, int type)
                            val cardId = args?.getOrNull(0) as? String
                            if (!cardId.isNullOrBlank()) {
                                val uid = cardId.trim().uppercase()
                                Log.d("F10NFC", "onSwipe cardId=$uid")
                                runOnUiThread { nfcSink?.success(uid) }
                            }
                            null
                        }
                        // Handle Object methods so the reader can store the proxy
                        // in a list/observer without NPEs.
                        "hashCode" -> System.identityHashCode(proxy)
                        "equals" -> proxy === args?.getOrNull(0)
                        "toString" -> "NfcRdlistenerProxy"
                        else -> null
                    }
                },
            )
        } catch (t: Throwable) {
            Log.d("F10NFC", "buildNfcRdListener failed: ${t.javaClass.simpleName}")
            null
        }
    }

    /** Opens the F10 dedicated reader and registers the onSwipe listener. */
    private fun startNfcRd() {
        val mgr = nfcRdManager ?: return
        try {
            val ret = mgr.javaClass.getMethod("open").invoke(mgr) as? Int ?: -1
            nfcRdOpen = ret == 0
            Log.d("F10NFC", "NfcRd open() = $ret")
            if (nfcRdListener == null) nfcRdListener = buildNfcRdListener()
            val listener = nfcRdListener ?: return
            val listenerIface = Class.forName("com.common.face.api.NfcRdlistener")
            mgr.javaClass.getMethod("addListener", listenerIface).invoke(mgr, listener)
            Log.d("F10NFC", "NfcRd addListener registered")
        } catch (t: Throwable) {
            Log.d("F10NFC", "startNfcRd failed: ${t.javaClass.simpleName} ${t.message}")
        }
    }

    /** Removes listeners and closes the F10 dedicated reader. */
    private fun stopNfcRd() {
        val mgr = nfcRdManager ?: return
        try {
            runCatching { mgr.javaClass.getMethod("removeListeners").invoke(mgr) }
            if (nfcRdOpen) {
                runCatching { mgr.javaClass.getMethod("close").invoke(mgr) }
                nfcRdOpen = false
            }
        } catch (t: Throwable) {
            Log.d("F10NFC", "stopNfcRd failed: ${t.javaClass.simpleName}")
        }
    }

    override fun onResume() {
        super.onResume()
        if (nfcRdManager != null) {
            startNfcRd()
        } else {
            // Primary path: give this activity priority for NFC tags.
            try {
                nfcAdapter?.enableForegroundDispatch(this, nfcPendingIntent, null, null)
                Log.d("F10NFC", "foreground dispatch enabled (adapter enabled=${nfcAdapter?.isEnabled})")
            } catch (t: Throwable) {
                Log.d("F10NFC", "enableForegroundDispatch failed: ${t.javaClass.simpleName} ${t.message}")
            }
        }
    }

    override fun onPause() {
        super.onPause()
        if (nfcRdManager != null) {
            stopNfcRd()
        } else {
            try {
                nfcAdapter?.disableForegroundDispatch(this)
            } catch (_: Throwable) { /* ignore */ }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Only relevant for the NfcAdapter fallback path.
        if (nfcRdManager == null) handleNfcIntent(intent)
    }

    /** Fallback only: extracts the tag UID (hex) from an NfcAdapter intent. */
    private fun handleNfcIntent(intent: Intent) {
        val action = intent.action ?: return
        if (action != NfcAdapter.ACTION_TAG_DISCOVERED &&
            action != NfcAdapter.ACTION_TECH_DISCOVERED &&
            action != NfcAdapter.ACTION_NDEF_DISCOVERED
        ) {
            return
        }
        @Suppress("DEPRECATION")
        val tag: Tag? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
        } else {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        }
        val id = tag?.id ?: return
        val uid = id.joinToString("") { "%02X".format(it) }
        Log.d("F10NFC", "tag discovered → UID=$uid")
        runOnUiThread { nfcSink?.success(uid) }
    }

    /** True only on hardware where PosUtil is resolvable. */
    private fun isPosUtilAvailable(): Boolean {
        // PosUtil.jar is bundled in the APK, so Class.forName finds it on ANY
        // device — it does NOT tell us if we're on the real F10. Detect the
        // actual hardware by the device model instead (ro.internal.model = F10,
        // or manufacturer Telpo). On a tablet/phone this is false, which lets
        // the UI offer the camera-scan fallback.
        return try {
            val internal = getSystemProp("ro.internal.model")
            val model = android.os.Build.MODEL ?: ""
            val manufacturer = android.os.Build.MANUFACTURER ?: ""
            internal.equals("F10", ignoreCase = true) ||
                model.equals("F10", ignoreCase = true) ||
                manufacturer.contains("telpo", ignoreCase = true)
        } catch (_: Throwable) {
            false
        }
    }

    /** Reads an Android system property (e.g. ro.internal.model) reflectively. */
    private fun getSystemProp(key: String): String = try {
        val sp = Class.forName("android.os.SystemProperties")
        val get = sp.getMethod("get", String::class.java)
        (get.invoke(null, key) as? String) ?: ""
    } catch (_: Throwable) {
        ""
    }

    private fun openDoor(holdMs: Long, result: MethodChannel.Result) {
        val ret = setRelayPower(1)
        if (ret != 0) {
            result.error("RELAY_ERROR", "openDoor returned $ret", null)
            return
        }
        if (holdMs > 0) {
            // Close the relay after holdMs without blocking the platform thread.
            window.decorView.postDelayed({ setRelayPower(0) }, holdMs)
        }
        result.success(true)
    }

    /**
     * Calls PosUtil.setRelayPower(int) reflectively.
     * Returns 0 on success (per SDK), or a negative sentinel when the hardware
     * is unavailable / the call throws (-1 no class, -2 invocation error).
     */
    private fun setRelayPower(state: Int): Int = try {
        val posUtil = Class.forName("com.common.pos.api.util.PosUtil")
        val method = posUtil.getMethod("setRelayPower", Int::class.javaPrimitiveType)
        (method.invoke(null, state) as? Int) ?: -2
    } catch (_: ClassNotFoundException) {
        -1
    } catch (_: Throwable) {
        -2
    }

    /**
     * Calls PosUtil.setLedLight(int) reflectively — the F10's status LED.
     * On the F10 (ro.internal.model = "F10") the SDK routes this to
     * controlLedBright(3, x). Returns >= 0 on success, negative when the
     * hardware is unavailable / the call throws (-1 no class, -2 error).
     */
    private fun setLedLight(state: Int): Int = try {
        val posUtil = Class.forName("com.common.pos.api.util.PosUtil")
        val method = posUtil.getMethod("setLedLight", Int::class.javaPrimitiveType)
        (method.invoke(null, state) as? Int) ?: -2
    } catch (_: ClassNotFoundException) {
        -1
    } catch (_: Throwable) {
        -2
    }

    /**
     * Calls PosUtil.controlLedBright(int type, int progress) reflectively — the
     * OFFICIAL color-LED API per the F10 manual. type: 0=red, 1=green, 2=blue,
     * 3=white. progress = brightness (0 = off). Safe: this is the same call the
     * SDK routes setLedLight to, unlike setColorLed (which crashes the F10).
     */
    private fun controlLedBright(type: Int, progress: Int): Int = try {
        val posUtil = Class.forName("com.common.pos.api.util.PosUtil")
        val method = posUtil.getMethod(
            "controlLedBright",
            Int::class.javaPrimitiveType,
            Int::class.javaPrimitiveType,
        )
        (method.invoke(null, type, progress) as? Int) ?: -2
    } catch (_: ClassNotFoundException) {
        -1
    } catch (_: Throwable) {
        -2
    }
}
