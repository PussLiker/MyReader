import 'dart:io';
import 'package:my_reader/domain/entities/chapter_entity.dart';

class TxtParser {
  Future<List<ChapterEntity>> parseChapters(String filePath) async {
    try {
      final content = await File(filePath).readAsString();

      // Разбиваем на абзацы
      final paragraphs = content.split('\n\n').where((p) => p.trim().isNotEmpty).toList();

      // Объединяем абзацы в главы по 10 абзацев
      final chapters = <ChapterEntity>[];
      final chapterSize = 10;

      for (int i = 0; i < paragraphs.length; i += chapterSize) {
        final endIndex = (i + chapterSize).clamp(0, paragraphs.length);
        final chapterParagraphs = paragraphs.sublist(i, endIndex);
        final chapterContent = chapterParagraphs.join('\n\n');

        chapters.add(ChapterEntity(
          title: 'Глава ${(i ~/ chapterSize) + 1}',
          content: chapterContent,
          index: i ~/ chapterSize,
        ));
      }

      return chapters;
    } catch (e) {
      print('TXT parsing error: $e');
      return [];
    }
  }
}