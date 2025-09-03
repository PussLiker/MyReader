import 'package:my_reader/data/repositories/book_repository.dart';

class AddBook {
  final BookRepository repository;

  AddBook(this.repository);

  Future<void> call(String filePath) async {
    await repository.addBook(filePath);
  }
}