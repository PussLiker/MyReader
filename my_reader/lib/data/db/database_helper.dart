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
      version: 2, // Увеличиваем версию для миграции
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            path TEXT NOT NULL,
            format TEXT NOT NULL,
            cover_path TEXT,
            progress INTEGER NOT NULL,
            category TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            chapter_index INTEGER NOT NULL,
            description TEXT NOT NULL,
            FOREIGN KEY (book_id) REFERENCES books(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE quotes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            chapter_index INTEGER NOT NULL,
            quote_text TEXT NOT NULL,
            FOREIGN KEY (book_id) REFERENCES books(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE books ADD COLUMN category TEXT');
        }
      },
    );
  }

  Future<void> insertBook(BookEntity book) async {
    final db = await database;
    await db.insert(
      'books',
      {
        'title': book.title,
        'author': book.author,
        'path': book.path,
        'format': book.format,
        'cover_path': book.coverPath,
        'progress': book.progress,
        'category': book.category,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BookEntity>> getBooks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('books');
    return List.generate(maps.length, (i) {
      return BookEntity(
        id: maps[i]['id'],
        title: maps[i]['title'],
        author: maps[i]['author'],
        path: maps[i]['path'],
        format: maps[i]['format'],
        coverPath: maps[i]['cover_path'],
        progress: maps[i]['progress'],
        category: maps[i]['category'],
      );
    });
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

  Future<void> addBookmark(int bookId, int chapterIndex, String description) async {
    final db = await database;
    await db.insert(
      'bookmarks',
      {
        'book_id': bookId,
        'chapter_index': chapterIndex,
        'description': description,
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

  Future<void> addQuote(int bookId, int chapterIndex, String quoteText) async {
    final db = await database;
    await db.insert(
      'quotes',
      {
        'book_id': bookId,
        'chapter_index': chapterIndex,
        'quote_text': quoteText,
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
}