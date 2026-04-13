import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class RetroLoadingIndicator extends StatefulWidget {
  const RetroLoadingIndicator({super.key});

  @override
  State<RetroLoadingIndicator> createState() =>
      _RetroLoadingIndicatorState();
}

class _RetroLoadingIndicatorState extends State<RetroLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const List<String> _frames = [
    '|',
    '/',
    '-',
    '\\',
    '|',
    '/',
    '-',
    '\\'
  ];
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() {
        final newIndex =
            (_controller.value * _frames.length).floor() % _frames.length;
        if (newIndex != _frameIndex) {
          setState(() => _frameIndex = newIndex);
        }
      });
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'LOADING... ${_frames[_frameIndex]}',
        style: GoogleFonts.pressStart2p(
          fontSize: 12,
          color: RetroColors.neonGreen,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
