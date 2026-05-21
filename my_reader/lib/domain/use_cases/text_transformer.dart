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

    final List<InlineSpan> spans = [];
    int cursor = 0;

    final sorted = List<ReadingPosition>.from(marks)
      ..sort((a, b) => a.charOffset.compareTo(b.charOffset));

    for (final mark in sorted) {
      final start = mark.charOffset;

      if (start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, start),
          style: baseStyle,
        ));
      }

      final selected = mark.selectedText ?? '';
      if (selected.isEmpty) {
        cursor = start;
        continue;
      }

      final end = (start + selected.length).clamp(0, text.length);
      final isQuote = mark.note != null && mark.note!.isNotEmpty;

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () {
              if (onTapQuote != null) {
                onTapQuote(mark);
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isQuote
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFE8E0D1),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(
                    color: isQuote
                        ? const Color(0xFFFF9800)
                        : const Color(0xFF8D6E63),
                    width: 3,
                  ),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                selected,
                style: baseStyle.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
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