/// Settings screen for managing blog sources and monitoring sync status.
///
/// [SettingsScreen] provides:
/// - A list of configured [BlogSource]s with per-source sync, edit, and
///   delete actions.
/// - An "Add blog source" dialog that accepts a human-readable name,
///   Blogger blog ID, optional Google API key, sync interval, and an
///   enabled/disabled toggle.
/// - A sync status banner ([_SyncBanner]) that appears while a sync is
///   running or after it completes/fails, using the [SyncService] provided
///   in the widget tree.
/// - An empty-state placeholder with a call-to-action button when no
///   sources have been configured yet.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/blog_source.dart';
import '../services/sync_service.dart';
import 'package:intl/intl.dart';

/// Stateful screen for CRUD management of [BlogSource] entries.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Singleton data-access layer.
  final _db = DatabaseHelper.instance;

  /// Currently loaded list of blog sources.
  List<BlogSource> _sources = [];

  /// `true` while the initial database load is in progress.
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  /// Loads all [BlogSource]s from the database and refreshes the list.
  Future<void> _loadSources() async {
    final sources = await _db.getBlogSources();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _loading = false;
    });
  }

  /// Shows an [AlertDialog] for adding a new source or editing [existing].
  ///
  /// The dialog uses [StatefulBuilder] so that the dropdown and switch can
  /// update their values reactively without rebuilding the parent screen.
  /// Validation requires that both the name and blog ID fields are non-empty
  /// before allowing the user to save.
  Future<void> _showAddEditDialog([BlogSource? existing]) async {
    // Pre-populate controllers with the existing source's values (if editing).
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final blogIdCtrl =
        TextEditingController(text: existing?.blogId ?? '');
    final apiKeyCtrl =
        TextEditingController(text: existing?.apiKey ?? '');
    int intervalHours = existing?.syncIntervalHours ?? 24;
    bool enabled = existing?.enabled ?? true;

    // Await the dialog result; `true` means the user pressed Save.
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title:
                Text(existing == null ? 'Add Blog Source' : 'Edit Source'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Blog display name ───────────────────────────────
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Ecosophia',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Blogger numeric blog ID ─────────────────────────
                  TextField(
                    controller: blogIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Blogger Blog ID',
                      hintText: 'e.g. 123456789',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),

                  // ── Optional Google API key ─────────────────────────
                  TextField(
                    controller: apiKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Key (optional)',
                      hintText: 'Google API key for Blogger v3',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Sync interval picker ────────────────────────────
                  DropdownButtonFormField<int>(
                    value: intervalHours,
                    decoration: const InputDecoration(
                        labelText: 'Sync interval'),
                    items: const [
                      DropdownMenuItem(value: 6, child: Text('Every 6 h')),
                      DropdownMenuItem(
                          value: 12, child: Text('Every 12 h')),
                      DropdownMenuItem(
                          value: 24, child: Text('Every 24 h')),
                      DropdownMenuItem(
                          value: 48, child: Text('Every 2 days')),
                      DropdownMenuItem(
                          value: 168, child: Text('Every week')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => intervalHours = v);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── Enabled toggle ──────────────────────────────────
                  // Disabled sources are skipped by SyncService.syncAll().
                  SwitchListTile(
                    title: const Text('Enabled'),
                    value: enabled,
                    onChanged: (v) =>
                        setDialogState(() => enabled = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  // Require both name and blog ID before saving.
                  if (nameCtrl.text.trim().isEmpty ||
                      blogIdCtrl.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    // Construct the new or updated BlogSource and persist it.
    final source = BlogSource(
      // Preserve the existing ID when editing; generate a new one for inserts.
      id: existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: nameCtrl.text.trim(),
      blogId: blogIdCtrl.text.trim(),
      // Treat an empty API key field as "no key" (null) rather than storing
      // an empty string, which could cause issues in API request headers.
      apiKey: apiKeyCtrl.text.trim().isEmpty
          ? null
          : apiKeyCtrl.text.trim(),
      enabled: enabled,
      lastSyncAt: existing?.lastSyncAt,
      syncIntervalHours: intervalHours,
    );

    await _db.upsertBlogSource(source);
    // Reload the list to reflect the change.
    await _loadSources();
  }

  /// Shows a confirmation dialog and deletes [source] if confirmed.
  ///
  /// Posts and comments that were already synced for this source are
  /// intentionally retained in the database so they remain available for
  /// search and analytics.
  Future<void> _delete(BlogSource source) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete source?'),
        content: Text(
            'Remove "${source.name}"? All synced posts and comments will remain in the local database.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await _db.deleteBlogSource(source.id);
    await _loadSources();
  }

  @override
  Widget build(BuildContext context) {
    // Watch SyncService so the banner reacts to sync state changes in real time.
    final sync = context.watch<SyncService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          // Shortcut to add a new source from the AppBar.
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add blog source',
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Sync status banner ─────────────────────────────────
                // Shown whenever a sync is in progress or has just finished.
                if (sync.isSyncing || sync.statusMessage.isNotEmpty)
                  _SyncBanner(sync: sync),

                Expanded(
                  child: _sources.isEmpty
                      // ── Empty state ──────────────────────────────────
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.rss_feed,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No blog sources yet.',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add a source'),
                                onPressed: () => _showAddEditDialog(),
                              ),
                            ],
                          ),
                        )
                      // ── Source list ──────────────────────────────────
                      : ListView.separated(
                          itemCount: _sources.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final src = _sources[i];
                            // Format the last sync timestamp or show "Never".
                            final lastSync = src.lastSyncAt != null
                                ? DateFormat.yMMMd()
                                    .add_jm()
                                    .format(src.lastSyncAt!.toLocal())
                                : 'Never';
                            return ListTile(
                              // Dim the icon for disabled sources.
                              leading: Icon(
                                Icons.rss_feed,
                                color: src.enabled
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline,
                              ),
                              title: Text(src.name),
                              subtitle: Text(
                                'Blog ID: ${src.blogId}\nLast sync: $lastSync',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Per-source sync trigger button.
                                  IconButton(
                                    icon: const Icon(Icons.sync, size: 20),
                                    tooltip: 'Sync now',
                                    // Disable while a sync is already running.
                                    onPressed: sync.isSyncing
                                        ? null
                                        : () => context
                                            .read<SyncService>()
                                            .syncSource(src.id),
                                  ),
                                  // Edit button opens the add/edit dialog.
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    tooltip: 'Edit',
                                    onPressed: () =>
                                        _showAddEditDialog(src),
                                  ),
                                  // Delete button with confirmation dialog.
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20),
                                    tooltip: 'Delete',
                                    onPressed: () => _delete(src),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── Sync status banner ───────────────────────────────────────────────────────

/// A full-width banner displayed at the top of [SettingsScreen] while a sync
/// is in progress or after it completes (success or error).
///
/// Shows a [CircularProgressIndicator] spinner (determinate when [progress]
/// is available, indeterminate otherwise) while [SyncService.isSyncing] is
/// `true`, and a status icon afterwards.  Colours switch to
/// `errorContainer` on failure, and `primaryContainer` on success/progress.
class _SyncBanner extends StatelessWidget {
  /// The live [SyncService] instance to observe.
  final SyncService sync;

  const _SyncBanner({required this.sync});

  @override
  Widget build(BuildContext context) {
    final isError = sync.status == SyncStatus.error;
    // Choose container colours based on success vs error state.
    final color = isError
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.primaryContainer;
    final textColor = isError
        ? Theme.of(context).colorScheme.onErrorContainer
        : Theme.of(context).colorScheme.onPrimaryContainer;

    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (sync.isSyncing) ...[
            // Show a determinate progress indicator once we have progress data,
            // and an indeterminate one before the first post is processed.
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: sync.progress > 0 ? sync.progress : null,
              ),
            ),
            const SizedBox(width: 12),
          ] else
            // Show a check or error icon when the sync has finished.
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: textColor,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sync.statusMessage,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
