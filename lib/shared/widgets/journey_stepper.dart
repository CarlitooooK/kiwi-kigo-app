import 'package:flutter/material.dart';
import '../../core/theme/kigo_theme.dart';

/// The user-facing steps of the check-in journey.
///
/// Only the steps where the visitor actively *does* something are shown — data
/// entry, privacy consent, ID capture and photo. Background steps (processing,
/// waiting for host approval) are not part of the stepper because the visitor
/// has nothing to do there; showing them would only add anxiety.
enum JourneyStep {
  data, // name / phone / host / purpose (voice or touch form)
  consent, // privacy notice
  identity, // ID document capture
  photo; // selfie / face photo

  String get label {
    switch (this) {
      case JourneyStep.data:
        return 'Datos';
      case JourneyStep.consent:
        return 'Aviso';
      case JourneyStep.identity:
        return 'Identidad';
      case JourneyStep.photo:
        return 'Foto';
    }
  }
}

/// A slim horizontal progress indicator: numbered dots joined by a track,
/// with the current step highlighted and completed steps checked.
///
/// Drop it near the top of a form/capture screen:
/// ```dart
/// const JourneyStepper(current: JourneyStep.consent)
/// ```
class JourneyStepper extends StatelessWidget {
  const JourneyStepper({super.key, required this.current});

  final JourneyStep current;

  static const _steps = JourneyStep.values;

  @override
  Widget build(BuildContext context) {
    final currentIndex = _steps.indexOf(current);

    return Semantics(
      label:
          'Paso ${currentIndex + 1} de ${_steps.length}: ${current.label}',
      child: Row(
        children: [
          for (int i = 0; i < _steps.length; i++) ...[
            _Dot(
              index: i,
              label: _steps[i].label,
              state: i < currentIndex
                  ? _DotState.done
                  : (i == currentIndex ? _DotState.active : _DotState.upcoming),
            ),
            if (i < _steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: i < currentIndex
                      ? KigoTheme.kigo500
                      : KigoTheme.umbral200,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

enum _DotState { done, active, upcoming }

class _Dot extends StatelessWidget {
  const _Dot({
    required this.index,
    required this.label,
    required this.state,
  });

  final int index;
  final String label;
  final _DotState state;

  @override
  Widget build(BuildContext context) {
    final Color circleColor;
    final Color textColor;
    final Color labelColor;
    switch (state) {
      case _DotState.done:
        circleColor = KigoTheme.kigo500;
        textColor = KigoTheme.white;
        labelColor = KigoTheme.slate500;
        break;
      case _DotState.active:
        circleColor = KigoTheme.kigo500;
        textColor = KigoTheme.white;
        labelColor = KigoTheme.slate900;
        break;
      case _DotState.upcoming:
        circleColor = KigoTheme.umbral100;
        textColor = KigoTheme.slate500;
        labelColor = KigoTheme.slate500;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: state == _DotState.active
                ? Border.all(color: KigoTheme.kigo500.withValues(alpha: 0.35), width: 4)
                : null,
          ),
          alignment: Alignment.center,
          child: state == _DotState.done
              ? const Icon(Icons.check_rounded, size: 16, color: KigoTheme.white)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                state == _DotState.active ? FontWeight.w700 : FontWeight.w500,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
