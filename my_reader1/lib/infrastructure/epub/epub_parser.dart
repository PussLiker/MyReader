import 'dart:io';
import 'package:epubx/epubx.dart';

class EpubParser {
  Future<Map<String, dynamic>> parseMetadata(String path) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      final epub = await EpubReader.readBook(bytes);

      // Извлекаем название
      String title = epub.Title ?? 'Без названия';

      // Извлекаем автора
      String author = epub.Author ?? 'Неизвестен';

      // Извлекаем жанр (из Subjects, если доступно)
      String category = epub.Schema?.Package?.Metadata?.Subjects?.isNotEmpty ?? false
          ? epub.Schema!.Package!.Metadata!.Subjects!.first
          : 'Другое';

      return {
        'title': title,
        'author': author,
        'category': category,
      };
    } catch (e) {
      throw Exception('Не удалось разобрать EPUB: $e');
    }
  }
}