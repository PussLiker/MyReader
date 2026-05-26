// lib/domain/entities/chapter_entity.dart
import 'dart:typed_data';

class ChapterEntity {
  final String title;
  final String content;
  final int index;
  final Uint8List? imageBytes;
  final String? imagePath;

  // Кэш для ленивой загрузки PDF текста
  String? _lazyContent;

  bool get isContentLoaded => _lazyContent != null;

  ChapterEntity({
    required this.title,
    required this.content,
    required this.index,
    this.imageBytes,
    this.imagePath,
  }) : _lazyContent = content.isEmpty ? null : content;

  // Получить контент (если не загружен, вернём пустую строку)
  String get loadedContent => _lazyContent ?? '';

  // Загрузить контент
  void setContent(String newContent) {
    _lazyContent = newContent;
  }

  ChapterEntity copyWith({
    String? title,
    String? content,
    int? index,
    Uint8List? imageBytes,
    String? imagePath,
  }) {
    final newEntity = ChapterEntity(
      title: title ?? this.title,
      content: content ?? this.content,
      index: index ?? this.index,
      imageBytes: imageBytes ?? this.imageBytes,
      imagePath: imagePath ?? this.imagePath,
    );
    if (content != null) {
      newEntity.setContent(content);
    }
    return newEntity;
  }
}