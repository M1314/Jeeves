/// Identifies which platform a [BlogSource] is hosted on, which determines
/// which HTTP client strategy [FeedService] uses.
enum SourceType {
  /// WordPress site — fetched via the WordPress REST API v2
  /// (`/wp-json/wp/v2/posts` and `/wp-json/wp/v2/comments`).
  wordpress,

  /// Dreamwidth journal — fetched via the site's public Atom feed
  /// (`/data/atom`).  Comment sync is not supported for this type.
  dreamwidth,
}

/// Immutable configuration record for a blog that Jeeves should scrape,
/// store, and keep in sync.
///
/// A [BlogSource] is persisted in the `blog_sources` SQLite table and managed
/// through [SettingsScreen].  Each source maps 1-to-1 to a site identified by
/// its [siteUrl].  Multiple sources can be active simultaneously, allowing the
/// user to track several Ecosophia-affiliated blogs.
class BlogSource {
  /// Application-generated unique identifier for this source (milliseconds
  /// since epoch as a string).  Used as the SQLite primary key.
  final String id;

  /// Human-readable display name shown in the Settings screen, e.g.
  /// `"Ecosophia"`.
  final String name;

  /// Base URL of the blog, e.g. `"https://www.ecosophia.net"` or
  /// `"https://ecosophia.dreamwidth.org"`.  Used by [FeedService] to build
  /// request URIs.  Trailing slashes are stripped before use.
  final String siteUrl;

  /// Platform type of this source.  Determines which scraping strategy
  /// [FeedService] applies (WordPress REST API vs Dreamwidth Atom feed).
  final SourceType sourceType;

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
    required this.siteUrl,
    this.sourceType = SourceType.wordpress,
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
      siteUrl: map['site_url'] as String,
      sourceType: _sourceTypeFromString(map['source_type'] as String? ?? 'wordpress'),
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
      'site_url': siteUrl,
      'source_type': sourceType.name,
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
    String? siteUrl,
    SourceType? sourceType,
    bool? enabled,
    DateTime? lastSyncAt,
    int? syncIntervalHours,
  }) {
    return BlogSource(
      id: id,
      name: name ?? this.name,
      siteUrl: siteUrl ?? this.siteUrl,
      sourceType: sourceType ?? this.sourceType,
      enabled: enabled ?? this.enabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      syncIntervalHours: syncIntervalHours ?? this.syncIntervalHours,
    );
  }

  static SourceType _sourceTypeFromString(String value) {
    return SourceType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => SourceType.wordpress,
    );
  }
}
