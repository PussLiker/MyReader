// lib/domain/entities/book_entity.dart
class BookEntity {
  final int id;
  final String title;
  final String author;
  final String category;
  final String format;
  final double progress;
  final String path;

  BookEntity({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.format,
    required this.progress,
    required this.path,
  });
}
