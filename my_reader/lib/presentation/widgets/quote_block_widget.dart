import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app_colors.dart';

class QuoteBlockWidget extends StatelessWidget {
  final String text;
  final String? currentComment;
  final TextStyle baseStyle;
  final VoidCallback onTap;

  const QuoteBlockWidget({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.onTap,
    this.currentComment,
  });

  @override
  Widget build(BuildContext context) {
    // Получаем цвета из темы
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: colors.accent, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text.trim(),
                    style: baseStyle.copyWith(
                      color: colors.mainText, // Динамика!
                      fontStyle: FontStyle.italic,
                    )),
                if (currentComment != null && currentComment!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(currentComment!,
                      style: baseStyle.copyWith(
                          fontSize: 12, color: colors.secondaryText // Динамика!
                          )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}