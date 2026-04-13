/// Immutable configuration record for a Blogger blog that Jeeves should
/// scrape, store, and keep in sync.
///
/// A [BlogSource] is persisted in the `blog_sources` SQLite table and managed
/// through [SettingsScreen].  Each source maps 1-to-1 to a Blogger blog
/// identified by [blogId].  Multiple sources can be active simultaneously,
/// allowing the user to track several Ecosophia-affiliated blogs.
class BlogSource {
  /// Application-generated unique identifier for this source (milliseconds
  /// since epoch as a string).  Used as the SQLite primary key.
  final String id;

  /// Human-readable display name shown in the Settings screen, e.g.
  /// `"Ecosophia"`.
  final String name;

  /// Blogger-assigned numeric blog ID, e.g. `"123456789"`.  Required by the
  /// Blogger API v3 for all post and comment requests.
  final String blogId;

  /// Google API key used to authenticate Blogger API v3 requests.
  ///
  /// Optional: the API can be called without a key for public blogs, but the
  /// unauthenticated quota is lower.  When provided, it is passed as the
  /// `key` query parameter on every API request.
  ///
  /// **Security note**: API keys are stored in plaintext in the local SQLite
  /// database.  Users should use a key that is restricted to the Blogger API
  /// and to their device's package ID.
  final String? apiKey;

  /// Whether this source should be included in automatic and manual sync
  /// operations.  Disabled sources are skipped by [SyncService.syncAll].
  final bool enabled;

  /// UTC timestamp of the most recent successful sync for this source, or
  /// `null` if the source has never been synced.
  ///
  /// Displayed as "Last sync: <date>" in the Settings list and used to
  /// determine whether a scheduled sync is due.
  final DateTime? lastSyncAt;

  /// Minimum number of hours between automatic syncs for this source.
  ///
  /// Defaults to 24 (daily).  Future background-sync infrastructure should
  /// skip a source whose [lastSyncAt] is within [syncIntervalHours] hours of
  /// the current time.
  final int syncIntervalHours;

  const BlogSource({
    required this.id,
    required this.name,
    required this.blogId,
    this.apiKey,
    this.enabled = true,
    this.lastSyncAt,
    this.syncIntervalHours = 24,
  });

  /// Deserialises a [BlogSource] from a SQLite column map.
  ///
  /// SQLite has no native boolean type; [enabled] is stored as `1` (true) or
  /// `0` (false).  [lastSyncAt] is stored as a nullable integer milliseconds
  /// since epoch.
  factory BlogSource.fromMap(Map<String, dynamic> map) {
    return BlogSource(
      id: map['id'] as String,
      name: map['name'] as String,
      blogId: map['blog_id'] as String,
      apiKey: map['api_key'] as String?,
      // SQLite INTEGER 1/0 → Dart bool.
      enabled: (map['enabled'] as int? ?? 1) == 1,
      // last_sync_at is NULL until the first successful sync completes.
      lastSyncAt: map['last_sync_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_sync_at'] as int)
          : null,
      syncIntervalHours: map['sync_interval_hours'] as int? ?? 24,
    );
  }

  /// Serialises this [BlogSource] into a SQLite column map.
  ///
  /// The map keys match the `blog_sources` table column names exactly.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'blog_id': blogId,
      'api_key': apiKey,
      // Store bool as INTEGER so SQLite can index and filter efficiently.
      'enabled': enabled ? 1 : 0,
      'last_sync_at': lastSyncAt?.millisecondsSinceEpoch,
      'sync_interval_hours': syncIntervalHours,
    };
  }

  /// Returns a copy of this [BlogSource] with the specified fields replaced.
  ///
  /// All parameters are optional; omitting a parameter retains the current
  /// value.  Useful in the Settings dialog to apply partial edits.
  BlogSource copyWith({
    String? name,
    String? blogId,
    String? apiKey,
    bool? enabled,
    DateTime? lastSyncAt,
    int? syncIntervalHours,
  }) {
    return BlogSource(
      id: id,
      name: name ?? this.name,
      blogId: blogId ?? this.blogId,
      apiKey: apiKey ?? this.apiKey,
      enabled: enabled ?? this.enabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      syncIntervalHours: syncIntervalHours ?? this.syncIntervalHours,
    );
  }
}
