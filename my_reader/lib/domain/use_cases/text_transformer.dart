import 'package:flutter/material.dart';
import '../../presentation/widgets/quote_block_widget.dart';

class TextTransformer {
  static List<Widget> buildTextBlocks(
      String text,
      List<dynamic> marks,
      dynamic settings,
      Function(dynamic) onQuoteTap, // Передаем callback для обработки клика
      ) {
    final TextStyle baseStyle = TextStyle(
      fontFamily: settings.fontFamily ?? 'Serif',
      fontSize: settings.fontSize ?? 18.0,
      height: settings.lineHeight ?? 1.4,
      color: const Color(0xFF3E2723),
    );

    if (marks.isEmpty) {
      return [Text(text, style: baseStyle)];
    }

    final sortedMarks = List.from(marks)
      ..sort((a, b) => a.charOffset.compareTo(b.charOffset));

    final List<Widget> blocks = [];
    int currentIndex = 0;

    for (var mark in sortedMarks) {
      final int markStart = mark.charOffset;
      final String? selectedText = mark.selectedText;

      if (selectedText == null || selectedText.isEmpty) continue;
      final int markEnd = markStart + selectedText.length;

      if (markStart < currentIndex || markEnd > text.length) continue;

      if (markStart > currentIndex) {
        final String normalText = text.substring(currentIndex, markStart);
        if (normalText.trim().isNotEmpty) {
          blocks.add(Text(normalText, style: baseStyle));
        }
      }

      final String quoteText = text.substring(markStart, markEnd);

      // Добавляем коробочку с передачей параметров комментария и клика
      blocks.add(QuoteBlockWidget(
        text: quoteText,
        baseStyle: baseStyle,
        currentComment: mark.comment, // Передаем текст текущей заметки
        onTap: () => onQuoteTap(mark), // Передаем сам объект разметки при тапе
      ));

      currentIndex = markEnd;
    }

    if (currentIndex < text.length) {
      final String trailingText = text.substring(currentIndex);
      if (trailingText.trim().isNotEmpty) {
        blocks.add(Text(trailingText, style: baseStyle));
      }
    }

    return blocks;
  }
}