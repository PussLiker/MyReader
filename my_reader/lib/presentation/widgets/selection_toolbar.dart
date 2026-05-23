import 'package:flutter/material.dart';
import 'dart:ui';

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
    // Тулбар больше не использует системные оверлеи, он рендерится как самостоятельный красивый блок
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        // Отступ чуть выше низа экрана
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            // Эффект размытия стекла detrás
            child: Container(
              height: 64, // Жесткая высота, защищающая от RenderFlex overflow
              width: MediaQuery.of(context).size.width *
                  0.9, // 90% от ширины экрана
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEDE7D9).withOpacity(0.85),
                    const Color(0xFFE0D8C3).withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
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
                  ),
                  _buildAction(
                    icon: Icons.share_rounded,
                    label: 'Поделиться',
                    onPressed: onShare,
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: const Color(0xFF7B5E57).withOpacity(0.2),
                  ),
                  _buildAction(
                    icon: Icons.close_rounded,
                    label: 'Закрыть',
                    onPressed: onClose,
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
    bool isClose = false,
  }) {
    final Color color =
        isClose ? const Color(0xFF8D6E63) : const Color(0xFF5D4037);

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
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
