import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/blog_source.dart';

class DatabaseHelper {
  static const _dbName = 'jeeves.db';
  static const _dbVersion = 1;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Blog sources
    await db.execute('''
      CREATE TABLE blog_sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        blog_id TEXT NOT NULL,
        api_key TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        last_sync_at INTEGER,
        sync_interval_hours INTEGER NOT NULL DEFAULT 24
      )
    ''');

    // Posts
    await db.execute('''
      CREATE TABLE posts (
        id TEXT PRIMARY KEY,
        blog_id TEXT NOT NULL,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        published_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        body TEXT NOT NULL,
        labels TEXT NOT NULL DEFAULT '[]',
        comment_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Posts FTS5 virtual table
    await db.execute('''
      CREATE VIRTUAL TABLE posts_fts USING fts5(
        id UNINDEXED,
        title,
        author,
        body,
        labels,
        content=posts,
        content_rowid=rowid
      )
    ''');

    // Triggers to keep FTS in sync with posts table
    await db.execute('''
      CREATE TRIGGER posts_ai AFTER INSERT ON posts BEGIN
        INSERT INTO posts_fts(rowid, id, title, author, body, labels)
        VALUES (new.rowid, new.id, new.title, new.author, new.body, new.labels);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER posts_ad AFTER DELETE ON posts BEGIN
        INSERT INTO posts_fts(posts_fts, rowid, id, title, author, body, labels)
        VALUES ('delete', old.rowid, old.id, old.title, old.author, old.body, old.labels);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER posts_au AFTER UPDATE ON posts BEGIN
        INSERT INTO posts_fts(posts_fts, rowid, id, title, author, body, labels)
        VALUES ('delete', old.rowid, old.id, old.title, old.author, old.body, old.labels);
        INSERT INTO posts_fts(rowid, id, title, author, body, labels)
        VALUES (new.rowid, new.id, new.title, new.author, new.body, new.labels);
      END
    ''');

    // Comments
    await db.execute('''
      CREATE TABLE comments (
        id TEXT PRIMARY KEY,
        post_id TEXT NOT NULL,
        parent_id TEXT,
        author TEXT NOT NULL,
        published_at INTEGER NOT NULL,
        body TEXT NOT NULL,
        FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
      )
    ''');

    // Comments FTS5 virtual table
    await db.execute('''
      CREATE VIRTUAL TABLE comments_fts USING fts5(
        id UNINDEXED,
        post_id UNINDEXED,
        author,
        body,
        content=comments,
        content_rowid=rowid
      )
    ''');

    await db.execute('''
      CREATE TRIGGER comments_ai AFTER INSERT ON comments BEGIN
        INSERT INTO comments_fts(rowid, id, post_id, author, body)
        VALUES (new.rowid, new.id, new.post_id, new.author, new.body);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER comments_ad AFTER DELETE ON comments BEGIN
        INSERT INTO comments_fts(comments_fts, rowid, id, post_id, author, body)
        VALUES ('delete', old.rowid, old.id, old.post_id, old.author, old.body);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER comments_au AFTER UPDATE ON comments BEGIN
        INSERT INTO comments_fts(comments_fts, rowid, id, post_id, author, body)
        VALUES ('delete', old.rowid, old.id, old.post_id, old.author, old.body);
        INSERT INTO comments_fts(rowid, id, post_id, author, body)
        VALUES (new.rowid, new.id, new.post_id, new.author, new.body);
      END
    ''');

    // Indexes
    await db.execute(
        'CREATE INDEX posts_blog_id ON posts(blog_id)');
    await db.execute(
        'CREATE INDEX posts_published_at ON posts(published_at)');
    await db.execute(
        'CREATE INDEX comments_post_id ON comments(post_id)');
    await db.execute(
        'CREATE INDEX comments_published_at ON comments(published_at)');
  }

  // ─── Blog Sources ────────────────────────────────────────────────────────

  Future<List<BlogSource>> getBlogSources() async {
    final db = await database;
    final rows = await db.query('blog_sources');
    return rows.map(BlogSource.fromMap).toList();
  }

  Future<void> upsertBlogSource(BlogSource source) async {
    final db = await database;
    await db.insert(
      'blog_sources',
      source.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBlogSource(String id) async {
    final db = await database;
    await db.delete('blog_sources', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateLastSyncAt(String blogSourceId) async {
    final db = await database;
    await db.update(
      'blog_sources',
      {'last_sync_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [blogSourceId],
    );
  }

  // ─── Posts ───────────────────────────────────────────────────────────────

  Future<void> upsertPost(Post post) async {
    final db = await database;
    await db.insert(
      'posts',
      post.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertPosts(List<Post> posts) async {
    final db = await database;
    final batch = db.batch();
    for (final post in posts) {
      batch.insert(
        'posts',
        post.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<Post?> getPost(String id) async {
    final db = await database;
    final rows = await db.query('posts', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Post.fromMap(rows.first);
  }

  Future<List<Post>> getPosts({
    String? blogId,
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    final db = await database;
    final rows = await db.query(
      'posts',
      where: blogId != null ? 'blog_id = ?' : null,
      whereArgs: blogId != null ? [blogId] : null,
      orderBy: orderBy ?? 'published_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Post.fromMap).toList();
  }

  Future<DateTime?> getLatestPostUpdatedAt(String blogId) async {
    final db = await database;
    final rows = await db.query(
      'posts',
      columns: ['MAX(updated_at) as max_updated'],
      where: 'blog_id = ?',
      whereArgs: [blogId],
    );
    if (rows.isEmpty || rows.first['max_updated'] == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(
        rows.first['max_updated'] as int);
  }

  // ─── Comments ────────────────────────────────────────────────────────────

  Future<void> upsertComments(List<Comment> comments) async {
    final db = await database;
    final batch = db.batch();
    for (final c in comments) {
      batch.insert(
        'comments',
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Comment>> getCommentsForPost(String postId) async {
    final db = await database;
    final rows = await db.query(
      'comments',
      where: 'post_id = ?',
      whereArgs: [postId],
      orderBy: 'published_at ASC',
    );
    return rows.map(Comment.fromMap).toList();
  }

  Future<void> updatePostCommentCount(String postId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM comments WHERE post_id = ?',
      [postId],
    );
    final count = (result.first['cnt'] as int?) ?? 0;
    await db.update(
      'posts',
      {'comment_count': count},
      where: 'id = ?',
      whereArgs: [postId],
    );
  }

  // ─── Full-text search ────────────────────────────────────────────────────

  /// Search posts and/or comments using FTS5.
  ///
  /// [query] is the user search string (supports FTS5 syntax).
  /// [searchPosts] and [searchComments] toggle which tables are searched.
  /// [authorFilter], [labelFilter], [fromDate], [toDate] narrow results.
  Future<SearchResults> search({
    required String query,
    bool searchPosts = true,
    bool searchComments = true,
    String? authorFilter,
    String? labelFilter,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 50,
  }) async {
    final db = await database;
    final ftsQuery = _escapeFtsQuery(query);

    final List<PostSearchResult> postResults = [];
    final List<CommentSearchResult> commentResults = [];

    if (searchPosts && ftsQuery.isNotEmpty) {
      final whereClauses = <String>['posts_fts MATCH ?'];
      final args = <dynamic>[ftsQuery];

      if (authorFilter != null && authorFilter.isNotEmpty) {
        whereClauses.add("p.author LIKE ?");
        args.add('%$authorFilter%');
      }
      if (labelFilter != null && labelFilter.isNotEmpty) {
        whereClauses.add("p.labels LIKE ?");
        args.add('%$labelFilter%');
      }
      if (fromDate != null) {
        whereClauses.add('p.published_at >= ?');
        args.add(fromDate.millisecondsSinceEpoch);
      }
      if (toDate != null) {
        whereClauses.add('p.published_at <= ?');
        args.add(toDate.millisecondsSinceEpoch);
      }

      final sql = '''
        SELECT p.*, bm25(posts_fts) AS rank
        FROM posts_fts
        JOIN posts p ON posts_fts.id = p.id
        WHERE ${whereClauses.join(' AND ')}
        ORDER BY rank
        LIMIT $limit
      ''';

      final rows = await db.rawQuery(sql, args);
      for (final row in rows) {
        final map = Map<String, dynamic>.from(row)..remove('rank');
        postResults.add(PostSearchResult(post: Post.fromMap(map)));
      }
    }

    if (searchComments && ftsQuery.isNotEmpty) {
      final whereClauses = <String>['comments_fts MATCH ?'];
      final args = <dynamic>[ftsQuery];

      if (authorFilter != null && authorFilter.isNotEmpty) {
        whereClauses.add('c.author LIKE ?');
        args.add('%$authorFilter%');
      }
      if (fromDate != null) {
        whereClauses.add('c.published_at >= ?');
        args.add(fromDate.millisecondsSinceEpoch);
      }
      if (toDate != null) {
        whereClauses.add('c.published_at <= ?');
        args.add(toDate.millisecondsSinceEpoch);
      }

      final sql = '''
        SELECT c.*, p.title as post_title, p.url as post_url,
               bm25(comments_fts) AS rank
        FROM comments_fts
        JOIN comments c ON comments_fts.id = c.id
        JOIN posts p ON c.post_id = p.id
        WHERE ${whereClauses.join(' AND ')}
        ORDER BY rank
        LIMIT $limit
      ''';

      final rows = await db.rawQuery(sql, args);
      for (final row in rows) {
        final comment = Comment.fromMap({
          'id': row['id'],
          'post_id': row['post_id'],
          'parent_id': row['parent_id'],
          'author': row['author'],
          'published_at': row['published_at'],
          'body': row['body'],
        });
        commentResults.add(CommentSearchResult(
          comment: comment,
          postTitle: row['post_title'] as String? ?? '',
          postUrl: row['post_url'] as String? ?? '',
        ));
      }
    }

    return SearchResults(posts: postResults, comments: commentResults);
  }

  // ─── Analytics ───────────────────────────────────────────────────────────

  /// Returns post counts grouped by calendar month (UTC).
  Future<List<ActivityPoint>> getPostActivityByMonth() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        strftime('%Y-%m', datetime(published_at/1000, 'unixepoch')) AS month,
        COUNT(*) AS count
      FROM posts
      GROUP BY month
      ORDER BY month
    ''');
    return rows
        .map((r) => ActivityPoint(
              label: r['month'] as String,
              count: r['count'] as int,
            ))
        .toList();
  }

  /// Returns comment counts grouped by calendar month (UTC).
  Future<List<ActivityPoint>> getCommentActivityByMonth() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        strftime('%Y-%m', datetime(published_at/1000, 'unixepoch')) AS month,
        COUNT(*) AS count
      FROM comments
      GROUP BY month
      ORDER BY month
    ''');
    return rows
        .map((r) => ActivityPoint(
              label: r['month'] as String,
              count: r['count'] as int,
            ))
        .toList();
  }

  /// Top commenters ranked by comment count.
  Future<List<RankedItem>> getTopCommenters({int limit = 20}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT author, COUNT(*) AS count
      FROM comments
      GROUP BY author
      ORDER BY count DESC
      LIMIT ?
    ''', [limit]);
    return rows
        .map((r) =>
            RankedItem(label: r['author'] as String, count: r['count'] as int))
        .toList();
  }

  /// Most-commented posts ranked by comment count.
  Future<List<Post>> getMostCommentedPosts({int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'posts',
      orderBy: 'comment_count DESC',
      limit: limit,
    );
    return rows.map(Post.fromMap).toList();
  }

  /// Label/tag frequency across all posts.
  Future<List<RankedItem>> getLabelFrequency({int limit = 30}) async {
    final db = await database;
    // labels is stored as a JSON array string; we expand it in application code
    final rows = await db.query('posts', columns: ['labels']);
    final freq = <String, int>{};
    for (final row in rows) {
      final post = Post.fromMap({
        'id': '',
        'blog_id': '',
        'url': '',
        'title': '',
        'author': '',
        'published_at': 0,
        'updated_at': 0,
        'body': '',
        'labels': row['labels'],
        'comment_count': 0,
      });
      for (final label in post.labels) {
        freq[label] = (freq[label] ?? 0) + 1;
      }
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(limit)
        .map((e) => RankedItem(label: e.key, count: e.value))
        .toList();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Escape/sanitize a user query for FTS5 MATCH.
  String _escapeFtsQuery(String query) {
    // Remove characters that would break FTS5 syntax; wrap in quotes for
    // phrase matching when the query contains spaces.
    final cleaned = query
        .replaceAll('"', '""')
        .replaceAll(RegExp(r'[^\w\s"*]'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    // If multi-word, use implicit AND (FTS5 default)
    return '"${cleaned.replaceAll(' ', '" "')}"';
  }
}

// ─── Result types ────────────────────────────────────────────────────────────

class SearchResults {
  final List<PostSearchResult> posts;
  final List<CommentSearchResult> comments;

  const SearchResults({required this.posts, required this.comments});

  bool get isEmpty => posts.isEmpty && comments.isEmpty;
  int get totalCount => posts.length + comments.length;
}

class PostSearchResult {
  final Post post;
  const PostSearchResult({required this.post});
}

class CommentSearchResult {
  final Comment comment;
  final String postTitle;
  final String postUrl;
  const CommentSearchResult({
    required this.comment,
    required this.postTitle,
    required this.postUrl,
  });
}

class ActivityPoint {
  final String label;
  final int count;
  const ActivityPoint({required this.label, required this.count});
}

class RankedItem {
  final String label;
  final int count;
  const RankedItem({required this.label, required this.count});
}
