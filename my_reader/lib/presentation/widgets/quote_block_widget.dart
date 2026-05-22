import 'package:flutter/material.dart';

class QuoteBlockWidget extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;

  const QuoteBlockWidget({
    super.key,
    required this.text,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        // Мягкий теплый фон коробочки, контрастирующий со страницей
        color: const Color(0xFFFBF9F5),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        // Деликатная рамка для ощущения физических границ
        border: Border.all(
          color: const Color(0xFFEFEBE4),
          width: 1,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Благородный вертикальный цветовой индикатор слева
            Container(
              width: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFFD4A373), // Янтарно-карамельный акцент
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            // Текст цитаты с легким наклоном и глубоким цветом
            Expanded(
              child: Text(
                text.trim(),
                style: baseStyle.copyWith(
                  color: const Color(0xFF2B1D11),
                  fontStyle: FontStyle.italic,
                  height: baseStyle.height != null ? baseStyle.height! * 1.05 : 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}