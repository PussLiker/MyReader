import 'package:flutter/material.dart';
import '../entities/reading_position.dart';
import '../entities/reader_settings.dart'; // Импортируй модель

class TextTransformer {
  static TextSpan buildHighlightedSpan(String text,
      List<ReadingPosition> marks,
      ReaderSettings settings,) {
    // ИСПРАВЛЕНО: Используем settings.lineHeight вместо фиксированного 1.6
    final TextStyle baseStyle = TextStyle(
      fontSize: settings.fontSize,
      fontFamily: settings.fontFamily,
      height: settings.lineHeight, // <-- Теперь используется из настроек
      color: const Color(0xFF4E342E),
    );

    final TextStyle highlightStyle = baseStyle.copyWith(
      fontStyle: FontStyle.italic,
      backgroundColor: const Color(0xFFE6D5B8).withOpacity(0.6),
      color: const Color(0xFF4E342E),
    );

    if (marks.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    int currentPosition = 0;

    // Сортируем метки по charOffset
    final sortedMarks = List<ReadingPosition>.from(marks)
      ..sort((a, b) => a.charOffset.compareTo(b.charOffset));

    for (final position in sortedMarks) {
      if (position.charOffset > currentPosition) {
        spans.add(TextSpan(
          text: text.substring(currentPosition, position.charOffset),
          style: baseStyle,
        ));
      }

      final selectedText = position.selectedText ?? '';
      final textEnd = position.charOffset + selectedText.length;

      if (textEnd <= text.length && selectedText.isNotEmpty) {
        spans.add(TextSpan(
          text: selectedText,
          style: highlightStyle,
        ));
      }
      currentPosition = textEnd;
    }

    if (currentPosition < text.length) {
      spans.add(
          TextSpan(text: text.substring(currentPosition), style: baseStyle));
    }

    return TextSpan(children: spans);
  }
}