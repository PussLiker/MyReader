import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/domain/entities/reading_position.dart';
import 'package:my_reader/presentation/screens/reader_screen.dart';
import 'package:share_plus/share_plus.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  _BookmarksScreenState createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;
  final Map<int, BookEntity> _booksCache = {};

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  void _shareBookmark(Map<String, dynamic> bookmarkData) {
    final bookmark = bookmarkData['bookmark'];
    final book = bookmarkData['book'] as BookEntity;
    final selectedText = bookmark['selected_text'] as String?;
    final note = bookmark['note'] as String?;

    if (selectedText != null) {
      String shareText = '"$selectedText" - ${book.author}. ${book.title}.';

      if (note != null && note.isNotEmpty && note != 'Закладка') {
        shareText += '\n:: $note';
      }

      Share.share(shareText);
    } else if (note != null && note.isNotEmpty && note != 'Закладка') {
      Share.share('$note - ${book.author}. ${book.title}.');
    }
  }

  Future<void> _loadBookmarks() async {
    try {
      final allBookmarks = await DatabaseHelper.instance.getBookmarksWithDetails();
      final bookmarksWithBooks = <Map<String, dynamic>>[];

      for (final bookmark in allBookmarks) {
        final bookId = bookmark['book_id'] as int;
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
          bookmarksWithBooks.add({
            'bookmark': bookmark,
            'book': book,
          });
        }
      }

      // Сортируем по названию книги для группировки
      bookmarksWithBooks.sort((a, b) {
        final bookA = a['book'] as BookEntity;
        final bookB = b['book'] as BookEntity;
        return bookA.title.compareTo(bookB.title);
      });

      setState(() {
        _bookmarks = bookmarksWithBooks;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookmarks: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goToBookmark(Map<String, dynamic> bookmarkData) async {
    final bookmark = bookmarkData['bookmark'];
    final book = bookmarkData['book'] as BookEntity;

    final chapterIndex = (bookmark['chapter_index'] as num?)?.toDouble() ?? (bookmark['position'] as num).toDouble();
    final charOffset = bookmark['char_offset'] as int? ?? 0;

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
      _loadBookmarks();
    });
  }

  Future<void> _deleteBookmark(Map<String, dynamic> bookmarkData) async {
    final bookmark = bookmarkData['bookmark'];
    final bookmarkId = bookmark['id'] as int;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text(
          'Удалить закладку?',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
        content: Text(
          'Вы уверены, что хотите удалить эту закладку?',
          style: const TextStyle(color: Color(0xFF4E342E)),
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
        await DatabaseHelper.instance.deleteBookmarkById(bookmarkId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Закладка удалена'),
            backgroundColor: Color(0xFF8D6E63),
          ),
        );
        await _loadBookmarks();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBookmarkItem(Map<String, dynamic> bookmarkData) {
    final bookmark = bookmarkData['bookmark'];
    final book = bookmarkData['book'] as BookEntity;
    final selectedText = bookmark['selected_text'] as String?;
    final note = bookmark['note'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7CCC8)),
      ),
      child: ListTile(
        leading: const Icon(Icons.bookmark, color: Color(0xFF7B5E57)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedText != null)
              Text(
                selectedText,
                style: const TextStyle(
                  color: Color(0xFF4E342E),
                  fontSize: 14,
                  height: 1.4,
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
        subtitle: note != null && note.isNotEmpty && note != 'Закладка'
            ? Text(
          note,
          style: const TextStyle(
            color: Color(0xFF8D6E63),
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        )
            : null,
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF7B5E57), size: 20),
          onSelected: (value) {
            if (value == 'delete') {
              _deleteBookmark(bookmarkData);
            } else if (value == 'share') {
              _shareBookmark(bookmarkData);
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
        onTap: () => _goToBookmark(bookmarkData),
      ),
    );
  }

  Widget _buildBookGroup(String bookTitle, List<Map<String, dynamic>> bookmarks) {
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
        ...bookmarks.map(_buildBookmarkItem),
      ],
    );
  }

  Widget _buildGroupedBookmarks() {
    final groupedBookmarks = <String, List<Map<String, dynamic>>>{};

    for (final bookmarkData in _bookmarks) {
      final book = bookmarkData['book'] as BookEntity;
      final bookTitle = book.title;

      if (!groupedBookmarks.containsKey(bookTitle)) {
        groupedBookmarks[bookTitle] = [];
      }
      groupedBookmarks[bookTitle]!.add(bookmarkData);
    }

    return ListView(
      children: groupedBookmarks.entries.map((entry) {
        return _buildBookGroup(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B5E57)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: Colors.brown[300],
          ),
          const SizedBox(height: 20),
          Text(
            'Пока нет закладок',
            style: TextStyle(
              color: Colors.brown[700],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Добавляйте закладки в книгах, и они появятся здесь',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.brown[600],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBCAAA4),
        title: const Text(
          'Мои закладки',
          style: TextStyle(
            color: Color(0xFF4E342E),
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoading()
          : _bookmarks.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
        onRefresh: _loadBookmarks,
        backgroundColor: const Color(0xFFF8F4F0),
        color: const Color(0xFF8D6E63),
        child: _buildGroupedBookmarks(),
      ),
    );
  }
}