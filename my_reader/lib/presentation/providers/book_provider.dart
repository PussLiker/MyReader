import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/data/repositories/book_repository.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import '../../domain/entities/reader_settings.dart';
import '../../domain/use_cases/settings_service.dart';

final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final databaseHelper = ref.read(databaseHelperProvider);
  return BookRepository(databaseHelper);
});

// Провайдер для книг с фильтром по категории
final getBooksProvider = FutureProvider.family<List<BookEntity>, String?>((ref, category) async {
  final repo = ref.read(bookRepositoryProvider);
  final books = await repo.getBooks(category);
  return books;
});

final readerSettingsProvider = FutureProvider<ReaderSettings>((ref) async {
  final service = ref.read(settingsServiceProvider);
  return await service.loadSettings();
});

// Провайдер для списка категорий
final getCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.read(bookRepositoryProvider);
  final categories = await repo.getCategories();
  return categories;
});

// Провайдер для всех книг без фильтра
final getAllBooksProvider = FutureProvider<List<BookEntity>>((ref) async {
  final repo = ref.read(bookRepositoryProvider);
  final books = await repo.getBooks(); // без категории
  return books;
});