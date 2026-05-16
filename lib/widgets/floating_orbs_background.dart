import 'dart:ui';
import 'package:flutter/material.dart';

class FloatingOrbsBackground extends StatefulWidget {
  final Widget child;
  const FloatingOrbsBackground({super.key, required this.child});

  @override
  State<FloatingOrbsBackground> createState() => _FloatingOrbsBackgroundState();
}

class _FloatingOrbsBackgroundState extends State<FloatingOrbsBackground>
    with TickerProviderStateMixin {
  late final AnimationController _controller1;
  late final AnimationController _controller2;
  late final AnimationController _controller3;

  late final Animation<Offset> _anim1;
  late final Animation<Offset> _anim2;
  late final Animation<Offset> _anim3;

  @override
  void initState() {
    super.initState();

    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _controller3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _anim1 = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0.04, 0.06),
    ).animate(CurvedAnimation(parent: _controller1, curve: Curves.easeInOut));

    _anim2 = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(-0.05, 0.04),
    ).animate(CurvedAnimation(parent: _controller2, curve: Curves.easeInOut));

    _anim3 = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0.03, -0.05),
    ).animate(CurvedAnimation(parent: _controller3, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Solid base so orbs are visible and text has consistent contrast in both themes.
        Positioned.fill(
          child: Container(color: Theme.of(context).colorScheme.surface),
        ),
        // Purple orb — top-left
        AnimatedBuilder(
          animation: _anim1,
          builder: (_, _) => Positioned(
            top: -80 + _anim1.value.dy * 200,
            left: -80 + _anim1.value.dx * 200,
            child: _Orb(size: 280, color: const Color(0xFF7B61FF)),
          ),
        ),
        // Pink orb — center-right
        AnimatedBuilder(
          animation: _anim2,
          builder: (_, _) => Positioned(
            top: 200 + _anim2.value.dy * 200,
            right: -60 + _anim2.value.dx * 200,
            child: _Orb(size: 240, color: const Color(0xFFE94B9C)),
          ),
        ),
        // Orange orb — bottom-center
        AnimatedBuilder(
          animation: _anim3,
          builder: (_, _) => Positioned(
            bottom: -60 + _anim3.value.dy * 200,
            left: 80 + _anim3.value.dx * 200,
            child: _Orb(size: 260, color: const Color(0xFFFF6B35)),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}
