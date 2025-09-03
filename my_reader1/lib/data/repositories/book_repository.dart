// my_reader/lib/data/repositories/book_repository.dart
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/infrastructure/epub/epub_parser.dart';

class BookRepository {
  final DatabaseHelper db;
  final EpubParser epubParser;

  BookRepository(this.db, this.epubParser);

  Future<int> addBook({
    required String title,
    required String authorFirstName,
    String? authorLastName,
    required String path,
    required String format,
    required String category,
    double progress = 0.0,
  }) async {
    try {
      int authorId = await db.insertAuthor(authorFirstName, authorLastName);
      return await db.insertBook(
        title: title,
        authorId: authorId,
        path: path,
        formatName: format,
        progress: progress,
        categoryName: category,
      );
    } catch (e) {
      if (e.toString().contains('FOREIGN KEY')) {
        throw Exception('FOREIGN KEY constraint failed: проверьте автор, формат или категорию');
      }
      rethrow;
    }
  }

  Future<List<BookEntity>> getBooks({String? category}) async {
    int? categoryId = category != null ? await db.getCategoryId(category) : null;
    final books = await db.getBooks(categoryId: categoryId);
    return books.map((b) => BookEntity(
      id: b['id'],
      title: b['title'],
      author: b['author'],
      category: b['category'],
      format: b['format'],
      progress: b['progress'],
      path: b['path'],
    )).toList();
  }
}