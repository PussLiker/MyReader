import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:my_reader/domain/entities/book_entity.dart';

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
            progress INTEGER NOT NULL,
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
            position INTEGER NOT NULL,
            note TEXT NOT NULL,
            FOREIGN KEY (book_id) REFERENCES books(id) ON UPDATE CASCADE ON DELETE RESTRICT
          )
        ''');
        await db.execute('''
          CREATE TABLE quotes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            quote_text TEXT NOT NULL,
            comment TEXT,
            FOREIGN KEY (book_id) REFERENCES books(id) ON UPDATE CASCADE ON DELETE RESTRICT
          )
        ''');
        // Начальные данные для форматов
        await db.insert('formats', {'name': 'EPUB'});
        await db.insert('formats', {'name': 'FB2'});
        await db.insert('formats', {'name': 'TXT'});
      },
    );
  }

  Future<int> insertAuthor(String firstName, String lastName) async {
    final db = await database;
    return await db.insert(
      'authors',
      {'first_name': firstName, 'last_name': lastName},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> getAuthorId(String firstName, String lastName) async {
    final db = await database;
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
    return await db.insert(
      'categories',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
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
    final authorId = await getAuthorId(book.author.split(' ').first, book.author.split(' ').last);
    final formatId = await getFormatId(book.format);
    final categoryId = book.category != null ? await getCategoryId(book.category!) : null;

    return await db.insert(
      'books',
      {
        'title': book.title,
        'author_id': authorId,
        'path': book.path,
        'format_id': formatId,
        'progress': book.progress,
        'category_id': categoryId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BookEntity>> getBooks() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT books.id, books.title, books.path, books.progress,
             formats.name AS format,
             categories.name AS category,
             authors.first_name, authors.last_name
      FROM books
      JOIN authors ON books.author_id = authors.id
      JOIN formats ON books.format_id = formats.id
      LEFT JOIN categories ON books.category_id = categories.id
    ''');
    return List.generate(maps.length, (i) {
      return BookEntity(
        id: maps[i]['id'] as int,
        title: maps[i]['title'] as String,
        author: '${maps[i]['first_name']} ${maps[i]['last_name']}',
        path: maps[i]['path'] as String,
        format: maps[i]['format'] as String,
        coverPath: null, // Обложки пока не поддерживаются
        progress: maps[i]['progress'] as int,
        category: maps[i]['category'] as String?,
      );
    });
  }

  Future<void> updateBook(BookEntity book) async {
    final db = await database;
    final authorId = await getAuthorId(book.author.split(' ').first, book.author.split(' ').last);
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
        'category_id': categoryId,
      },
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<void> deleteBook(int bookId) async {
    final db = await database;
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
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

  Future<int> addBookmark(int bookId, int position, String note) async {
    final db = await database;
    return await db.insert(
      'bookmarks',
      {
        'book_id': bookId,
        'position': position,
        'note': note,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getBookmarks(int bookId) async {
    final db = await database;
    return await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> deleteBookmark(int bookmarkId) async {
    final db = await database;
    await db.delete(
      'bookmarks',
      where: 'id = ?',
      whereArgs: [bookmarkId],
    );
  }

  Future<int> addQuote(int bookId, int position, String quoteText, String? comment) async {
    final db = await database;
    return await db.insert(
      'quotes',
      {
        'book_id': bookId,
        'position': position,
        'quote_text': quoteText,
        'comment': comment,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getQuotes(int bookId) async {
    final db = await database;
    return await db.query(
      'quotes',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
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
    final maps = await db.query('categories');
    return List.generate(maps.length, (i) => maps[i]['name'] as String);
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
}