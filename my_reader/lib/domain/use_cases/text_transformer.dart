import 'package:flutter/material.dart';
import '../entities/reading_position.dart';
import '../entities/reader_settings.dart'; // Импортируй модель

class TextTransformer {
  static TextSpan buildHighlightedSpan(
      String text,
      List<ReadingPosition> marks,
      ReaderSettings settings // <--- Добавляем настройки сюда
      ) {
    // Создаем базовый стиль на основе настроек
    final TextStyle baseStyle = TextStyle(
      fontSize: settings.fontSize,
      fontFamily: settings.fontFamily,
      height: settings.lineHeight,
      color: const Color(0xFF4E342E),
    );

    final TextStyle highlightStyle = baseStyle.copyWith(
      fontStyle: FontStyle.italic, // Курсив
      backgroundColor: Colors.yellow.withOpacity(0.2), // Подсветка
      color: const Color(0xFF4E342E), // Цвет текста цитаты
    );

    if (marks.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int currentPosition = 0;

    for (final position in marks) {
      if (position.charOffset > currentPosition) {
        spans.add(TextSpan(
          text: text.substring(currentPosition, position.charOffset),
          style: baseStyle,
        ));
      }

      final selectedText = position.selectedText ?? '';
      final textEnd = position.charOffset + selectedText.length;

      if (textEnd <= text.length) {
        spans.add(TextSpan(
          text: text.substring(position.charOffset, textEnd),
          style: highlightStyle,
        ));
      }
      currentPosition = textEnd;
    }

    if (currentPosition < text.length) {
      spans.add(TextSpan(text: text.substring(currentPosition), style: baseStyle));
    }

    return TextSpan(children: spans);
  }
}