// lib/infrastructure/epub/epub_parser.dart
import 'package:epub_viewer/epub_viewer.dart';

class EpubParser {
  Future<Map<String, dynamic>> parseMetadata(String path) async {
    // Заглушка: возвращаем тестовые метаданные
    // Позже заменим на реальный парсинг с epub_viewer или epubx
    try {
      return {
        'title': 'Тестовая книга',
        'author': 'Неизвестен',
        'category': 'Другое',
      };
    } catch (e) {
      throw Exception('Не удалось разобрать EPUB: $e');
    }
  }
}