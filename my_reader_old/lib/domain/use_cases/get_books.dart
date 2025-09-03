// my_reader/lib/domain/use_cases/get_books.dart
import 'package:my_reader/data/repositories/book_repository.dart';
import 'package:my_reader/domain/entities/book_entity.dart';

class GetBooks {
  final BookRepository repository;

  GetBooks(this.repository);

  Future<List<BookEntity>> call({String? category}) async {
    return await repository.getBooks(category: category);
  }
}