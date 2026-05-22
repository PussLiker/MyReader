import 'package:flutter/material.dart';

class QuoteBlockWidget extends StatelessWidget {
  final String text;
  final String? currentComment;
  final TextStyle baseStyle;
  final VoidCallback onTap; // Колбэк для обработки нажатия

  const QuoteBlockWidget({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.onTap,
    this.currentComment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 0,
      color: const Color(0xFFFBF9F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFEFEBE4), width: 1),
      ),
      clipBehavior: Clip.antiAlias, // Чтобы InkWell не вылезал за скругления
      child: InkWell(
        onTap: onTap,
        splashColor: const Color(0x1AD4A373),
        highlightColor: const Color(0x0AD4A373),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Индикатор
                Container(
                  width: 3.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A373),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                // Контент
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.trim(),
                        style: baseStyle.copyWith(
                          color: const Color(0xFF2B1D11),
                          fontStyle: FontStyle.italic,
                          height: baseStyle.height != null ? baseStyle.height! * 1.05 : 1.45,
                        ),
                      ),
                      // Если комментарий уже существует, покажем аккуратный индикатор-заметку снизу
                      if (currentComment != null && currentComment!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(color: Color(0xFFEFEBE4), height: 1),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 14,
                              color: Color(0xFF8B7E74),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                currentComment!,
                                style: baseStyle.copyWith(
                                  fontSize: baseStyle.fontSize! - 4,
                                  color: const Color(0xFF8B7E74),
                                  fontStyle: FontStyle.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}