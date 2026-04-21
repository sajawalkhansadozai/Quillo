import 'package:flutter/material.dart';

class QuilloButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;

  const QuilloButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  State<QuilloButton> createState() => _QuilloButtonState();
}

class _QuilloButtonState extends State<QuilloButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.reverse(),
      onTapUp: (_) {
        _controller.forward();
        widget.onTap();
      },
      onTapCancel: () => _controller.forward(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.backgroundColor.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: widget.textColor,
                fontFamily: 'Nunito',
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
