/// Collapsible filter panel for the Search screen.
///
/// [SearchFilterBar] wraps an [ExpansionTile] containing five filter controls:
/// - **Posts / Comments toggles** — [FilterChip]s that include or exclude each
///   content type from the search results.
/// - **Author** — substring filter applied as a SQL LIKE clause.
/// - **Label / tag** — substring filter matched against the serialised labels
///   column.
/// - **Date range** — "From" and "To" date pickers that produce an inclusive
///   [DateTime] range; a clear button removes both dates at once.
///
/// Any change to a filter immediately calls [onFiltersChanged] so that the
/// parent [SearchScreen] can re-issue the database query with the updated
/// constraints.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Collapsible filter bar emitted above the search results list.
///
/// [onFiltersChanged] is called whenever the user changes any filter value,
/// including toggling content types, typing in the author/label fields,
/// picking a date, or clearing the date range.
class SearchFilterBar extends StatefulWidget {
  /// Callback invoked on every filter state change.
  ///
  /// All parameters are optional; omitting a parameter (or passing `null`)
  /// means "no filter" for that dimension.  [searchPosts] and [searchComments]
  /// default to `true` if omitted.
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
  /// Text controller for the author filter field.
  final _authorController = TextEditingController();

  /// Text controller for the label filter field.
  final _labelController = TextEditingController();

  /// Inclusive start of the date range, or `null` for no lower bound.
  DateTime? _from;

  /// Inclusive end of the date range (clamped to end-of-day), or `null`.
  DateTime? _to;

  /// Whether post results should be included in the next search.
  bool _searchPosts = true;

  /// Whether comment results should be included in the next search.
  bool _searchComments = true;

  /// Notifies the parent screen of the current filter state.
  ///
  /// Called after every user interaction that changes a filter value.
  void _emit() {
    widget.onFiltersChanged(
      // Treat empty strings as "no filter" (null) so the SQL WHERE clause
      // is only added when the user has actually typed something.
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

  /// Opens the platform date picker and stores the chosen date as either
  /// [_from] (when [isFrom] is `true`) or [_to] (end-of-day).
  ///
  /// The "To" date is clamped to 23:59:59 on the selected day so the range
  /// is fully inclusive.
  Future<void> _pickDate(BuildContext context, bool isFrom) async {
    final now = DateTime.now();
    // Pre-select the currently set date (or today) as the initial value.
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
        // Set end-of-day to make the "to" filter fully inclusive of the
        // selected date (midnight would exclude events on that day).
        _to = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
    _emit();
  }

  @override
  void dispose() {
    // Release text controllers to prevent memory leaks.
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
              // ── Content type toggles ──────────────────────────────
              Row(
                children: [
                  // Posts toggle — always shows at least one type selected.
                  FilterChip(
                    label: const Text('Posts'),
                    selected: _searchPosts,
                    onSelected: (v) {
                      setState(() => _searchPosts = v);
                      _emit();
                    },
                  ),
                  const SizedBox(width: 8),
                  // Comments toggle.
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

              // ── Author filter ─────────────────────────────────────
              TextField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: 'Author',
                  prefixIcon: Icon(Icons.person_outline),
                  isDense: true,
                ),
                // Re-emit on every keystroke for responsive filtering.
                onChanged: (_) => _emit(),
              ),
              const SizedBox(height: 8),

              // ── Label / tag filter ────────────────────────────────
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

              // ── Date range picker ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        // Show the selected date or a placeholder.
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
                  // Show the clear button only when at least one date is set.
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
