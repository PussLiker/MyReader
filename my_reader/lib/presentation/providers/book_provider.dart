import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/data/repositories/book_repository.dart';
import 'package:my_reader/domain/entities/book_entity.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final databaseHelper = ref.read(databaseHelperProvider);
  return BookRepository(databaseHelper);
});

final getBooksProvider = FutureProvider.family<List<BookEntity>, String?>((ref, category) async {
  final repo = ref.read(bookRepositoryProvider);
  final books = await repo.getBooks(category);
  return books;
});