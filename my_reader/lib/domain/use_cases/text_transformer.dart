import 'package:flutter/material.dart';
import '../../domain/entities/reading_position.dart';

class TextTransformer {
  /// Стиль для основного текста
  static const TextStyle _baseStyle = TextStyle(
    fontSize: 18.0,
    height: 1.6,
    color: Color(0xFF4E342E),
    fontFamily: 'Georgia',
  );

  /// Стиль для выделенных цитат и закладок
  static const TextStyle _highlightStyle = TextStyle(
    fontSize: 18.0,
    height: 1.6,
    color: Color(0xFF4E342E),
    backgroundColor: Color(0xFFFFF8E1), // Светло-желтый фон
    fontStyle: FontStyle.italic,
  );

  /// Основной метод, который превращает строку в дерево TextSpan.
  /// Принимает уже отфильтрованные и отсортированные отметки для конкретной главы.
  static TextSpan buildHighlightedSpan(String text, List<ReadingPosition> marks) {
    if (marks.isEmpty) {
      return TextSpan(text: text, style: _baseStyle);
    }

    final spans = <TextSpan>[];
    int currentPosition = 0;

    for (final position in marks) {
      // 1. Добавляем обычный текст ДО отметки
      if (position.charOffset > currentPosition) {
        spans.add(TextSpan(
          text: text.substring(currentPosition, position.charOffset),
          style: _baseStyle,
        ));
      }

      // 2. Добавляем выделенный текст (цитата/закладка)
      final selectedText = position.selectedText ?? '';
      final textEnd = position.charOffset + selectedText.length;

      // Проверка на выход за границы (защита от ошибок парсинга)
      if (textEnd <= text.length) {
        spans.add(TextSpan(
          text: text.substring(position.charOffset, textEnd),
          style: _highlightStyle,
        ));
      }

      currentPosition = textEnd;
    }

    // 3. Добавляем оставшийся хвост текста
    if (currentPosition < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPosition),
        style: _baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }
}