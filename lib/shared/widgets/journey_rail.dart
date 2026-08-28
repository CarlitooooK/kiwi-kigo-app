import 'package:flutter/material.dart';
import '../../core/theme/kigo_theme.dart';

/// Step state in the JourneyRail.
enum JourneyStepState {
  completed,
  active,
  pending,
}

/// Configuration for a single step.
class JourneyStep {
  final String label;
  final IconData icon;
  final JourneyStepState state;

  const JourneyStep({
    required this.label,
    required this.icon,
    this.state = JourneyStepState.pending,
  });
}

/// JourneyRail — Always-visible left rail showing visitor progress.
///
/// Visual language:
/// - Completed: green circle with check icon
/// - Active: pulsing orange ring with icon
/// - Pending: gray circle with "Sin iniciar" label
///
/// The rail gives the visitor permanent context of where they are
/// in the process, reducing anxiety and building trust.
class JourneyRail extends StatelessWidget {
  final List<JourneyStep> steps;

  const JourneyRail({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: KigoTheme.white,
        border: Border(
          right: BorderSide(color: KigoTheme.umbral200, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kigo brand
              const Text(
                'Kigo Welcome',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: KigoTheme.kigo500,
                ),
              ),
              const SizedBox(height: 32),

              // Steps
              Expanded(
                child: ListView.builder(
                  itemCount: steps.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    final isLast = index == steps.length - 1;
                    return _RailStep(
                      step: step,
                      isLast: isLast,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailStep extends StatelessWidget {
  final JourneyStep step;
  final bool isLast;

  const _RailStep({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + connector line
          SizedBox(
            width: 32,
            child: Column(
              children: [
                _StepDot(state: step.state, icon: step.icon),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: step.state == JourneyStepState.completed
                          ? KigoTheme.green600.withValues(alpha: 0.3)
                          : KigoTheme.umbral200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Label
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: step.state == JourneyStepState.active
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: step.state == JourneyStepState.pending
                          ? KigoTheme.gray400
                          : KigoTheme.slate900,
                    ),
                  ),
                  if (step.state == JourneyStepState.pending)
                    const Text(
                      'Sin iniciar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: KigoTheme.gray400,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final JourneyStepState state;
  final IconData icon;

  const _StepDot({required this.state, required this.icon});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case JourneyStepState.completed:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: KigoTheme.green600,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 16,
            color: Colors.white,
          ),
        );

      case JourneyStepState.active:
        return _PulsingDot(icon: icon);

      case JourneyStepState.pending:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: KigoTheme.umbral100,
            shape: BoxShape.circle,
            border: Border.all(color: KigoTheme.umbral200, width: 1.5),
          ),
          child: Icon(icon, size: 14, color: KigoTheme.gray400),
        );
    }
  }
}

/// Pulsing orange ring for the active step.
class _PulsingDot extends StatefulWidget {
  final IconData icon;
  const _PulsingDot({required this.icon});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: KigoTheme.kigo500.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: KigoTheme.kigo500, width: 2.5),
            ),
            child: Icon(widget.icon, size: 14, color: KigoTheme.kigo500),
          ),
        );
      },
    );
  }
}
