import 'package:flutter/material.dart';

class SelectionToolbar extends StatelessWidget {
  final VoidCallback onAddBookmark;
  final VoidCallback onSaveQuote;
  final VoidCallback onShare;
  final VoidCallback onClose;

  const SelectionToolbar({
    super.key,
    required this.onAddBookmark,
    required this.onSaveQuote,
    required this.onShare,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 20,
      right: 20,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEDE7D9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD7CCC8),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAction(
                  icon: Icons.bookmark_add,
                  label: 'Закладка',
                  onPressed: onAddBookmark,
                  color: const Color(0xFF7B5E57),
                ),
                _buildAction(
                  icon: Icons.format_quote,
                  label: 'Цитата',
                  onPressed: onSaveQuote,
                  color: const Color(0xFF7B5E57),
                ),
                _buildAction(
                  icon: Icons.share,
                  label: 'Поделиться',
                  onPressed: onShare,
                  color: const Color(0xFF7B5E57),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: const Color(0xFFD7CCC8),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                _buildAction(
                  icon: Icons.close,
                  label: 'Закрыть',
                  onPressed: onClose,
                  color: const Color(0xFF8D6E63),
                ),
              ],
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
    required Color color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}