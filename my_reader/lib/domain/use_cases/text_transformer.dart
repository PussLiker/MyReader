import 'package:flutter/material.dart';
import '../../app_colors.dart';
import '../../presentation/widgets/quote_block_widget.dart';

class TextTransformer {
  static List<Widget> buildTextBlocks(
    String text,
    List<dynamic> marks,
    dynamic settings,
    Function(dynamic) onQuoteTap,
    AppColors colors,
  ) {
    final TextStyle baseStyle = TextStyle(
      fontFamily: settings.fontFamily ?? 'Serif',
      fontSize: settings.fontSize ?? 18.0,
      height: settings.lineHeight ?? 1.4,
      color: colors.mainText,
    );

    // Сортируем маркеры
    final sortedMarks = List.from(marks)
      ..sort((a, b) => a.charOffset.compareTo(b.charOffset));

    final List<Widget> blocks = [];
    int currentIndex = 0;

    for (var mark in sortedMarks) {
      final int markStart = mark.charOffset;
      final String? selectedText = mark.selectedText;

      // Временная проверка: если маркер за пределами текста, принудительно двигаем индекс
      if (markStart >= text.length) continue;

      // Добавляем обычный текст до маркера
      if (markStart > currentIndex) {
        final String normalText = text.substring(currentIndex, markStart);
        if (normalText.isNotEmpty) {
          blocks.add(Text(normalText, style: baseStyle));
        }
      }

      // Вычисляем длину, чтобы не выйти за границы
      final int len = selectedText?.length ?? 0;
      final int markEnd =
          (markStart + len > text.length) ? text.length : markStart + len;
      final String quoteText = text.substring(markStart, markEnd);

      // Добавляем саму цитату
      blocks.add(QuoteBlockWidget(
        text: quoteText,
        baseStyle: baseStyle,
        currentComment: mark.comment,
        onTap: () => onQuoteTap(mark),
      ));

      currentIndex = markEnd;
    }

    // Добавляем оставшийся текст
    if (currentIndex < text.length) {
      blocks.add(Text(text.substring(currentIndex), style: baseStyle));
    }

    return blocks;
  }
}
