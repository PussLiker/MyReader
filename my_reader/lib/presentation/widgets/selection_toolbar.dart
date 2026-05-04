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
      child: Card(
        color: const Color(0xFFBCAAA4),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAction(Icons.bookmark_add, 'Закладка', onAddBookmark),
              _buildAction(Icons.format_quote, 'Цитата', onSaveQuote),
              _buildAction(Icons.share, 'Поделиться', onShare),
              const VerticalDivider(width: 1, indent: 10, endIndent: 10),
              _buildAction(Icons.close, 'Закрыть', onClose),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: const Color(0xFF4E342E)),
      onPressed: onPressed,
      tooltip: label,
    );
  }
}