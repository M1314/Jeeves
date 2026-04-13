import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A compact filter bar for narrowing search results.
///
/// Calls [onFiltersChanged] whenever any filter value changes.
class SearchFilterBar extends StatefulWidget {
  final void Function({
    String? author,
    String? label,
    DateTime? from,
    DateTime? to,
    bool searchPosts,
    bool searchComments,
  }) onFiltersChanged;

  const SearchFilterBar({super.key, required this.onFiltersChanged});

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  final _authorController = TextEditingController();
  final _labelController = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  bool _searchPosts = true;
  bool _searchComments = true;

  void _emit() {
    widget.onFiltersChanged(
      author: _authorController.text.trim().isEmpty
          ? null
          : _authorController.text.trim(),
      label: _labelController.text.trim().isEmpty
          ? null
          : _labelController.text.trim(),
      from: _from,
      to: _to,
      searchPosts: _searchPosts,
      searchComments: _searchComments,
    );
  }

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom ? (_from ?? now) : (_to ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
    _emit();
  }

  @override
  void dispose() {
    _authorController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMMMd();

    return ExpansionTile(
      title: const Text('Filters'),
      leading: const Icon(Icons.filter_list),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type toggles
              Row(
                children: [
                  FilterChip(
                    label: const Text('Posts'),
                    selected: _searchPosts,
                    onSelected: (v) {
                      setState(() => _searchPosts = v);
                      _emit();
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Comments'),
                    selected: _searchComments,
                    onSelected: (v) {
                      setState(() => _searchComments = v);
                      _emit();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Author
              TextField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: 'Author',
                  prefixIcon: Icon(Icons.person_outline),
                  isDense: true,
                ),
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 8),
              // Label
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label / tag',
                  prefixIcon: Icon(Icons.label_outline),
                  isDense: true,
                ),
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 8),
              // Date range
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _from != null ? 'From: ${fmt.format(_from!)}' : 'From',
                        style: theme.textTheme.bodySmall,
                      ),
                      onPressed: () => _pickDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _to != null ? 'To: ${fmt.format(_to!)}' : 'To',
                        style: theme.textTheme.bodySmall,
                      ),
                      onPressed: () => _pickDate(context, false),
                    ),
                  ),
                  if (_from != null || _to != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Clear dates',
                      onPressed: () {
                        setState(() {
                          _from = null;
                          _to = null;
                        });
                        _emit();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
