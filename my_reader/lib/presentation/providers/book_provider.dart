import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/data/repositories/book_repository.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/domain/use_cases/get_books.dart';
import 'package:my_reader/domain/use_cases/add_book.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(DatabaseHelper.instance);
});

final getBooksProvider = FutureProvider<List<BookEntity>>((ref) async {
  final repository = ref.watch(bookRepositoryProvider);
  return repository.getBooks();
});

final addBookProvider = Provider<AddBook>((ref) {
  final repository = ref.watch(bookRepositoryProvider);
  return AddBook(repository);
});