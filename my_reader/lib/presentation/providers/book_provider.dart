// my_reader/lib/presentation/providers/book_provider.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/data/repositories/book_repository.dart';
import 'package:my_reader/domain/use_cases/get_books.dart';
import 'package:my_reader/infrastructure/epub/epub_parser.dart';
import 'package:my_reader/domain/entities/book_entity.dart';

// Провайдер для репозитория
final bookRepositoryProvider = Provider((ref) => BookRepository(
  DatabaseHelper(),
  EpubParser(),
));

// Провайдер для use case
final getBooksProvider = Provider((ref) => GetBooks(ref.read(bookRepositoryProvider)));

final bookProvider = Provider((ref) => BookProvider(ref));

class BookProvider {
  final Ref _ref;

  BookProvider(this._ref);

  Future<List<BookEntity>> getBooks({String? category}) async {
    return await _ref.read(getBooksProvider).call(category: category);
  }
}