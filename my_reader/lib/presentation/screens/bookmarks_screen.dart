import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/domain/entities/reading_position.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';
import 'package:my_reader/presentation/screens/reader_screen.dart';
import 'package:share_plus/share_plus.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  _BookmarksScreenState createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  // Возвращаем структуру Map для хранения сырых данных и объектов книг
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;
  final Map<int, BookEntity> _booksCache = {};



  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  // --- ЛОГИКА ЗАГРУЗКИ (Полная версия) ---
  Future<void> _loadBookmarks() async {
    final repo = ref.read(bookRepositoryProvider);
    try {
      final List<Map<String, dynamic>> bookmarksWithBooks = [];
      final allBooks = await repo.getBooks();

      for (final book in allBooks) {
        // Получаем типизированные объекты ReadingPosition из репозитория
        final bks = await repo.getBookmarks(book.id);
        final qts = await repo.getQuotes(book.id);
        final positions = [...bks, ...qts];

        for (final pos in positions) {
          bookmarksWithBooks.add({
            'bookmark': pos, // Теперь это объект ReadingPosition
            'book': book,
          });
        }
      }

      // Сортировка по названию книги
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
      debugPrint('Error loading bookmarks: $e');
      setState(() => _isLoading = false);
    }
  }

  // --- ЛОГИКА ПЕРЕХОДА ---
  void _goToBookmark(Map<String, dynamic> bookmarkData) async {
    final repo = ref.read(bookRepositoryProvider);
    final pos = bookmarkData['bookmark'] as ReadingPosition;
    final book = bookmarkData['book'] as BookEntity;


    // 1. Обновляем позицию в базе данных перед переходом
    await repo.updateReadingStatus(
      book.id,
      pos.chapterIndex.toInt(),
      pos.position, // ИСПОЛЬЗУЕМ position (0.0-1.0) вместо charOffset
    );

    // 2. Создаем обновленный объект книги
    final updatedBook = book.copyWith(
      progress: pos.chapterIndex.toInt(),
      position: pos.position,
    );

    if (!mounted) return;

    // 3. Летим в ридер
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(book: updatedBook),
      ),
    ).then((_) => _loadBookmarks());
  }

  // --- ЛОГИКА УДАЛЕНИЯ  ---
  Future<void> _deleteBookmark(Map<String, dynamic> bookmarkData) async {
    final repo = ref.read(bookRepositoryProvider);
    final pos = bookmarkData['bookmark'] as ReadingPosition;

    if (pos.id == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text('Удалить?', style: TextStyle(color: Color(0xFF4E342E))),
        content: const Text('Удалить эту метку навсегда?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (result == true) {
      await repo.deleteBookmark(pos.id!);
      await _loadBookmarks(); // Обновляем список на экране
    }
  }

  // --- ВЕРСТКА ЭЛЕМЕНТА  ---
  Widget _buildBookmarkItem(Map<String, dynamic> bookmarkData) {
    final pos = bookmarkData['bookmark'];

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
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFD7CCC8),
          child: Icon(Icons.bookmark, color: Color(0xFF7B5E57), size: 20),
        ),
        title: Text(
          pos.selectedText.isEmpty ? "Закладка" : pos.selectedText,
          style: const TextStyle(color: Color(0xFF4E342E), fontSize: 14),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Глава ${pos.chapterIndex.toInt() + 1}',
          style: const TextStyle(color: Color(0xFF8D6E63), fontSize: 11),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF7B5E57)),
          onSelected: (val) {
            if (val == 'delete') {
              _deleteBookmark(bookmarkData);
            } else if (val == 'share') {
              final pos = bookmarkData['bookmark'];
              final book = bookmarkData['book'] as BookEntity;
              Share.share('"${pos.selectedText}" — из книги ${book.title}');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'share', child: Text('Поделиться')),
            const PopupMenuItem(value: 'delete', child: Text('Удалить')),
          ],
        ),
        onTap: () => _goToBookmark(bookmarkData),
      ),
    );
  }

  // --- ГРУППИРОВКА И СПИСОК ---
  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final b in _bookmarks) {
      final title = (b['book'] as BookEntity).title;
      (grouped[title] ??= []).add(b);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBCAAA4),
        title: const Text('Мои закладки', style: TextStyle(color: Color(0xFF4E342E), fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : grouped.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
        onRefresh: _loadBookmarks,
        child: ListView.builder(
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final title = grouped.keys.elementAt(index);
            final items = grouped[title]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                ...items.map(_buildBookmarkItem),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() => const Center(child: Text("Закладок нет"));
}