class BookEntity {
  final int id;
  final String title;
  final String author;
  final String path;
  final String format;
  final String? coverPath;
  final int progress;
  final String? category;
  final double position; // Меняем на double для точности

  BookEntity({
    required this.id,
    required this.title,
    required this.author,
    required this.path,
    required this.format,
    this.coverPath,
    this.progress = 0,
    this.category,
    this.position = 0.0, // По умолчанию 0.0
  });

  BookEntity copyWith({
    int? id,
    String? title,
    String? author,
    String? path,
    String? format,
    String? coverPath,
    int? progress,
    String? category,
    double? position,
  }) {
    return BookEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      path: path ?? this.path,
      format: format ?? this.format,
      coverPath: coverPath ?? this.coverPath,
      progress: progress ?? this.progress,
      category: category ?? this.category,
      position: position ?? this.position,
    );
  }
}