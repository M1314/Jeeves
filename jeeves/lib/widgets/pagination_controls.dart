import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'retro_button.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageSelected;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
  });

  List<int> _visiblePages() {
    const maxVisible = 5;
    final half = maxVisible ~/ 2;
    int start = (currentPage - half).clamp(1, totalPages);
    int end = (start + maxVisible - 1).clamp(1, totalPages);
    if (end - start + 1 < maxVisible) {
      start = (end - maxVisible + 1).clamp(1, totalPages);
    }
    return List.generate(end - start + 1, (i) => start + i);
  }

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final pages = _visiblePages();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RetroButton(
            label: '< PREV',
            onPressed:
                currentPage > 1 ? () => onPageSelected(currentPage - 1) : null,
            color: RetroColors.electricBlue,
          ),
          const SizedBox(width: 8),
          ...pages.map((p) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: RetroButton(
                  label: '$p',
                  onPressed: p == currentPage ? null : () => onPageSelected(p),
                  color: p == currentPage
                      ? RetroColors.purple
                      : RetroColors.darkSurface2,
                ),
              )),
          const SizedBox(width: 8),
          RetroButton(
            label: 'NEXT >',
            onPressed: currentPage < totalPages
                ? () => onPageSelected(currentPage + 1)
                : null,
            color: RetroColors.electricBlue,
          ),
        ],
      ),
    );
  }
}
