import 'package:flutter/material.dart';
import 'dart:ui';

import '../../app_colors.dart';

class SelectionToolbar extends StatelessWidget {
  final VoidCallback onSaveQuote;
  final VoidCallback onShare;
  final VoidCallback onClose;

  const SelectionToolbar({
    super.key,
    required this.onSaveQuote,
    required this.onShare,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Достаем цвета из темы
    final colors = Theme.of(context).extension<AppColors>();
    if (colors == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 64,
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                // Используем цвета темы для градиента
                gradient: LinearGradient(
                  colors: [
                    colors.background.withOpacity(0.9),
                    colors.cardBackground.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.border.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAction(
                    icon: Icons.format_quote_rounded,
                    label: 'Цитата',
                    onPressed: onSaveQuote,
                    colors: colors, // Передаем colors дальше
                  ),
                  _buildAction(
                    icon: Icons.share_rounded,
                    label: 'Поделиться',
                    onPressed: onShare,
                    colors: colors,
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: colors.border,
                  ),
                  _buildAction(
                    icon: Icons.close_rounded,
                    label: 'Закрыть',
                    onPressed: onClose,
                    colors: colors,
                    isClose: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required AppColors colors, // Добавили параметр
    bool isClose = false,
  }) {
    // Используем акцент из темы для кнопки закрытия, основной текст — для остальных
    final Color color = colors.mainText;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
