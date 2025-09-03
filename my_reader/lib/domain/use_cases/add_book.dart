
import '../entities/book_entity.dart';
import '../../data/repositories/book_repository.dart';

class AddBook {
  final BookRepository repository;

  AddBook(this.repository);

  Future<int> call({
    required String title,
    required String authorFirstName,
    String? authorLastName,
    required String path,
    required String format,
    required String category,
    double progress = 0.0,
  }) async {
    return await repository.addBook(
      title: title,
      authorFirstName: authorFirstName,
      authorLastName: authorLastName,
      path: path,
      format: format,
      category: category,
      progress: progress,
    );
  }
}