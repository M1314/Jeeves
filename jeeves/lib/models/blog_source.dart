class BlogSource {
  final String id;
  final String name;
  final String blogId;
  final String? apiKey;
  final bool enabled;
  final DateTime? lastSyncAt;
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

  factory BlogSource.fromMap(Map<String, dynamic> map) {
    return BlogSource(
      id: map['id'] as String,
      name: map['name'] as String,
      blogId: map['blog_id'] as String,
      apiKey: map['api_key'] as String?,
      enabled: (map['enabled'] as int? ?? 1) == 1,
      lastSyncAt: map['last_sync_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_sync_at'] as int)
          : null,
      syncIntervalHours: map['sync_interval_hours'] as int? ?? 24,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'blog_id': blogId,
      'api_key': apiKey,
      'enabled': enabled ? 1 : 0,
      'last_sync_at': lastSyncAt?.millisecondsSinceEpoch,
      'sync_interval_hours': syncIntervalHours,
    };
  }

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
