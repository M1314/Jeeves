import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RetroButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final TextStyle? textStyle;

  const RetroButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.textStyle,
  });

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null) setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _pressed = false);
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.color ?? RetroColors.neonGreen;
    final topLeftColor =
        _pressed ? Colors.black : Colors.white.withAlpha(200);
    final bottomRightColor =
        _pressed ? Colors.white.withAlpha(200) : Colors.black;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: widget.onPressed == null ? bg.withAlpha(100) : bg,
          border: Border(
            top: BorderSide(color: topLeftColor, width: 2),
            left: BorderSide(color: topLeftColor, width: 2),
            bottom: BorderSide(color: bottomRightColor, width: 2),
            right: BorderSide(color: bottomRightColor, width: 2),
          ),
        ),
        child: Text(
          widget.label,
          style: widget.textStyle ??
              TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: widget.onPressed == null
                    ? RetroColors.black.withAlpha(150)
                    : RetroColors.black,
                letterSpacing: 1,
              ),
        ),
      ),
    );
  }
}
