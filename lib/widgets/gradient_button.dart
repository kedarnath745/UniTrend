import 'package:flutter/material.dart';

class GradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double? width;
  final bool loading;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 52,
    this.width,
    this.loading = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: widget.width ?? double.infinity,
          height: widget.height,
          child: AnimatedBuilder(
            animation: _shimmerAnim,
            builder: (_, _) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: widget.onPressed != null
                    ? LinearGradient(
                        colors: const [
                          Color(0xFFFF6B35),
                          Color(0xFFE94B9C),
                          Color(0xFF7B61FF),
                          Color(0xFFE94B9C),
                          Color(0xFFFF6B35),
                        ],
                        stops: [
                          (_shimmerAnim.value - 1).clamp(0.0, 1.0),
                          (_shimmerAnim.value - 0.5).clamp(0.0, 1.0),
                          _shimmerAnim.value.clamp(0.0, 1.0),
                          (_shimmerAnim.value + 0.5).clamp(0.0, 1.0),
                          (_shimmerAnim.value + 1).clamp(0.0, 1.0),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF444444), Color(0xFF333333)],
                      ),
              ),
              child: Center(
                child: widget.loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : DefaultTextStyle(
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        child: widget.child,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
