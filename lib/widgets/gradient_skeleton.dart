import 'package:flutter/material.dart';

class GradientSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const GradientSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<GradientSkeleton> createState() => _GradientSkeletonState();
}

class _GradientSkeletonState extends State<GradientSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [
              Color(0xFF1A1A24),
              Color(0xFF252535),
              Color(0xFF2A2A3A),
              Color(0xFF252535),
              Color(0xFF1A1A24),
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
      ),
    );
  }
}

// A pre-built card skeleton for home screen YouTube shimmer replacement
class GradientSkeletonCard extends StatelessWidget {
  const GradientSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(left: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientSkeleton(
            width: 200,
            height: 112,
            borderRadius: 14,
          ),
          const SizedBox(height: 8),
          const GradientSkeleton(width: 100, height: 10),
          const SizedBox(height: 6),
          const GradientSkeleton(height: 13),
          const SizedBox(height: 4),
          const GradientSkeleton(width: 140, height: 13),
          const SizedBox(height: 6),
          const GradientSkeleton(width: 80, height: 10),
        ],
      ),
    );
  }
}

// Post skeleton for Reddit/News shimmer replacement
class GradientSkeletonPost extends StatelessWidget {
  const GradientSkeletonPost({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GradientSkeleton(width: 80, height: 10),
                const SizedBox(height: 8),
                const GradientSkeleton(height: 14),
                const SizedBox(height: 6),
                const GradientSkeleton(width: 200, height: 14),
                const SizedBox(height: 8),
                const GradientSkeleton(width: 120, height: 10),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GradientSkeleton(
            width: 72,
            height: 72,
            borderRadius: 10,
          ),
        ],
      ),
    );
  }
}
