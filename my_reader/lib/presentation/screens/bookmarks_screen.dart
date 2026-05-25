import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/domain/entities/reading_position.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';
import 'package:my_reader/presentation/screens/reader_screen.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_colors.dart';
import '../widgets/ThemeToggleButton.dart';

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  _BookmarksScreenState createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  List<Map<String, dynamic>> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final repo = ref.read(bookRepositoryProvider);
    try {
      final List<Map<String, dynamic>> bookmarksWithBooks = [];
      final allBooks = await repo.getBooks();

      for (final book in allBooks) {
        final bks = await repo.getBookmarks(book.id);
        for (final pos in bks) {
          bookmarksWithBooks.add({
            'bookmark': pos,
            'book': book,
          });
        }
      }

      bookmarksWithBooks.sort((a, b) {
        final bookA = a['book'] as BookEntity;
        final bookB = b['book'] as BookEntity;
        return bookA.title.compareTo(bookB.title);
      });

      if (mounted) {
        setState(() {
          _bookmarks = bookmarksWithBooks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _goToBookmark(Map<String, dynamic> bookmarkData) async {
    final repo = ref.read(bookRepositoryProvider);
    final pos = bookmarkData['bookmark'] as ReadingPosition;
    final book = bookmarkData['book'] as BookEntity;

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

    _loadBookmarks();
  }

  Future<void> _deleteBookmark(Map<String, dynamic> bookmarkData) async {
    final colors = Theme.of(context).extension<AppColors>()!;
    final repo = ref.read(bookRepositoryProvider);
    final pos = bookmarkData['bookmark'] as ReadingPosition;

    if (pos.id == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.background,
        title: Text('Удалить?', style: TextStyle(color: colors.mainText)),
        content: const Text('Удалить эту метку навсегда?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      await repo.deleteBookmark(pos.id!);
      await _loadBookmarks();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Получаем доступ к нашим цветам
    final colors = Theme.of(context).extension<AppColors>()!;

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final b in _bookmarks) {
      final title = (b['book'] as BookEntity).title;
      (grouped[title] ??= []).add(b);
    }

    return Scaffold(
      backgroundColor: colors.background, // Используем фоновый цвет темы
      appBar: AppBar(
        backgroundColor: colors.accent,
        title: Text(
          'Мои закладки',
          style: TextStyle(color: colors.mainText, fontWeight: FontWeight.bold),
        ),
        actions: const [
          ThemeToggleButton(),
        ],
        iconTheme: IconThemeData(color: colors.mainText),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : grouped.isEmpty
              ? Center(
                  child: Text("Закладок нет",
                      style: TextStyle(color: colors.mainText)))
              : RefreshIndicator(
                  onRefresh: _loadBookmarks,
                  color: colors.accent,
                  backgroundColor: colors.background,
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
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: colors.mainText,
                              ),
                            ),
                          ),
                          ...items
                              .map((item) => _buildBookmarkItem(item, colors)),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

// Передаем colors в метод, чтобы он их использовал
  Widget _buildBookmarkItem(
      Map<String, dynamic> bookmarkData, AppColors colors) {
    final pos = bookmarkData['bookmark'] as ReadingPosition;
    final book = bookmarkData['book'] as BookEntity;
    final Color bookmarkColor =
        pos.color != null ? Color(pos.color!) : colors.secondaryText;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: colors.cardBackground, // Используем фоновый цвет карточки темы
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: bookmarkColor.withOpacity(0.2),
          child: Icon(Icons.bookmark, color: bookmarkColor, size: 20),
        ),
        title: Text(
          pos.title?.isNotEmpty == true ? pos.title! : "Без названия",
          style: TextStyle(color: colors.mainText, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pos.note?.isNotEmpty == true) ...[
              Text(pos.note!,
                  style: TextStyle(color: colors.mainText, fontSize: 12)),
              const SizedBox(height: 2),
            ],
            Text(
              'Глава ${pos.chapterIndex.toInt() + 1}',
              style: TextStyle(color: colors.secondaryText, fontSize: 11),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: colors.mainText),
          onPressed: () => _deleteBookmark(bookmarkData),
        ),
        onTap: () => _goToBookmark(bookmarkData),
      ),
    );
  }
}
