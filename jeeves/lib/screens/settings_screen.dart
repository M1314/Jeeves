import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../models/blog_source.dart';
import '../services/sync_service.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _db = DatabaseHelper.instance;
  List<BlogSource> _sources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    final sources = await _db.getBlogSources();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _loading = false;
    });
  }

  Future<void> _showAddEditDialog([BlogSource? existing]) async {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final blogIdCtrl =
        TextEditingController(text: existing?.blogId ?? '');
    final apiKeyCtrl =
        TextEditingController(text: existing?.apiKey ?? '');
    int intervalHours = existing?.syncIntervalHours ?? 24;
    bool enabled = existing?.enabled ?? true;

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
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Ecosophia',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: blogIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Blogger Blog ID',
                      hintText: 'e.g. 123456789',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: apiKeyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'API Key (optional)',
                      hintText: 'Google API key for Blogger v3',
                    ),
                  ),
                  const SizedBox(height: 12),
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

    final source = BlogSource(
      id: existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: nameCtrl.text.trim(),
      blogId: blogIdCtrl.text.trim(),
      apiKey: apiKeyCtrl.text.trim().isEmpty
          ? null
          : apiKeyCtrl.text.trim(),
      enabled: enabled,
      lastSyncAt: existing?.lastSyncAt,
      syncIntervalHours: intervalHours,
    );

    await _db.upsertBlogSource(source);
    await _loadSources();
  }

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
    final sync = context.watch<SyncService>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
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
                // Sync status banner
                if (sync.isSyncing || sync.statusMessage.isNotEmpty)
                  _SyncBanner(sync: sync),

                Expanded(
                  child: _sources.isEmpty
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
                      : ListView.separated(
                          itemCount: _sources.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final src = _sources[i];
                            final lastSync = src.lastSyncAt != null
                                ? DateFormat.yMMMd()
                                    .add_jm()
                                    .format(src.lastSyncAt!.toLocal())
                                : 'Never';
                            return ListTile(
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
                                  IconButton(
                                    icon: const Icon(Icons.sync, size: 20),
                                    tooltip: 'Sync now',
                                    onPressed: sync.isSyncing
                                        ? null
                                        : () => context
                                            .read<SyncService>()
                                            .syncSource(src.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    tooltip: 'Edit',
                                    onPressed: () =>
                                        _showAddEditDialog(src),
                                  ),
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

class _SyncBanner extends StatelessWidget {
  final SyncService sync;
  const _SyncBanner({required this.sync});

  @override
  Widget build(BuildContext context) {
    final isError = sync.status == SyncStatus.error;
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
