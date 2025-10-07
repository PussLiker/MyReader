import 'dart:io';
import 'package:epubx/epubx.dart' as epub;
import 'package:my_reader/domain/entities/chapter_entity.dart';

class EpubParser {
  Future<List<ChapterEntity>> parseChapters(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final epubBook = await epub.EpubReader.readBook(bytes);
      final chapters = <ChapterEntity>[];

      // Используем Chapters из epubBook
      if (epubBook.Chapters != null) {
        int chapterIndex = 0;

        for (final chapter in epubBook.Chapters!) {
          if (_isValidChapter(chapter)) {
            final content = _extractTextFromHtml(chapter.HtmlContent!);
            if (content.trim().isNotEmpty) {
              chapters.add(ChapterEntity(
                title: chapter.Title?.isNotEmpty == true
                    ? chapter.Title!
                    : 'Глава ${chapterIndex + 1}',
                content: content,
                index: chapterIndex,
              ));
              chapterIndex++;
            }
          }
        }
      }

      // Если глав не найдено, пробуем получить контент из Html файлов
      if (chapters.isEmpty && epubBook.Content?.Html != null) {
        int htmlIndex = 0;
        for (final htmlFile in epubBook.Content!.Html!.values) {
          if (htmlFile.Content != null && htmlFile.Content!.isNotEmpty) {
            final content = _extractTextFromHtml(htmlFile.Content!);
            if (content.trim().isNotEmpty) {
              chapters.add(ChapterEntity(
                title: 'Страница ${htmlIndex + 1}',
                content: content,
                index: htmlIndex,
              ));
              htmlIndex++;
            }
          }
        }
      }

      // Если все еще нет глав, создаем одну большую главу из всего контента
      if (chapters.isEmpty) {
        final allContent = await _extractAllContent(epubBook);
        if (allContent.isNotEmpty) {
          chapters.add(ChapterEntity(
            title: 'Содержание',
            content: allContent,
            index: 0,
          ));
        }
      }

      print('EPUB parsed: ${chapters.length} chapters found');
      return chapters;
    } catch (e) {
      print('EPUB parsing error: $e');
      return [];
    }
  }

  bool _isValidChapter(epub.EpubChapter chapter) {
    return chapter.HtmlContent != null && chapter.HtmlContent!.isNotEmpty;
  }

  String _extractTextFromHtml(String html) {
    // Упрощенная очистка HTML для получения читаемого текста
    String text = html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<!--.*?-->', caseSensitive: false), '')
        .replaceAll(RegExp(r'<head>.*?</head>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<meta[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<title>.*?</title>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]*>'), ' ') // Удаляем все оставшиеся теги
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Убираем слишком длинные пробелы и форматируем текст
    text = text
        .replaceAll(RegExp(r'\.\s+'), '.\n\n')
        .replaceAll(RegExp(r'\?\s+'), '?\n\n')
        .replaceAll(RegExp(r'!\s+'), '!\n\n')
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n');

    return text;
  }

  Future<String> _extractAllContent(epub.EpubBook epubBook) async {
    final buffer = StringBuffer();

    // Собираем контент из всех глав
    if (epubBook.Chapters != null) {
      for (final chapter in epubBook.Chapters!) {
        if (chapter.HtmlContent != null && chapter.HtmlContent!.isNotEmpty) {
          final content = _extractTextFromHtml(chapter.HtmlContent!);
          if (content.isNotEmpty) {
            buffer.writeln('=== ${chapter.Title ?? "Без названия"} ===');
            buffer.writeln(content);
            buffer.writeln('\n\n');
          }
        }
      }
    }

    // Добавляем контент из HTML файлов если глав нет
    if (buffer.isEmpty && epubBook.Content?.Html != null) {
      for (final htmlFile in epubBook.Content!.Html!.values) {
        if (htmlFile.Content != null && htmlFile.Content!.isNotEmpty) {
          final content = _extractTextFromHtml(htmlFile.Content!);
          buffer.writeln(content);
          buffer.writeln('\n\n');
        }
      }
    }

    return buffer.toString().trim();
  }
}