import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/data/repositories/book_repository.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/domain/use_cases/get_books.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final databaseHelper = ref.watch(databaseHelperProvider);
  return BookRepository(databaseHelper);
});

final getBooksProvider = FutureProvider.family<List<BookEntity>, String?>((ref, category) async {
  final repository = ref.watch(bookRepositoryProvider);
  final getBooks = GetBooks(repository);
  return await getBooks(category: category);
});