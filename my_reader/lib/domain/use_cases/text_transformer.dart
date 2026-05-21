import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../entities/reading_position.dart';
import '../entities/reader_settings.dart';

class TextTransformer {
  static TextSpan buildHighlightedSpan(
      String text,
      List<ReadingPosition> marks,
      ReaderSettings settings,
      void Function(ReadingPosition mark)? onTapQuote,
      ) {
    final baseStyle = TextStyle(
      fontSize: settings.fontSize,
      fontFamily: settings.fontFamily,
      height: settings.lineHeight,
      color: const Color(0xFF3E2F2B),
    );

    if (marks.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final List<TextSpan> spans = [];

    final sorted = List<ReadingPosition>.from(marks)
      ..sort((a, b) => a.charOffset.compareTo(b.charOffset));

    int cursor = 0;

    for (final mark in sorted) {
      final start = mark.charOffset;

      if (start < cursor || start >= text.length) {
        continue;
      }

      if (start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, start),
          style: baseStyle,
        ));
      }

      final selected = mark.selectedText ?? '';

      if (selected.isEmpty) {
        continue;
      }

      final end = (start + selected.length).clamp(0, text.length);

      final isQuote = (mark.note ?? '').isNotEmpty;

      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: baseStyle.copyWith(
            backgroundColor: isQuote
                ? const Color(0xFFFFF3E0)
                : const Color(0xFFE8E0D1),
            fontStyle: FontStyle.italic,
          ),
        ),
      );

      cursor = end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursor),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }
}