import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SsoButton extends StatefulWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool dark;

  const SsoButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.dark = false,
  });

  @override
  State<SsoButton> createState() => _SsoButtonState();
}

class _SsoButtonState extends State<SsoButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: widget.dark ? AppColors.textDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.dark ? AppColors.textDark : AppColors.chipBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.icon,
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.dark ? Colors.white : AppColors.textDark,
                  fontFamily: 'Nunito',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
