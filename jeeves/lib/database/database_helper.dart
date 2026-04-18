/// Singleton data-access layer for Jeeves.
///
/// [DatabaseHelper] owns the single SQLite database file (`jeeves.db`) and
/// exposes typed read/write/query methods for every entity in the schema.
///
/// ## Schema overview
/// ```
/// blog_sources  — user-configured Blogger sources
/// posts         — scraped blog posts (with FTS5 virtual table posts_fts)
/// comments      — scraped comments   (with FTS5 virtual table comments_fts)
/// ```
///
/// ## Full-text search
/// Both `posts_fts` and `comments_fts` are SQLite FTS5 *content tables*
/// backed by `posts` and `comments` respectively.  Three triggers
/// (`_ai`, `_ad`, `_au`) keep each FTS table in sync with its content table
/// automatically on every INSERT, DELETE, and UPDATE.
///
/// BM25 relevance ranking is used in [search] queries via SQLite's built-in
/// `bm25()` function.
///
/// ## Usage
/// Obtain the singleton via [DatabaseHelper.instance]; the underlying
/// [Database] is opened lazily on the first access.
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/blog_source.dart';

/// Singleton access point for the local SQLite database.
///
/// All I/O methods are `async` and safe to call from the UI thread; sqflite
/// dispatches SQL work to a background isolate automatically.
class DatabaseHelper {
  /// File name of the SQLite database stored in the platform's default
  /// databases directory (returned by [getDatabasesPath]).
  static const _dbName = 'jeeves.db';

  /// Schema version.  Increment and add a migration in [openDatabase]'s
  /// `onUpgrade` callback whenever the schema changes.
  ///
  /// v1 → v2: replaced `blog_id`/`api_key` columns in `blog_sources` with
  /// `site_url` and `source_type` to support WordPress and Dreamwidth instead
  /// of the Blogger API.
  static const _dbVersion = 2;

  /// Private constructor — access only via [instance].
  DatabaseHelper._();

  /// Application-wide singleton.  All screens and services share this single
  /// instance and therefore the same open database connection.
  static final DatabaseHelper instance = DatabaseHelper._();

  /// Lazily-initialised underlying database connection.
  Database? _db;

  /// Returns the open [Database], opening it if this is the first access.
  ///
  /// Thread-safe because Dart's event loop is single-threaded; the `??=`
  /// assignment cannot race with itself.
  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  /// Opens (or creates) the database at the platform-default path.
  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      // Called once on first open (or after a schema version bump).
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Creates all tables, virtual tables, triggers, and indexes.
  ///
  /// Called by sqflite when the database is first created.  Everything is
  /// executed inside an implicit transaction, so either the entire schema is
  /// created or nothing is (atomic).
  Future<void> _onCreate(Database db, int version) async {
    // ── blog_sources ──────────────────────────────────────────────────────
    // Stores user-configured blog sources (WordPress or Dreamwidth).  Each
    // row drives one scraping job in SyncService.
    await db.execute('''
      CREATE TABLE blog_sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        site_url TEXT NOT NULL,
        source_type TEXT NOT NULL DEFAULT 'wordpress',
        enabled INTEGER NOT NULL DEFAULT 1,
        last_sync_at INTEGER,
        sync_interval_hours INTEGER NOT NULL DEFAULT 24
      )
    ''');

    // ── posts ─────────────────────────────────────────────────────────────
    // One row per scraped blog post.  `labels` is a JSON-encoded string
    // (SQLite has no native array type).  `comment_count` is a denormalised
    // counter updated by updatePostCommentCount() after each comment sync.
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

    // ── posts_fts — FTS5 content table backed by posts ────────────────────
    // An FTS5 *content table* mirrors the indexed columns of `posts` but
    // stores only the FTS index, not the raw text (content=posts).  The
    // `content_rowid` directive tells FTS5 which column in `posts` is its
    // rowid so it can look up the original content when needed.
    //
    // `id` is UNINDEXED because it is a string identifier, not searchable
    // prose — including it avoids a join to get the post ID from results.
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

    // ── Triggers: keep posts_fts in sync with posts ───────────────────────
    // Because posts_fts is a content table, FTS5 does not intercept writes
    // to `posts` automatically.  These three triggers handle INSERT, DELETE,
    // and UPDATE to keep the two tables consistent.

    // After INSERT: add new row to the FTS index.
    await db.execute('''
      CREATE TRIGGER posts_ai AFTER INSERT ON posts BEGIN
        INSERT INTO posts_fts(rowid, id, title, author, body, labels)
        VALUES (new.rowid, new.id, new.title, new.author, new.body, new.labels);
      END
    ''');
    // After DELETE: remove the row from the FTS index using the special
    // 'delete' command recognised by FTS5.
    await db.execute('''
      CREATE TRIGGER posts_ad AFTER DELETE ON posts BEGIN
        INSERT INTO posts_fts(posts_fts, rowid, id, title, author, body, labels)
        VALUES ('delete', old.rowid, old.id, old.title, old.author, old.body, old.labels);
      END
    ''');
    // After UPDATE: remove the old FTS entry then insert the updated one.
    // FTS5 content tables have no native UPDATE command; delete-then-insert
    // is the canonical approach.
    await db.execute('''
      CREATE TRIGGER posts_au AFTER UPDATE ON posts BEGIN
        INSERT INTO posts_fts(posts_fts, rowid, id, title, author, body, labels)
        VALUES ('delete', old.rowid, old.id, old.title, old.author, old.body, old.labels);
        INSERT INTO posts_fts(rowid, id, title, author, body, labels)
        VALUES (new.rowid, new.id, new.title, new.author, new.body, new.labels);
      END
    ''');

    // ── comments ──────────────────────────────────────────────────────────
    // One row per scraped comment.  `parent_id` is NULL for top-level
    // comments and set to the parent comment's ID for replies, enabling the
    // CommentThread widget to reconstruct the thread tree.
    //
    // ON DELETE CASCADE ensures comments are removed if their parent post is
    // ever deleted from `posts`.
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

    // ── comments_fts — FTS5 content table backed by comments ─────────────
    // Mirrors the pattern used for posts_fts above.  `id` and `post_id` are
    // UNINDEXED to avoid wasting space on non-searchable identifiers while
    // still making them available in result rows without a JOIN.
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

    // After INSERT on comments: populate the FTS index.
    await db.execute('''
      CREATE TRIGGER comments_ai AFTER INSERT ON comments BEGIN
        INSERT INTO comments_fts(rowid, id, post_id, author, body)
        VALUES (new.rowid, new.id, new.post_id, new.author, new.body);
      END
    ''');
    // After DELETE on comments: remove from FTS index.
    await db.execute('''
      CREATE TRIGGER comments_ad AFTER DELETE ON comments BEGIN
        INSERT INTO comments_fts(comments_fts, rowid, id, post_id, author, body)
        VALUES ('delete', old.rowid, old.id, old.post_id, old.author, old.body);
      END
    ''');
    // After UPDATE on comments: replace the FTS entry.
    await db.execute('''
      CREATE TRIGGER comments_au AFTER UPDATE ON comments BEGIN
        INSERT INTO comments_fts(comments_fts, rowid, id, post_id, author, body)
        VALUES ('delete', old.rowid, old.id, old.post_id, old.author, old.body);
        INSERT INTO comments_fts(rowid, id, post_id, author, body)
        VALUES (new.rowid, new.id, new.post_id, new.author, new.body);
      END
    ''');

    // ── Indexes ───────────────────────────────────────────────────────────
    // Covering indexes on frequently-filtered columns to speed up the most
    // common query patterns (browsing by blog, sorting by date, joining
    // comments to their post).
    await db.execute(
        'CREATE INDEX posts_blog_id ON posts(blog_id)');
    await db.execute(
        'CREATE INDEX posts_published_at ON posts(published_at)');
    await db.execute(
        'CREATE INDEX comments_post_id ON comments(post_id)');
    await db.execute(
        'CREATE INDEX comments_published_at ON comments(published_at)');
  }

  /// Migrates the database from [oldVersion] to [newVersion].
  ///
  /// v1 → v2: Drop the old `blog_sources` table (which had Blogger-specific
  /// `blog_id` and `api_key` columns) and recreate it with the new
  /// `site_url` and `source_type` columns.  Existing synced posts and
  /// comments are left intact; only the source configuration is cleared,
  /// because old Blogger-based sources would no longer work anyway.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS blog_sources');
      await db.execute('''
        CREATE TABLE blog_sources (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          site_url TEXT NOT NULL,
          source_type TEXT NOT NULL DEFAULT 'wordpress',
          enabled INTEGER NOT NULL DEFAULT 1,
          last_sync_at INTEGER,
          sync_interval_hours INTEGER NOT NULL DEFAULT 24
        )
      ''');
    }
  }

  // ─── Blog Sources ────────────────────────────────────────────────────────

  /// Returns all [BlogSource] rows from the database, unordered.
  Future<List<BlogSource>> getBlogSources() async {
    final db = await database;
    final rows = await db.query('blog_sources');
    return rows.map(BlogSource.fromMap).toList();
  }

  /// Inserts or replaces a [BlogSource] row (upsert by primary key).
  ///
  /// Used both when creating a new source and when editing an existing one
  /// in [SettingsScreen].
  Future<void> upsertBlogSource(BlogSource source) async {
    final db = await database;
    await db.insert(
      'blog_sources',
      source.toMap(),
      // REPLACE conflict resolution: if a row with the same `id` already
      // exists, it is deleted and re-inserted with the new values.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Permanently deletes the [BlogSource] identified by [id].
  ///
  /// Existing posts and comments scraped for this source are **not** deleted
  /// (they remain available for search and analytics).
  Future<void> deleteBlogSource(String id) async {
    final db = await database;
    await db.delete('blog_sources', where: 'id = ?', whereArgs: [id]);
  }

  /// Updates the `last_sync_at` timestamp of [blogSourceId] to `DateTime.now()`.
  ///
  /// Called by [SyncService] after a source's posts and comments have been
  /// successfully written to the database.
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

  /// Inserts or replaces a single [Post] row (upsert by primary key).
  Future<void> upsertPost(Post post) async {
    final db = await database;
    await db.insert(
      'posts',
      post.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Batch-upserts a list of [Post] rows inside a single database transaction.
  ///
  /// Using [Database.batch] reduces the number of round-trips to the
  /// sqflite isolate, which dramatically improves throughput when syncing
  /// large numbers of posts.
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
    // noResult: true avoids allocating a result list for each insert,
    // improving performance for large batches.
    await batch.commit(noResult: true);
  }

  /// Fetches the [Post] with the given [id], or `null` if no such post exists.
  Future<Post?> getPost(String id) async {
    final db = await database;
    final rows = await db.query('posts', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Post.fromMap(rows.first);
  }

  /// Returns a list of [Post] rows, optionally filtered and paginated.
  ///
  /// Parameters:
  /// - [siteUrl]: when provided, limits results to posts from that source.
  /// - [limit] / [offset]: control pagination (SQLite LIMIT / OFFSET).
  /// - [orderBy]: SQL ORDER BY clause; defaults to `published_at DESC`.
  Future<List<Post>> getPosts({
    String? siteUrl,
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    final db = await database;
    final rows = await db.query(
      'posts',
      where: siteUrl != null ? 'blog_id = ?' : null,
      whereArgs: siteUrl != null ? [siteUrl] : null,
      orderBy: orderBy ?? 'published_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Post.fromMap).toList();
  }

  /// Returns the most recent `updated_at` timestamp across all posts for
  /// [siteUrl], or `null` if no posts exist for that source.
  ///
  /// Used by [SyncService] to set the incremental sync boundary, so that
  /// only posts modified after this timestamp are fetched on subsequent syncs.
  Future<DateTime?> getLatestPostUpdatedAt(String siteUrl) async {
    final db = await database;
    final rows = await db.query(
      'posts',
      columns: ['MAX(updated_at) as max_updated'],
      where: 'blog_id = ?',
      whereArgs: [siteUrl],
    );
    if (rows.isEmpty || rows.first['max_updated'] == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(
        rows.first['max_updated'] as int);
  }

  // ─── Comments ────────────────────────────────────────────────────────────

  /// Batch-upserts a list of [Comment] rows inside a single transaction.
  ///
  /// Follows the same batching strategy as [upsertPosts] for performance.
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

  /// Returns all [Comment]s for [postId], ordered chronologically
  /// (oldest first) so that the [CommentThread] widget displays replies
  /// after the comments they respond to.
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

  /// Recomputes and stores the comment count for [postId] by counting rows
  /// in the `comments` table.
  ///
  /// Must be called after [upsertComments] so that [Post.commentCount] stays
  /// accurate for display in list tiles and analytics queries.
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

  /// Searches posts and/or comments using FTS5 BM25 ranking.
  ///
  /// Returns a [SearchResults] object containing separate lists for
  /// [PostSearchResult]s and [CommentSearchResult]s, both ordered by BM25
  /// relevance (ascending — lower BM25 means a better match in SQLite's
  /// implementation).
  ///
  /// Parameters:
  /// - [query]: the user's search string; sanitised by [_escapeFtsQuery]
  ///   before being passed to the FTS5 MATCH operator.
  /// - [searchPosts] / [searchComments]: independently toggle which entity
  ///   types are included in the results.
  /// - [authorFilter]: case-insensitive substring match on the `author`
  ///   column (applied as a SQL LIKE filter after the FTS MATCH).
  /// - [labelFilter]: substring match on the serialised `labels` column.
  /// - [fromDate] / [toDate]: inclusive date range filter on `published_at`.
  /// - [limit]: maximum number of results per entity type (default 50).
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
    // Sanitise the user query to prevent FTS5 syntax errors.
    final ftsQuery = _escapeFtsQuery(query);

    final List<PostSearchResult> postResults = [];
    final List<CommentSearchResult> commentResults = [];

    if (searchPosts && ftsQuery.isNotEmpty) {
      // Start with the mandatory FTS MATCH predicate, then append any
      // optional SQL filters.  Positional arguments (`?`) are used throughout
      // to prevent SQL injection.
      final whereClauses = <String>['posts_fts MATCH ?'];
      final args = <dynamic>[ftsQuery];

      if (authorFilter != null && authorFilter.isNotEmpty) {
        whereClauses.add("p.author LIKE ?");
        args.add('%$authorFilter%');
      }
      if (labelFilter != null && labelFilter.isNotEmpty) {
        // labels is stored as a JSON array string; LIKE works as a substring
        // match, which is good enough for typical label queries.
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

      // JOIN posts_fts to posts so we can apply SQL column filters and
      // retrieve the full post row in a single query.  bm25() returns a
      // negative score; ORDER BY rank puts the best matches first.
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
        // Remove the synthetic `rank` column before passing to Post.fromMap.
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

      // Also JOIN to posts so the result row includes the parent post's
      // title and URL, which are shown in the search result tile.
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
        // Manually extract comment columns (excluding synthetic ones) to
        // avoid passing unknown keys to Comment.fromMap.
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

  /// Returns the number of posts published in each calendar month (UTC),
  /// ordered chronologically, as [ActivityPoint] records.
  ///
  /// The label format is `"YYYY-MM"` (e.g. `"2024-03"`), which is used by
  /// [ActivityChart] to render axis tick labels.
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

  /// Returns the number of comments published in each calendar month (UTC),
  /// ordered chronologically, as [ActivityPoint] records.
  ///
  /// Used alongside [getPostActivityByMonth] in the Analytics dashboard to
  /// compare post frequency with community engagement trends.
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

  /// Returns the top [limit] commenters ranked by total comment count,
  /// as [RankedItem] records (label = author name, count = number of comments).
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

  /// Returns the [limit] most-commented posts, ordered by [Post.commentCount]
  /// descending.
  ///
  /// The [commentCount] column is a denormalised counter updated by
  /// [updatePostCommentCount], so this query is an efficient indexed scan
  /// rather than a subquery.
  Future<List<Post>> getMostCommentedPosts({int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'posts',
      orderBy: 'comment_count DESC',
      limit: limit,
    );
    return rows.map(Post.fromMap).toList();
  }

  /// Returns the [limit] most frequently used labels across all posts, as
  /// [RankedItem] records (label = tag string, count = number of posts).
  ///
  /// Because labels are stored as a JSON-encoded array per post, this method
  /// reads the raw `labels` column for every post and tallies frequencies in
  /// Dart.  For large corpora a SQL-based approach (e.g. a normalised labels
  /// table) would be more efficient, but is unnecessary at typical blog scale.
  Future<List<RankedItem>> getLabelFrequency({int limit = 30}) async {
    final db = await database;
    // Only fetch the `labels` column to minimise data transfer from the
    // sqflite isolate.
    final rows = await db.query('posts', columns: ['labels']);
    final freq = <String, int>{};
    for (final row in rows) {
      // Reuse Post's _decodeLabels logic by constructing a minimal Post map.
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
    // Sort by frequency descending and take the top N.
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(limit)
        .map((e) => RankedItem(label: e.key, count: e.value))
        .toList();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Sanitises a raw user search string for safe use in an FTS5 MATCH clause.
  ///
  /// Strategy:
  /// 1. Double-quote any literal `"` characters to escape them.
  /// 2. Remove characters outside `\w`, `\s`, `"`, and `*` that would be
  ///    interpreted as FTS5 operators (e.g. `-`, `:`, `^`).
  /// 3. Wrap each whitespace-separated token in double-quotes so the query
  ///    behaves as an implicit AND of phrase queries rather than ambiguous
  ///    operator expressions.
  ///
  /// Returns an empty string if nothing remains after cleaning, which the
  /// caller should treat as "no search".
  String _escapeFtsQuery(String query) {
    final cleaned = query
        // Escape any literal double-quotes so they don't break the phrase
        // syntax we apply below.
        .replaceAll('"', '""')
        // Strip characters that carry special meaning in FTS5 query syntax
        // (column filters, boolean operators, etc.) but are not part of a
        // normal keyword search.
        .replaceAll(RegExp(r'[^\w\s"*]'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';
    // Wrap each space-separated token in double-quotes to form exact phrase
    // queries.  Multi-word input becomes: "word1" "word2" which FTS5 treats
    // as an implicit AND.
    return '"${cleaned.replaceAll(' ', '" "')}"';
  }
}

// ─── Result types ────────────────────────────────────────────────────────────

/// Aggregated container for a full-text search result set.
///
/// Returned by [DatabaseHelper.search]; contains separate ranked lists for
/// post and comment matches so the UI can display them in distinct sections.
class SearchResults {
  /// Ranked list of matching posts (best BM25 score first).
  final List<PostSearchResult> posts;

  /// Ranked list of matching comments (best BM25 score first).
  final List<CommentSearchResult> comments;

  const SearchResults({required this.posts, required this.comments});

  /// `true` when both [posts] and [comments] are empty (no results found).
  bool get isEmpty => posts.isEmpty && comments.isEmpty;

  /// Total number of individual results across both entity types.
  int get totalCount => posts.length + comments.length;
}

/// Wraps a single [Post] result from a full-text search query.
///
/// Currently a thin wrapper; extended in the future to carry snippet/
/// highlight offset information from FTS5.
class PostSearchResult {
  /// The matched post.
  final Post post;
  const PostSearchResult({required this.post});
}

/// Wraps a single [Comment] result from a full-text search query, enriched
/// with the title and URL of the comment's parent post so that the search
/// result tile can display context without a second database lookup.
class CommentSearchResult {
  /// The matched comment.
  final Comment comment;

  /// Title of the post that contains this comment.
  final String postTitle;

  /// Canonical URL of the post that contains this comment.
  final String postUrl;

  const CommentSearchResult({
    required this.comment,
    required this.postTitle,
    required this.postUrl,
  });
}

/// A single data point used by the analytics charts and ranked lists.
///
/// [label] is a human-readable identifier (e.g. a month string `"2024-03"` or
/// a commenter name); [count] is the associated numeric value.
class ActivityPoint {
  /// Human-readable x-axis label, e.g. `"2024-03"` for March 2024.
  final String label;

  /// The numeric value associated with [label] (e.g. number of posts).
  final int count;

  const ActivityPoint({required this.label, required this.count});
}

/// A label-count pair used to represent ranked items such as top commenters
/// or label frequencies in the analytics dashboard.
class RankedItem {
  /// The item's display name (commenter handle, tag string, etc.).
  final String label;

  /// The item's score (comment count, post count, etc.).
  final int count;

  const RankedItem({required this.label, required this.count});
}
