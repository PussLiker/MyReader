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
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS bookmarks');
    await db.execute('DROP TABLE IF EXISTS quotes');
    await db.execute('DROP TABLE IF EXISTS books');
    await db.execute('DROP TABLE IF EXISTS authors');
    await db.execute('DROP TABLE IF EXISTS formats');
    await db.execute('DROP TABLE IF EXISTS categories');

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
    chapter_index REAL NOT NULL,
    position REAL NOT NULL DEFAULT 0.0,
    char_offset INTEGER NOT NULL,
    note TEXT,           
    title TEXT,          
    color INTEGER,       
    FOREIGN KEY (book_id) REFERENCES books(id) ON UPDATE CASCADE ON DELETE CASCADE
  )
''');

    await db.execute('''
      CREATE TABLE quotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        chapter_index REAL NOT NULL,
        position REAL NOT NULL DEFAULT 0.0,
        char_offset INTEGER NOT NULL,
        quote_text TEXT NOT NULL,
        comment TEXT,
        FOREIGN KEY (book_id) REFERENCES books(id) ON UPDATE CASCADE ON DELETE CASCADE
      )
    ''');

    await db.insert('formats', {'name': 'EPUB'});
    await db.insert('formats', {'name': 'FB2'});
    await db.insert('formats', {'name': 'TXT'});
    await db.insert('formats', {'name': 'PDF'});
  }

  // --- Методы для Авторов ---
  Future<int> insertAuthor(String firstName, String lastName) async {
    final db = await database;
    return await db.insert(
      'authors',
      {'first_name': firstName, 'last_name': lastName},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
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
    if (maps.isNotEmpty) return maps.first['id'] as int;
    return await insertAuthor(firstName, lastName);
  }

  // --- Методы для Книг ---
  Future<int> insertBook(BookEntity book) async {
    final db = await database;
    final authorId = await getAuthorId(book.author);
    final formatId = await getFormatId(book.format);
    final categoryId =
        book.category != null ? await getCategoryId(book.category!) : null;

    return await db.insert(
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
  }

  Future<void> updatePosition(int bookId, int progress, double position) async {
    final db = await database;
    await db.update(
      'books',
      {
        'progress': progress, // Номер главы (int)
        'position': position, // Процент скролла (double/REAL)
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<List<BookEntity>> getBooks() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT books.*, formats.name AS format, categories.name AS category,
             authors.first_name, authors.last_name
      FROM books
      JOIN authors ON books.author_id = authors.id
      JOIN formats ON books.format_id = formats.id
      LEFT JOIN categories ON books.category_id = categories.id
    ''');
    return maps.map((m) => _mapToBookEntity(m)).toList();
  }

  Future<BookEntity?> getBookById(int bookId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT books.*, formats.name AS format, categories.name AS category,
             authors.first_name, authors.last_name
      FROM books
      JOIN authors ON books.author_id = authors.id
      JOIN formats ON books.format_id = formats.id
      LEFT JOIN categories ON books.category_id = categories.id
      WHERE books.id = ?
    ''', [bookId]);
    return maps.isNotEmpty ? _mapToBookEntity(maps.first) : null;
  }

  // --- Закладки ---
  Future<int> addBookmarkWithPosition(int bookId, ReadingPosition pos,
      String title, String note, int color) async {
    final db = await database;
    return await db.insert('bookmarks', {
      'book_id': bookId,
      'chapter_index': pos.chapterIndex,
      'position': pos.position,
      'char_offset': pos.charOffset,
      'title': title,
      'note': note,
      'color': color,
    });
  }

  // --- Цитаты ---
  Future<int> addQuoteWithPosition(
      int bookId, ReadingPosition pos, String text, String? comment) async {
    final db = await database;
    return await db.insert('quotes', {
      'book_id': bookId,
      'chapter_index': pos.chapterIndex,
      'position': pos.position,
      'char_offset': pos.charOffset,
      'quote_text': text,
      'comment': comment,
    });
  }

  // Обновление существующей закладки
  Future<int> updateBookmark(ReadingPosition bookmark) async {
    final db = await database;
    return await db.update(
      'bookmarks',
      {
        'title': bookmark.title,
        'note': bookmark.note,
        'color': bookmark.color,
        'char_offset': bookmark.charOffset,
      },
      where: 'id = ?',
      whereArgs: [bookmark.id],
    );
  }

  // Обновленный метод получения закладок (с учетом новых полей)
  Future<List<ReadingPosition>> getBookmarksWithPosition(int bookId) async {
    final db = await database;
    final maps =
        await db.query('bookmarks', where: 'book_id = ?', whereArgs: [bookId]);
    return maps.map((m) => ReadingPosition.fromMap(m)).toList();
  }

  // --- Обновление комментария у существующей цитаты ---
  Future<int> updateQuoteComment(int id, String? comment) async {
    print("--- DB UPDATE --- ID: $id, COMMENT: $comment");
    final db = await instance.database;
    final result = await db.update(
      'quotes',
      {'comment': comment},
      where: 'id = ?',
      whereArgs: [id],
    );
    print("DB result (rows affected): $result");
    return result;
  }

  Future<List<ReadingPosition>> getQuotesWithPosition(int bookId) async {
    final db = await database;
    final maps =
        await db.query('quotes', where: 'book_id = ?', whereArgs: [bookId]);
    return maps
        .map((m) => ReadingPosition(
              id: m['id'] as int,
              chapterIndex: (m['chapter_index'] as num).toDouble(),
              position: (m['position'] as num? ?? 0.0).toDouble(),
              charOffset: m['char_offset'] as int,
              selectedText: m['quote_text'] as String?,
              comment: m['comment'] as String?,
            ))
        .toList();
  }

  // --- Вспомогательные методы ---
  BookEntity _mapToBookEntity(Map<String, dynamic> m) {
    return BookEntity(
      id: m['id'] as int,
      title: m['title'] as String,
      author: '${m['first_name']} ${m['last_name']}'.trim(),
      path: m['path'] as String,
      format: m['format'] as String,
      coverPath: null,
      progress: m['progress'] as int,
      category: m['category'] as String?,
      position: (m['position'] as num? ?? 0.0).toDouble(),
    );
  }

  Future<int> getFormatId(String name) async {
    final db = await database;
    final maps = await db
        .query('formats', where: 'name = ?', whereArgs: [name.toUpperCase()]);
    if (maps.isNotEmpty) return maps.first['id'] as int;
    throw Exception('Format $name not found');
  }

  Future<int> getCategoryId(String name) async {
    final db = await database;
    final maps =
        await db.query('categories', where: 'name = ?', whereArgs: [name]);
    if (maps.isNotEmpty) return maps.first['id'] as int;
    return await db.insert('categories', {'name': name});
  }

  Future<void> deleteBook(int bookId) async {
    final db = await database;
    await db.delete('bookmarks', where: 'book_id = ?', whereArgs: [bookId]);
    await db.delete('quotes', where: 'book_id = ?', whereArgs: [bookId]);
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
    await db.rawDelete(
        'DELETE FROM categories WHERE id NOT IN (SELECT DISTINCT category_id FROM books WHERE category_id IS NOT NULL)');
  }

  Future<void> deleteBookmarkById(int id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteQuoteById(int id) async {
    final db = await database;
    await db.delete('quotes', where: 'id = ?', whereArgs: [id]);
  }

  // Получение всех цитат с данными о книгах
  Future<List<Map<String, dynamic>>> getQuotesWithDetails() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT 
      q.*, 
      b.id as book_id, 
      b.title as book_title, 
      authors.first_name || ' ' || authors.last_name as book_author
    FROM quotes q
    JOIN books b ON q.book_id = b.id
    JOIN authors ON b.author_id = authors.id
    ORDER BY b.title ASC, q.chapter_index ASC
  ''');
  }

// Метод для обновления книги
  Future<int> updateBook(BookEntity book) async {
    final db = await database;
    final authorId = await getAuthorId(book.author);
    final formatId = await getFormatId(book.format);
    final categoryId =
        book.category != null ? await getCategoryId(book.category!) : null;

    return await db.update(
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

  // --- Проверка существования закладки на той же позиции ---
  Future<bool> bookmarkExists(int bookId, int charOffset) async {
    final db = await database;
    final result = await db.query(
      'bookmarks',
      where: 'book_id = ? AND char_offset = ?',
      whereArgs: [bookId, charOffset],
    );
    return result.isNotEmpty;
  }

  Future<void> cleanupOrphanedCategories() async {
    final db = await database;
    await db.rawDelete('''
    DELETE FROM categories 
    WHERE id NOT IN (SELECT DISTINCT category_id FROM books WHERE category_id IS NOT NULL)
  ''');
  }

// --- Проверка существования цитаты на той же позиции ---
  Future<bool> quoteExists(int bookId, int charOffset) async {
    final db = await database;
    final result = await db.query(
      'quotes',
      where: 'book_id = ? AND char_offset = ?',
      whereArgs: [bookId, charOffset],
    );
    return result.isNotEmpty;
  }

  Future<bool> anyMarkExists(int bookId, int charOffset) async {
    final db = await database;

    final bookmarks = await db.query(
      'bookmarks',
      where: 'book_id = ? AND char_offset = ?',
      whereArgs: [bookId, charOffset],
    );

    final quotes = await db.query(
      'quotes',
      where: 'book_id = ? AND char_offset = ?',
      whereArgs: [bookId, charOffset],
    );

    return bookmarks.isNotEmpty || quotes.isNotEmpty;
  }

  Future<List<String>> getCategories() async {
    final db = await database;
    final maps = await db.rawQuery('SELECT name FROM categories ORDER BY name');
    return maps.map((m) => m['name'] as String).toList();
  }
}
