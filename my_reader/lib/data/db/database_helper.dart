import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import '../../domain/entities/reading_position.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  DatabaseHelper._();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'books.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateToV2(db);
        }
        if (oldVersion < 3) {
          await _migrateToV3(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE authors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE formats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author_id INTEGER NOT NULL,
        path TEXT NOT NULL,
        format_id INTEGER NOT NULL,
        progress INTEGER NOT NULL DEFAULT 0,
        position REAL NOT NULL DEFAULT 0.0,
        category_id INTEGER,
        FOREIGN KEY (author_id) REFERENCES authors(id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (format_id) REFERENCES formats(id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON UPDATE CASCADE ON DELETE RESTRICT
      )
    ''');
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        position REAL NOT NULL,
        note TEXT NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON UPDATE CASCADE ON DELETE RESTRICT
      )
    ''');
    await db.execute('''
      CREATE TABLE quotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        position REAL NOT NULL,
        quote_text TEXT NOT NULL,
        comment TEXT,
        FOREIGN KEY (book_id) REFERENCES books(id) ON UPDATE CASCADE ON DELETE RESTRICT
      )
    ''');

    await db.insert('formats', {'name': 'EPUB'});
    await db.insert('formats', {'name': 'FB2'});
    await db.insert('formats', {'name': 'TXT'});
  }

  Future<void> _migrateToV2(Database db) async {
    await db.execute('''
      ALTER TABLE books ADD COLUMN position REAL NOT NULL DEFAULT 0.0
    ''');
    await db.execute('''
      ALTER TABLE bookmarks ADD COLUMN position_real REAL
    ''');
    await db.execute('''
      UPDATE bookmarks SET position_real = CAST(position AS REAL)
    ''');
    await db.execute('''
      ALTER TABLE bookmarks DROP COLUMN position
    ''');
    await db.execute('''
      ALTER TABLE bookmarks RENAME COLUMN position_real TO position
    ''');
    await db.execute('''
      ALTER TABLE quotes ADD COLUMN position_real REAL
    ''');
    await db.execute('''
      UPDATE quotes SET position_real = CAST(position AS REAL)
    ''');
    await db.execute('''
      ALTER TABLE quotes DROP COLUMN position
    ''');
    await db.execute('''
      ALTER TABLE quotes RENAME COLUMN position_real TO position
    ''');
  }

  Future<void> _migrateToV3(Database db) async {
    await db.execute('''
      ALTER TABLE bookmarks ADD COLUMN chapter_index REAL
    ''');
    await db.execute('''
      ALTER TABLE bookmarks ADD COLUMN char_offset INTEGER
    ''');
    await db.execute('''
      ALTER TABLE bookmarks ADD COLUMN selected_text TEXT
    ''');
    await db.execute('''
      ALTER TABLE quotes ADD COLUMN chapter_index REAL
    ''');
    await db.execute('''
      ALTER TABLE quotes ADD COLUMN char_offset INTEGER
    ''');
    await db.execute('''
      UPDATE bookmarks SET chapter_index = position, char_offset = 0
    ''');
    await db.execute('''
      UPDATE quotes SET chapter_index = position, char_offset = 0
    ''');
  }

  Future<int> insertAuthor(String firstName, String lastName) async {
    final db = await database;
    final id = await db.insert(
      'authors',
      {'first_name': firstName, 'last_name': lastName},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return id;
  }

  Future<int> getAuthorId(String author) async {
    final db = await database;
    final parts = author.trim().split(' ');
    final firstName = parts.isNotEmpty ? parts[0] : author;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final maps = await db.query(
      'authors',
      where: 'first_name = ? AND last_name = ?',
      whereArgs: [firstName, lastName],
    );
    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    }
    return await insertAuthor(firstName, lastName);
  }

  Future<int> insertCategory(String name) async {
    final db = await database;
    final id = await db.insert(
      'categories',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return id;
  }

  Future<int> getCategoryId(String name) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    }
    return await insertCategory(name);
  }

  Future<int> getFormatId(String name) async {
    final db = await database;
    final maps = await db.query(
      'formats',
      where: 'name = ?',
      whereArgs: [name.toUpperCase()],
    );
    if (maps.isNotEmpty) {
      return maps.first['id'] as int;
    }
    throw Exception('Format $name not found');
  }

  Future<int> insertBook(BookEntity book) async {
    final db = await database;
    final authorId = await getAuthorId(book.author);
    final formatId = await getFormatId(book.format);
    final categoryId = book.category != null ? await getCategoryId(book.category!) : null;

    final id = await db.insert(
      'books',
      {
        'title': book.title,
        'author_id': authorId,
        'path': book.path,
        'format_id': formatId,
        'progress': book.progress,
        'position': book.position,
        'category_id': categoryId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<BookEntity>> getBooks() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT books.id, books.title, books.path, books.progress, books.position,
             formats.name AS format,
             categories.name AS category,
             authors.first_name, authors.last_name
      FROM books
      JOIN authors ON books.author_id = authors.id
      JOIN formats ON books.format_id = formats.id
      LEFT JOIN categories ON books.category_id = categories.id
    ''');
    final books = List.generate(maps.length, (i) {
      return BookEntity(
        id: maps[i]['id'] as int,
        title: maps[i]['title'] as String,
        author: '${maps[i]['first_name']} ${maps[i]['last_name']}'.trim(),
        path: maps[i]['path'] as String,
        format: maps[i]['format'] as String,
        coverPath: null,
        progress: maps[i]['progress'] as int,
        category: maps[i]['category'] as String?,
        position: (maps[i]['position'] as num).toDouble(),
      );
    });
    return books;
  }

  Future<List<BookEntity>> getBooksByCategory(String category) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT books.id, books.title, books.path, books.progress, books.position,
             formats.name AS format,
             categories.name AS category,
             authors.first_name, authors.last_name
      FROM books
      JOIN authors ON books.author_id = authors.id
      JOIN formats ON books.format_id = formats.id
      LEFT JOIN categories ON books.category_id = categories.id
      WHERE categories.name = ?
    ''', [category]);
    final books = List.generate(maps.length, (i) {
      return BookEntity(
        id: maps[i]['id'] as int,
        title: maps[i]['title'] as String,
        author: '${maps[i]['first_name']} ${maps[i]['last_name']}'.trim(),
        path: maps[i]['path'] as String,
        format: maps[i]['format'] as String,
        coverPath: null,
        progress: maps[i]['progress'] as int,
        category: maps[i]['category'] as String?,
        position: (maps[i]['position'] as num).toDouble(),
      );
    });
    return books;
  }

  Future<void> updateBook(BookEntity book) async {
    final db = await database;
    final authorId = await getAuthorId(book.author);
    final formatId = await getFormatId(book.format);
    final categoryId = book.category != null ? await getCategoryId(book.category!) : null;

    await db.update(
      'books',
      {
        'title': book.title,
        'author_id': authorId,
        'path': book.path,
        'format_id': formatId,
        'progress': book.progress,
        'position': book.position,
        'category_id': categoryId,
      },
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<void> deleteBook(int bookId) async {
    final db = await database;
    await db.delete('bookmarks', where: 'book_id = ?', whereArgs: [bookId]);
    await db.delete('quotes', where: 'book_id = ?', whereArgs: [bookId]);
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
    await db.rawDelete('''
      DELETE FROM categories 
      WHERE id NOT IN (SELECT DISTINCT category_id FROM books WHERE category_id IS NOT NULL)
    ''');
  }

  Future<void> updateProgress(int bookId, int progress) async {
    final db = await database;
    await db.update(
      'books',
      {'progress': progress},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> updatePosition(int bookId, double position) async {
    final db = await database;
    await db.update(
      'books',
      {'position': position},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<int> addBookmark(int bookId, double position, String note) async {
    final db = await database;
    final id = await db.insert(
      'bookmarks',
      {
        'book_id': bookId,
        'position': position,
        'note': note,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> getBookmarks(int bookId) async {
    final db = await database;
    final bookmarks = await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return bookmarks;
  }

  Future<void> deleteBookmark(int bookmarkId) async {
    final db = await database;
    await db.delete(
      'bookmarks',
      where: 'id = ?',
      whereArgs: [bookmarkId],
    );
  }

  Future<int> addQuote(int bookId, double position, String quoteText, String? comment) async {
    final db = await database;
    final id = await db.insert(
      'quotes',
      {
        'book_id': bookId,
        'position': position,
        'quote_text': quoteText,
        'comment': comment,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> getQuotes(int bookId) async {
    final db = await database;
    final quotes = await db.query(
      'quotes',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return quotes;
  }

  Future<void> deleteQuote(int quoteId) async {
    final db = await database;
    await db.delete(
      'quotes',
      where: 'id = ?',
      whereArgs: [quoteId],
    );
  }

  Future<List<String>> getCategories() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT DISTINCT categories.name 
      FROM categories 
      JOIN books ON categories.id = books.category_id 
      WHERE books.category_id IS NOT NULL
    ''');
    final categories = List.generate(maps.length, (i) => maps[i]['name'] as String);
    return categories;
  }

  Future<bool> categoryExists(String name) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
    );
    return maps.isNotEmpty;
  }

  Future<BookEntity?> getBookById(int bookId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT books.id, books.title, books.path, books.progress, books.position,
             formats.name AS format,
             categories.name AS category,
             authors.first_name, authors.last_name
      FROM books
      JOIN authors ON books.author_id = authors.id
      JOIN formats ON books.format_id = formats.id
      LEFT JOIN categories ON books.category_id = categories.id
      WHERE books.id = ?
    ''', [bookId]);

    if (maps.isNotEmpty) {
      final map = maps.first;
      return BookEntity(
        id: map['id'] as int,
        title: map['title'] as String,
        author: '${map['first_name']} ${map['last_name']}'.trim(),
        path: map['path'] as String,
        format: map['format'] as String,
        coverPath: null,
        progress: map['progress'] as int,
        category: map['category'] as String?,
        position: (map['position'] as num).toDouble(),
      );
    }
    return null;
  }

  Future<int> addBookmarkWithPosition(int bookId, ReadingPosition position, String note) async {
    final db = await database;
    final id = await db.insert(
      'bookmarks',
      {
        'book_id': bookId,
        'chapter_index': position.chapterIndex,
        'char_offset': position.charOffset,
        'selected_text': position.selectedText,
        'note': note,
      },
    );
    return id;
  }

  Future<int> addQuoteWithPosition(int bookId, ReadingPosition position, String quoteText, String? comment) async {
    final db = await database;
    final id = await db.insert(
      'quotes',
      {
        'book_id': bookId,
        'chapter_index': position.chapterIndex,
        'char_offset': position.charOffset,
        'quote_text': quoteText,
        'comment': comment,
      },
    );
    return id;
  }

  Future<List<ReadingPosition>> getBookmarksWithPosition(int bookId) async {
    final db = await database;
    final bookmarks = await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );

    return bookmarks.map((bm) => ReadingPosition(
      id: bm['id'] as int,
      chapterIndex: (bm['chapter_index'] as num?)?.toDouble() ?? (bm['position'] as num).toDouble(),
      charOffset: bm['char_offset'] as int? ?? 0,
      selectedText: bm['selected_text'] as String?,
      note: bm['note'] as String?,
    )).toList();
  }

  Future<List<ReadingPosition>> getQuotesWithPosition(int bookId) async {
    final db = await database;
    final quotes = await db.query(
      'quotes',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );

    return quotes.map((q) => ReadingPosition(
      id: q['id'] as int,
      chapterIndex: (q['chapter_index'] as num?)?.toDouble() ?? (q['position'] as num).toDouble(),
      charOffset: q['char_offset'] as int? ?? 0,
      selectedText: q['quote_text'] as String?,
      comment: q['comment'] as String?,
    )).toList();
  }

  Future<void> deleteBookmarkById(int bookmarkId) async {
    final db = await database;
    await db.delete(
      'bookmarks',
      where: 'id = ?',
      whereArgs: [bookmarkId],
    );
  }

  Future<void> deleteQuoteById(int quoteId) async {
    final db = await database;
    await db.delete(
      'quotes',
      where: 'id = ?',
      whereArgs: [quoteId],
    );
  }

  Future<List<Map<String, dynamic>>> getBookmarksWithDetails([int? bookId]) async {
    final db = await database;
    final where = bookId != null && bookId > 0 ? 'book_id = ?' : '1=1';
    final whereArgs = bookId != null && bookId > 0 ? [bookId] : [];

    final bookmarks = await db.query(
      'bookmarks',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
    return bookmarks;
  }

  Future<List<Map<String, dynamic>>> getQuotesWithDetails([int? bookId]) async {
    final db = await database;
    final where = bookId != null && bookId > 0 ? 'book_id = ?' : '1=1';
    final whereArgs = bookId != null && bookId > 0 ? [bookId] : [];

    final quotes = await db.query(
      'quotes',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
    return quotes;
  }
}