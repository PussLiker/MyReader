import 'package:my_reader/data/repositories/book_repository.dart';
import 'package:my_reader/domain/entities/book_entity.dart';

class AddBook {
  final BookRepository repository;

  AddBook(this.repository);

  Future<void> call({
    required String filePath,
    required String title,
    required String author,
    String? category,
  }) async {
    // Передаём пользовательские title и author в BookRepository
    await repository.addBook(
      filePath,
      categoryOverride: category,
      titleOverride: title,
      authorOverride: author,
    );
  }
}