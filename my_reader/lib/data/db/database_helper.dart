// lib/db/database_helper.dart
import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Инициализация БД
  Future<Database> _initDatabase() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'my_reader.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Создание таблиц и вставка начальных данных
  Future<void> _onCreate(Database db, int version) async {
    // Таблица authors
    await db.execute('''
      CREATE TABLE authors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL DEFAULT 'Неизвестен',
        last_name TEXT
      )
    ''');

    // Таблица categories с начальными данными (10 жанров)
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    List<String> genres = [
      'Фантастика', 'Фэнтези', 'Детектив', 'Классика', 'Научная',
      'Приключения', 'Роман', 'Ужасы', 'Поэзия', 'Другое'
    ];
    for (String genre in genres) {
      await db.insert('categories', {'name': genre});
    }

    // Таблица formats с начальными данными (3 формата)
    await db.execute('''
      CREATE TABLE formats (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');
    List<String> formats = ['EPUB', 'FB2', 'TXT'];
    for (String format in formats) {
      await db.insert('formats', {'name': format});
    }

    // Таблица books с FK
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author_id INTEGER NOT NULL,
        path TEXT NOT NULL,
        format_id INTEGER NOT NULL,
        progress REAL NOT NULL,
        category_id INTEGER NOT NULL,
        FOREIGN KEY (author_id) REFERENCES authors(id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (format_id) REFERENCES formats(id) ON UPDATE CASCADE ON DELETE RESTRICT,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON UPDATE CASCADE ON DELETE RESTRICT
      )
    ''');

    // Таблица bookmarks с FK
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        position REAL NOT NULL,
        note TEXT,
        FOREIGN KEY (book_id) REFERENCES books(id) ON UPDATE CASCADE ON DELETE CASCADE
      )
    ''');

    // Таблица quotes с FK
    await db.execute('''
      CREATE TABLE quotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        quote_text TEXT NOT NULL,
        comment TEXT,
        position REAL NOT NULL,
        FOREIGN KEY (book_id) REFERENCES books(id) ON UPDATE CASCADE ON DELETE CASCADE
      )
    ''');
  }

  // Метод для вставки автора (если новый)
  Future<int> insertAuthor(String firstName, String? lastName) async {
    final db = await database;
    // Проверка на существование (чтобы избежать дубликатов)
    List<Map> existing = await db.query(
      'authors',
      where: 'first_name = ? AND last_name = ?',
      whereArgs: [firstName, lastName],
    );
    if (existing.isNotEmpty) {
      return existing.first['id'] as int;
    }
    return await db.insert('authors', {
      'first_name': firstName,
      'last_name': lastName,
    });
  }

  // Метод для получения ID формата по имени (предотвращает ошибки FK)
  Future<int> getFormatId(String name) async {
    final db = await database;
    List<Map> result = await db.query(
      'formats',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (result.isEmpty) {
      throw Exception('Format not found: $name');
    }
    return result.first['id'] as int;
  }

  // Аналогично для category_id
  Future<int> getCategoryId(String name) async {
    final db = await database;
    List<Map> result = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (result.isEmpty) {
      throw Exception('Category not found: $name');
    }
    return result.first['id'] as int;
  }

  // Вставка книги (с проверками FK)
  Future<int> insertBook({
    required String title,
    required int authorId,
    required String path,
    required String formatName,
    required double progress,
    required String categoryName,
  }) async {
    final db = await database;
    int formatId = await getFormatId(formatName);
    int categoryId = await getCategoryId(categoryName);
    // Проверка authorId (должен существовать)
    List<Map> authorCheck = await db.query('authors', where: 'id = ?', whereArgs: [authorId]);
    if (authorCheck.isEmpty) {
      throw Exception('Author ID $authorId does not exist');
    }
    return await db.insert('books', {
      'title': title,
      'author_id': authorId,
      'path': path,
      'format_id': formatId,
      'progress': progress,
      'category_id': categoryId,
    });
  }

  // Обновление прогресса
  Future<void> updateProgress(int bookId, double progress) async {
    final db = await database;
    await db.update(
      'books',
      {'progress': progress},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  // Вставка закладки
  Future<int> insertBookmark(int bookId, double position, String? note) async {
    final db = await database;
    return await db.insert('bookmarks', {
      'book_id': bookId,
      'position': position,
      'note': note,
    });
  }

  // Вставка цитаты
  Future<int> insertQuote(int bookId, String quoteText, String? comment, double position) async {
    final db = await database;
    return await db.insert('quotes', {
      'book_id': bookId,
      'quote_text': quoteText,
      'comment': comment,
      'position': position,
    });
  }

  // Получение списка книг (с JOIN для информации)
  Future<List<Map<String, dynamic>>> getBooks({int? categoryId}) async {
    final db = await database;
    String whereClause = categoryId != null ? 'WHERE b.category_id = ?' : '';
    List<dynamic> whereArgs = categoryId != null ? [categoryId] : [];
    return await db.rawQuery('''
      SELECT b.id, b.title, a.first_name || ' ' || COALESCE(a.last_name, '') AS author, 
             c.name AS category, f.name AS format, b.progress, b.path
      FROM books b
      JOIN authors a ON b.author_id = a.id
      JOIN categories c ON b.category_id = c.id
      JOIN formats f ON b.format_id = f.id
      $whereClause
    ''', whereArgs);
  }

  // Получение закладок для книги
  Future<List<Map<String, dynamic>>> getBookmarks(int bookId) async {
    final db = await database;
    return await db.query('bookmarks', where: 'book_id = ?', whereArgs: [bookId]);
  }

  // Получение цитат для книги
  Future<List<Map<String, dynamic>>> getQuotes(int bookId) async {
    final db = await database;
    return await db.query('quotes', where: 'book_id = ?', whereArgs: [bookId]);
  }

// Другие методы по необходимости (например, deleteBook и т.д.)
}