import 'dart:io';
import 'package:xml/xml.dart';
import 'package:my_reader/domain/entities/chapter_entity.dart';

class Fb2Parser {
  Future<List<ChapterEntity>> parseChapters(String filePath) async {
    try {
      final xmlString = await File(filePath).readAsString();
      final document = XmlDocument.parse(xmlString);
      final chapters = <ChapterEntity>[];

      final sections = document.findAllElements('section').toList();
      int index = 0;

      for (final section in sections) {
        final titleElement = section.findElements('title').firstOrNull;
        String title = 'Раздел ${index + 1}';

        // Извлекаем чистый текст из заголовка
        if (titleElement != null) {
          title = _extractText(titleElement).trim();
          if (title.isEmpty) title = 'Раздел ${index + 1}';
        }

        // Извлекаем чистый текст содержимого
        final content = _extractSectionText(section);

        if (content.isNotEmpty) {
          chapters.add(ChapterEntity(
            title: title,
            content: content,
            index: index,
          ));
          index++;
        }
      }

      // Если секций нет, пробуем найти контент в body
      if (chapters.isEmpty) {
        final body = document.findAllElements('body').firstOrNull;
        if (body != null) {
          final content = _extractText(body);
          if (content.isNotEmpty) {
            chapters.add(ChapterEntity(
              title: 'Содержание',
              content: content,
              index: 0,
            ));
          }
        }
      }

      return chapters;
    } catch (e) {
      print('FB2 parsing error: $e');
      return [];
    }
  }

  String _extractSectionText(XmlElement section) {
    final buffer = StringBuffer();
    final paragraphs = section.findAllElements('p');

    for (final paragraph in paragraphs) {
      final text = _extractText(paragraph).trim();
      if (text.isNotEmpty) {
        buffer.writeln(text);
        buffer.writeln(); // Пустая строка между абзацами
      }
    }

    return buffer.toString().trim();
  }

  String _extractText(XmlElement element) {
    final buffer = StringBuffer();

    for (final node in element.children) {
      if (node is XmlText) {
        buffer.write(node.text);
      } else if (node is XmlElement) {
        // Рекурсивно обрабатываем вложенные элементы
        buffer.write(_extractText(node));

        // Добавляем пробелы и переносы для форматирования
        if (node.name.local == 'p' || node.name.local == 'br') {
          buffer.write('\n\n');
        } else if (node.name.local == 'empty-line') {
          buffer.write('\n\n');
        } else {
          buffer.write(' ');
        }
      }
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}