import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/domain/entities/reading_position.dart';
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
      final allQuotes = await DatabaseHelper.instance.getQuotesWithDetails();
      final quotesWithBooks = <Map<String, dynamic>>[];

      for (final quote in allQuotes) {
        final bookId = quote['book_id'] as int;
        BookEntity? book;

        if (_booksCache.containsKey(bookId)) {
          book = _booksCache[bookId];
        } else {
          book = await DatabaseHelper.instance.getBookById(bookId);
          if (book != null) {
            _booksCache[bookId] = book;
          }
        }

        if (book != null) {
          quotesWithBooks.add({
            'quote': quote,
            'book': book,
          });
        }
      }

      // Сортируем по названию книги для группировки
      quotesWithBooks.sort((a, b) {
        final bookA = a['book'] as BookEntity;
        final bookB = b['book'] as BookEntity;
        return bookA.title.compareTo(bookB.title);
      });

      setState(() {
        _quotes = quotesWithBooks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading quotes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goToQuote(Map<String, dynamic> quoteData) async {
    final quote = quoteData['quote'];
    final book = quoteData['book'] as BookEntity;

    final chapterIndex = (quote['chapter_index'] as num?)?.toDouble() ?? (quote['position'] as num).toDouble();
    final charOffset = quote['char_offset'] as int? ?? 0;

    await DatabaseHelper.instance.updatePosition(book.id, chapterIndex);
    final updatedBook = book.copyWith(position: chapterIndex);

    final initialCharOffset = book.format == 'EPUB' ? null : charOffset;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          book: updatedBook,
          initialCharOffset: initialCharOffset,
        ),
      ),
    ).then((_) {
      _loadQuotes();
    });
  }

  void _shareQuote(Map<String, dynamic> quoteData) {
    final quote = quoteData['quote'];
    final book = quoteData['book'] as BookEntity;
    final quoteText = quote['quote_text'] as String?;
    final comment = quote['comment'] as String?;

    if (quoteText != null) {
      String shareText = '"$quoteText" - ${book.author}. ${book.title}.';

      if (comment != null && comment.isNotEmpty) {
        shareText += '\n:: $comment';
      }

      Share.share(shareText);
    }
  }

  Future<void> _deleteQuote(Map<String, dynamic> quoteData) async {
    final quote = quoteData['quote'];
    final quoteId = quote['id'] as int;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text(
          'Удалить цитату?',
          style: TextStyle(
            color: Color(0xFF4E342E),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить эту цитату?',
          style: const TextStyle(
            color: Color(0xFF4E342E),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Color(0xFF4E342E)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Color(0xFF4E342E)),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await DatabaseHelper.instance.deleteQuoteById(quoteId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Цитата удалена'),
            backgroundColor: Color(0xFF8D6E63),
            duration: Duration(seconds: 2),
          ),
        );
        await _loadQuotes();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildQuoteItem(Map<String, dynamic> quoteData) {
    final quote = quoteData['quote'];
    final book = quoteData['book'] as BookEntity;
    final quoteText = quote['quote_text'] as String?;
    final comment = quote['comment'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7CCC8)),
      ),
      child: ListTile(
        leading: const Icon(Icons.format_quote, color: Color(0xFF7B5E57)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (quoteText != null)
              Text(
                quoteText,
                style: const TextStyle(
                  color: Color(0xFF4E342E),
                  fontSize: 14,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              book.title,
              style: const TextStyle(
                color: Color(0xFF6D4C41),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        subtitle: comment != null && comment.isNotEmpty
            ? Text(
          comment,
          style: const TextStyle(
            color: Color(0xFF8D6E63),
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        )
            : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF7B5E57), size: 20),
          onSelected: (value) {
            if (value == 'delete') {
              _deleteQuote(quoteData);
            } else if (value == 'share') {
              _shareQuote(quoteData);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 18, color: Color(0xFF7B5E57)),
                  SizedBox(width: 8),
                  Text('Поделиться'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Color(0xFF7B5E57)),
                  SizedBox(width: 8),
                  Text('Удалить'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _goToQuote(quoteData),
      ),
    );
  }

  Widget _buildBookGroup(String bookTitle, List<Map<String, dynamic>> quotes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Text(
            bookTitle,
            style: const TextStyle(
              color: Color(0xFF4E342E),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...quotes.map(_buildQuoteItem),
      ],
    );
  }

  Widget _buildGroupedQuotes() {
    final groupedQuotes = <String, List<Map<String, dynamic>>>{};

    for (final quoteData in _quotes) {
      final book = quoteData['book'] as BookEntity;
      final bookTitle = book.title;

      if (!groupedQuotes.containsKey(bookTitle)) {
        groupedQuotes[bookTitle] = [];
      }
      groupedQuotes[bookTitle]!.add(quoteData);
    }

    return ListView(
      children: groupedQuotes.entries.map((entry) {
        return _buildBookGroup(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B5E57)),
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.format_quote,
              size: 50,
              color: Colors.brown[300],
            ),
            const SizedBox(height: 20),
            Text(
              'Пока нет цитат',
              style: TextStyle(
                color: Colors.brown[700],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Выделяйте текст в книгах и сохраняйте\nпонравившиеся цитаты',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.brown[600],
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBCAAA4),
        elevation: 0,
        title: const Text(
          'Мои цитаты',
          style: TextStyle(
            color: Color(0xFF4E342E),

            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoading()
          : _quotes.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
        onRefresh: _loadQuotes,
        backgroundColor: const Color(0xFFF8F4F0),
        color: const Color(0xFF8D6E63),
        child: _buildGroupedQuotes(),
      ),
    );
  }
}