import 'dart:io';
import 'package:epubx/epubx.dart' as epub;
import 'package:my_reader/domain/entities/chapter_entity.dart';

class EpubParser {
  Future<List<ChapterEntity>> parseChapters(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final epubBook = await epub.EpubReader.readBook(bytes);
      final chapters = <ChapterEntity>[];

      // Сначала пробуем получить нормальные главы
      int validChapterCount = 0;
      for (final chapter in epubBook.Chapters ?? []) {
        if (_isValidChapter(chapter)) {
          final content = _cleanContent(chapter.HtmlContent!);
          if (content.length > 100) { // Минимальная длина главы
            chapters.add(ChapterEntity(
              title: chapter.Title?.isNotEmpty == true
                  ? chapter.Title!
                  : 'Глава ${validChapterCount + 1}',
              content: content,
              index: validChapterCount,
            ));
            validChapterCount++;
          }
        }
      }

      // Если нормальных глав мало, создаем большие разделы
      if (chapters.length <= 1 && epubBook.Chapters != null) {
        return _createLargeSections(epubBook.Chapters!);
      }

      return chapters;
    } catch (e) {
      print('EPUB parsing error: $e');
      return [];
    }
  }

  bool _isValidChapter(epub.EpubChapter chapter) {
    if (chapter.HtmlContent == null) return false;
    if (chapter.HtmlContent!.isEmpty) return false;

    // Игнорируем очень короткие главы (возможно, это метаданные)
    final cleanContent = _cleanContent(chapter.HtmlContent!);
    return cleanContent.length > 50;
  }

  String _cleanContent(String html) {
    // Базовая очистка без удаления переносов
    return html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<!--.*?-->', caseSensitive: false), '')
        .replaceAll(RegExp(r'<head>.*?</head>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<meta[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<title>.*?</title>', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<ChapterEntity> _createLargeSections(List<epub.EpubChapter> allChapters) {
    final sections = <ChapterEntity>[];
    final sectionSize = 5; // Объединяем по 5 глав в один раздел
    int sectionIndex = 0;

    for (int i = 0; i < allChapters.length; i += sectionSize) {
      final endIndex = (i + sectionSize).clamp(0, allChapters.length);
      final sectionChapters = allChapters.sublist(i, endIndex);

      final contentBuffer = StringBuffer();
      for (final chapter in sectionChapters) {
        if (chapter.HtmlContent != null && chapter.HtmlContent!.isNotEmpty) {
          contentBuffer.writeln(_cleanContent(chapter.HtmlContent!));
          contentBuffer.writeln('\n\n');
        }
      }

      final content = contentBuffer.toString().trim();
      if (content.isNotEmpty) {
        sections.add(ChapterEntity(
          title: 'Раздел ${sectionIndex + 1}',
          content: content,
          index: sectionIndex,
        ));
        sectionIndex++;
      }
    }

    return sections;
  }
}