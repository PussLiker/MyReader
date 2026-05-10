import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
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
  final Map<int, BookEntity> _booksCache = {};

  @override
  void initState() {
    super.initState();
    _loadQuotes();
  }

  Future<void> _loadQuotes() async {
    try {
      // 1. Получаем сырые данные из БД
      final rawQuotes = await DatabaseHelper.instance.getQuotesWithDetails();
      final quotesWithBooks = <Map<String, dynamic>>[];

      for (final rawData in rawQuotes) {
        final bookId = rawData['book_id'] as int;

        // 2. Получаем объект книги (из кэша или БД)
        BookEntity? book;
        if (_booksCache.containsKey(bookId)) {
          book = _booksCache[bookId];
        } else {
          book = await DatabaseHelper.instance.getBookById(bookId);
          if (book != null) _booksCache[bookId] = book;
        }

        if (book != null) {
          quotesWithBooks.add({
            'quote': rawData, // Вся строка из таблицы quotes
            'book': book,
          });
        }
      }

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

  void _goToQuote(Map<String, dynamic> quoteData) async {
    final quoteMap = quoteData['quote'];
    final book = quoteData['book'] as BookEntity;

    // Важно: проверяем типы данных, SQLite может вернуть int вместо double
    final int chapterIndex = (quoteMap['chapter_index'] as num).toInt();
    final double scrollPosition = (quoteMap['position'] as num).toDouble();

    // Обновляем прогресс книги, чтобы ридер открылся правильно
    await DatabaseHelper.instance.updatePosition(book.id, chapterIndex, scrollPosition);

    if (!mounted) return;

    final updatedBook = book.copyWith(
      progress: chapterIndex,
      position: scrollPosition,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(book: updatedBook),
      ),
    ).then((_) => _loadQuotes());
  }

  void _shareQuote(Map<String, dynamic> quoteData) {
    final quote = quoteData['quote'];
    final book = quoteData['book'] as BookEntity;
    final quoteText = quote['quote_text'] as String?;
    final comment = quote['comment'] as String?;

    if (quoteText != null) {
      String shareText = '«$quoteText»\n— ${book.author}, "${book.title}"';
      if (comment != null && comment.isNotEmpty) {
        shareText += '\n\nКомментарий: $comment';
      }
      Share.share(shareText);
    }
  }

  Future<void> _deleteQuote(Map<String, dynamic> quoteData) async {
    final quote = quoteData['quote'];
    final int quoteId = quote['id'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text('Удалить цитату?', style: TextStyle(color: Color(0xFF4E342E))),
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
      await DatabaseHelper.instance.deleteQuoteById(quoteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Цитата удалена'), backgroundColor: Color(0xFF8D6E63)),
        );
      }
      _loadQuotes();
    }
  }

  Widget _buildQuoteItem(Map<String, dynamic> quoteData) {
    final quote = quoteData['quote'];
    final quoteText = quote['quote_text'] as String? ?? '';
    final comment = quote['comment'] as String? ?? '';
    final double scrollPercent = (quote['position'] as num?)?.toDouble() ?? 0.0;
    final int chapter = (quote['chapter_index'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7CCC8)),
      ),
      child: ListTile(
        leading: const Icon(Icons.format_quote, color: Color(0xFF7B5E57)),
        title: Text(
          quoteText,
          style: const TextStyle(
            color: Color(0xFF4E342E),
            fontSize: 14,
            fontStyle: FontStyle.italic,
            fontFamily: 'serif',
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
                child: Text(comment, style: const TextStyle(color: Color(0xFF6D4C41), fontSize: 12)),
              ),
            Text(
              'Глава ${chapter + 1} • ${(scrollPercent * 100).toInt()}%',
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
        title: const Text('Мои цитаты', style: TextStyle(color: Color(0xFF4E342E))),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : grouped.isEmpty
          ? const Center(child: Text('Цитат пока нет'))
          : ListView.builder(
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final title = grouped.keys.elementAt(index);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ...grouped[title]!.map(_buildQuoteItem),
            ],
          );
        },
      ),
    );
  }
}