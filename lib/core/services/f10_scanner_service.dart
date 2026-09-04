import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Captures scans from the F10's built-in barcode module.
///
/// HARDWARE FACT (verified via `getevent` on the F10): the scanner is a
/// "Newland Auto-ID NLS-CEM300-DK USB POS KBW" — a **keyboard-wedge** device.
/// It types the decoded QR/barcode as key events (ending in Enter), NOT through
/// PosUtil.barcode_scaner (that serial path returns null on this unit).
///
/// So we read it like a keyboard: [ScanKeyboardListener] wraps the screen in a
/// focused key listener that accumulates characters and fires [onScan] when the
/// terminating Enter arrives. Scanners type fast; a human typing on a soft
/// keyboard won't reach this widget (there are no text fields under it), so in
/// practice every burst here is a scan.
class ScanKeyboardListener extends StatefulWidget {
  const ScanKeyboardListener({
    super.key,
    required this.onScan,
    required this.child,
    this.minLength = 3,
    this.enabled = true,
  });

  /// Called with the decoded payload when a scan completes (Enter received).
  final void Function(String code) onScan;

  /// The screen content shown while listening.
  final Widget child;

  /// Ignore bursts shorter than this (noise / stray keys).
  final int minLength;

  /// When false the listener is inert — used while the user types manually so
  /// the on-screen keyboard reaches the TextField instead of being captured.
  final bool enabled;

  @override
  State<ScanKeyboardListener> createState() => _ScanKeyboardListenerState();
}

class _ScanKeyboardListenerState extends State<ScanKeyboardListener> {
  final FocusNode _focus = FocusNode();
  final StringBuffer _buffer = StringBuffer();

  @override
  void initState() {
    super.initState();
    _grabFocusIfEnabled();
  }

  @override
  void didUpdateWidget(ScanKeyboardListener old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !old.enabled) _grabFocusIfEnabled();
  }

  void _grabFocusIfEnabled() {
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString().trim();
      _buffer.clear();
      if (code.length >= widget.minLength) widget.onScan(code);
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch != null && ch.isNotEmpty && ch != '\n' && ch != '\r') {
      _buffer.write(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // When disabled (manual typing mode) the Focus never grabs focus and lets
    // all keys flow to the TextField.
    if (!widget.enabled) return widget.child;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: widget.child,
      ),
    );
  }
}
