import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/domain/entities/reading_position.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';
import 'package:my_reader/presentation/screens/reader_screen.dart';
import 'package:share_plus/share_plus.dart';

class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({super.key});

  @override
  _QuotesScreenState createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  List<Map<String, dynamic>> _quotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    final repo = ref.read(bookRepositoryProvider);
    try {
      final List<Map<String, dynamic>> quotesWithBooks = [];
      final allBooks = await repo.getBooks();

      for (final book in allBooks) {
        final qts = await repo.getQuotes(book.id);
        for (final pos in qts) {
          quotesWithBooks.add({
            'quote': pos,
            'book': book,
          });
        }
      }

      quotesWithBooks.sort((a, b) {
        final bookA = a['book'] as BookEntity;
        final bookB = b['book'] as BookEntity;
        return bookA.title.compareTo(bookB.title);
      });

      if (mounted) {
        setState(() {
          _quotes = quotesWithBooks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки цитат: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _goToQuote(Map<String, dynamic> quoteData) async {
    final repo = ref.read(bookRepositoryProvider);
    final pos = quoteData['quote'] as ReadingPosition;
    final book = quoteData['book'] as BookEntity;

    await repo.updateReadingStatus(
      book.id,
      pos.chapterIndex.toInt(),
      pos.position,
    );

    final updatedBook = book.copyWith(
      progress: pos.chapterIndex.toInt(),
      position: pos.position,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(book: updatedBook),
      ),
    );

    _loadQuotes();
  }

  void _shareQuote(Map<String, dynamic> quoteData) {
    final pos = quoteData['quote'] as ReadingPosition;
    final book = quoteData['book'] as BookEntity;
    final quoteText = pos.selectedText;
    final comment = pos.comment;

    if (quoteText != null && quoteText.isNotEmpty) {
      String shareText = '«$quoteText»\n— ${book.author}, "${book.title}"';
      if (comment != null && comment.isNotEmpty) {
        shareText += '\n\nКомментарий: $comment';
      }
      Share.share(shareText);
    }
  }

  Future<void> _deleteQuote(Map<String, dynamic> quoteData) async {
    final repo = ref.read(bookRepositoryProvider);
    final pos = quoteData['quote'] as ReadingPosition;

    if (pos.id == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text('Удалить цитату?', style: TextStyle(color: Color(0xFF4E342E))),
        content: const Text('Вы уверены, что хотите удалить эту цитату?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF4E342E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      await repo.deleteQuote(pos.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Цитата удалена'),
            backgroundColor: Color(0xFF8D6E63),
          ),
        );
      }
      await _loadQuotes();
    }
  }

  Widget _buildQuoteItem(Map<String, dynamic> quoteData) {
    final pos = quoteData['quote'] as ReadingPosition;
    final book = quoteData['book'] as BookEntity;
    final quoteText = pos.selectedText ?? '';
    final comment = pos.comment ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7CCC8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: const Icon(Icons.format_quote, color: Color(0xFF7B5E57)),
        title: Text(
          quoteText,
          style: const TextStyle(
            color: Color(0xFF4E342E),
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  comment,
                  style: const TextStyle(color: Color(0xFF6D4C41), fontSize: 12),
                ),
              ),
            Text(
              '${book.title} • Глава ${pos.chapterIndex.toInt() + 1} • ${(pos.position * 100).toInt()}%',
              style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 11),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'delete') _deleteQuote(quoteData);
            if (val == 'share') _shareQuote(quoteData);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'share', child: Text('Поделиться')),
            const PopupMenuItem(value: 'delete', child: Text('Удалить')),
          ],
        ),
        onTap: () => _goToQuote(quoteData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var q in _quotes) {
      final title = (q['book'] as BookEntity).title;
      (grouped[title] ??= []).add(q);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBCAAA4),
        title: const Text(
          'Мои цитаты',
          style: TextStyle(color: Color(0xFF4E342E), fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : grouped.isEmpty
          ? const Center(
        child: Text(
          'Цитат пока нет',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadQuotes,
        child: ListView.builder(
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final title = grouped.keys.elementAt(index);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF4E342E),
                    ),
                  ),
                ),
                ...grouped[title]!.map(_buildQuoteItem),
              ],
            );
          },
        ),
      ),
    );
  }
}