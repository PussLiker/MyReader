import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/domain/entities/reading_position.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';
import 'package:my_reader/presentation/screens/reader_screen.dart';
import 'package:my_reader/app_colors.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/ThemeToggleButton.dart';

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
          quotesWithBooks.add({'quote': pos, 'book': book});
        }
      }

      quotesWithBooks.sort((a, b) => (a['book'] as BookEntity)
          .title
          .compareTo((b['book'] as BookEntity).title));

      if (mounted) {
        setState(() {
          _quotes = quotesWithBooks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteQuote(
      Map<String, dynamic> quoteData, AppColors colors) async {
    final repo = ref.read(bookRepositoryProvider);
    final pos = quoteData['quote'] as ReadingPosition;

    if (pos.id == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.background,
        title:
            Text('Удалить цитату?', style: TextStyle(color: colors.mainText)),
        content: Text('Вы уверены?', style: TextStyle(color: colors.mainText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (result == true) {
      await repo.deleteQuote(pos.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Цитата удалена'),
            backgroundColor: colors.accent));
      }
      await _loadQuotes();
    }
  }

  Widget _buildQuoteItem(Map<String, dynamic> quoteData, AppColors colors) {
    final pos = quoteData['quote'] as ReadingPosition;
    final book = quoteData['book'] as BookEntity;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: ListTile(
        leading: Icon(Icons.format_quote, color: colors.secondaryText),
        title: Text(
          pos.selectedText ?? '',
          style: TextStyle(
              color: colors.mainText,
              fontSize: 14,
              fontStyle: FontStyle.italic),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pos.comment?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(pos.comment!,
                    style:
                        TextStyle(color: colors.secondaryText, fontSize: 12)),
              ),
            Text(
              '${book.title} • Глава ${pos.chapterIndex.toInt() + 1}',
              style: TextStyle(color: colors.secondaryText, fontSize: 11),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: colors.secondaryText),
          onSelected: (val) {
            if (val == 'delete') _deleteQuote(quoteData, colors);
            if (val == 'share') _shareQuote(quoteData);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'share', child: Text('Поделиться')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Удалить', style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: () => _goToQuote(quoteData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var q in _quotes) {
      final title = (q['book'] as BookEntity).title;
      (grouped[title] ??= []).add(q);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.accent,
        title: Text('Мои цитаты',
            style:
                TextStyle(color: colors.mainText, fontWeight: FontWeight.bold)),
        actions: const [
          ThemeToggleButton(),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : grouped.isEmpty
              ? Center(
                  child: Text('Цитат нет',
                      style: TextStyle(color: colors.mainText)))
              : ListView.builder(
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final title = grouped.keys.elementAt(index);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text(title,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: colors.mainText)),
                        ),
                        ...grouped[title]!
                            .map((item) => _buildQuoteItem(item, colors)),
                      ],
                    );
                  },
                ),
    );
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
}
