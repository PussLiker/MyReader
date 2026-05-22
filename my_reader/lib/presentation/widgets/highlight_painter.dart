import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class HighlightPainter extends CustomPainter {
  final List<dynamic> marks;
  final String content;
  final RenderParagraph? renderParagraph;

  HighlightPainter({
    required this.marks,
    required this.content,
    required this.renderParagraph,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (marks.isEmpty || renderParagraph == null || !renderParagraph!.attached) return;

    final paint = Paint()
      ..color = const Color(0xFFF3E5AB).withOpacity(0.7) // Благородный янтарно-песочный
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
    // Эффект мягких краев акварельного маркера
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

    for (var mark in marks) {
      final int start = mark.charOffset;
      final String? selectedText = mark.selectedText;
      if (selectedText == null || selectedText.isEmpty) continue;
      final int end = start + selectedText.length;

      // Получаем текстовые боксы (координаты строк) для выделенного участка текста
      final List<TextBox> boxes = renderParagraph!.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );

      for (final box in boxes) {
        // Создаем слегка неровный, «живой» контур мазка кисти вокруг текста
        final Rect rect = Rect.fromLTRB(
          box.left - 2,
          box.top + 2, // Сдвигаем чуть ниже, чтобы штрих шел как подложка
          box.right + 2,
          box.bottom - 1,
        );

        // Рисуем скругленный мазок, имитирующий скошенное перо маркера
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
    return oldDelegate.marks != marks || oldDelegate.renderParagraph != renderParagraph;
  }
}