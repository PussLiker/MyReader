import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/data/repositories/book_repository.dart';
import 'package:my_reader/domain/use_cases/add_book.dart';
import 'package:my_reader/domain/use_cases/get_books.dart';
import 'package:my_reader/infrastructure/epub/epub_parser.dart';
import 'package:my_reader/domain/entities/book_entity.dart';

// Провайдер для репозитория
final bookRepositoryProvider = Provider((ref) => BookRepository(
  DatabaseHelper(),
  EpubParser(),
));

// Провайдер для use case GetBooks
final getBooksProvider = Provider((ref) => GetBooks(ref.read(bookRepositoryProvider)));

// Провайдер для use case AddBook
final addBookProvider = Provider((ref) => AddBook(ref.read(bookRepositoryProvider)));

// Провайдер для BookProvider
final bookProvider = Provider((ref) => BookProvider(ref));

class BookProvider {
  final Ref _ref;

  BookProvider(this._ref);

  Future<List<BookEntity>> getBooks({String? category}) async {
    return await _ref.read(getBooksProvider).call(category: category);
  }

  Future<void> addBook({
    required String title,
    required String authorFirstName,
    required String path,
    required String format,
    required String category,
  }) async {
    await _ref.read(addBookProvider).call(
      title: title,
      authorFirstName: authorFirstName,
      path: path,
      format: format,
      category: category,
    );
  }
}