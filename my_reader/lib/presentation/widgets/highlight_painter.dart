import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:my_reader/app_colors.dart';

class HighlightPainter extends CustomPainter {
  final List<dynamic> marks;
  final String content;
  final RenderParagraph? renderParagraph;
  final AppColors colors; // Передаем цвета через конструктор

  HighlightPainter({
    required this.marks,
    required this.content,
    required this.renderParagraph,
    required this.colors, // Обязательный параметр
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (marks.isEmpty || renderParagraph == null || !renderParagraph!.attached)
      return;

    // Теперь используем accent или специальный цвет для подсветки из темы
    final paint = Paint()
      ..color = colors.accent.withOpacity(0.4) // Используем цвет из темы
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    for (var mark in marks) {
      final int start = mark.charOffset;
      final String? selectedText = mark.selectedText;
      if (selectedText == null || selectedText.isEmpty) continue;
      final int end = start + selectedText.length;

      final List<TextBox> boxes = renderParagraph!.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );

      for (final box in boxes) {
        final Rect rect = Rect.fromLTRB(
          box.left - 2,
          box.top + 2,
          box.right + 2,
          box.bottom - 1,
        );

        final RRect rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(4),
          bottomLeft: const Radius.circular(6),
          topRight: const Radius.circular(5),
          bottomRight: const Radius.circular(3),
        );

        canvas.drawRRect(rrect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HighlightPainter oldDelegate) {
    return oldDelegate.marks != marks ||
        oldDelegate.renderParagraph != renderParagraph ||
        oldDelegate.colors != colors; // Добавляем проверку на цвета
  }
}
