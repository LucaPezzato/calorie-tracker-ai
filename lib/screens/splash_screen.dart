import 'dart:async';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();

    _navTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, __, ___) => widget.nextScreen,
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1512),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minimal App Emblem
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF17221D),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CircularProgressIndicator(
                          value: 0.75,
                          strokeWidth: 6,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(0xFF22332B),
                          color: cs.primary,
                        ),
                      ),
                      Icon(
                        Symbols.local_fire_department_rounded,
                        fill: 1,
                        size: 46,
                        color: cs.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Calorie Tracker',
                  style: tt.headlineSmall?.copyWith(
                    fontSize: 24,
                    color: const Color(0xFFE4F2EB),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17221D),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'Diario nutrizionale personale',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
