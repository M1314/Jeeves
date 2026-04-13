import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'retro_button.dart';

class RetroSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final String? initialValue;

  const RetroSearchBar({
    super.key,
    required this.onSearch,
    this.initialValue,
  });

  @override
  State<RetroSearchBar> createState() => _RetroSearchBarState();
}

class _RetroSearchBarState extends State<RetroSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSearch() {
    final q = _controller.text.trim();
    if (q.isNotEmpty) widget.onSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _handleSearch(),
            style: const TextStyle(
              color: RetroColors.neonGreen,
              fontFamily: 'Courier',
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'SEARCH COMMENTS...',
              prefixIcon: const Icon(
                Icons.search,
                color: RetroColors.neonGreen,
              ),
              filled: true,
              fillColor: RetroColors.darkSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide:
                    const BorderSide(color: RetroColors.neonGreen, width: 3),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide:
                    const BorderSide(color: RetroColors.neonGreen, width: 3),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide:
                    const BorderSide(color: RetroColors.electricBlue, width: 3),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        RetroButton(
          label: 'SEARCH',
          onPressed: _handleSearch,
          color: RetroColors.neonGreen,
        ),
      ],
    );
  }
}
