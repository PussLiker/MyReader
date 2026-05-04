import 'dart:async';
import '../widgets/selection_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/domain/entities/chapter_entity.dart';
import 'package:my_reader/domain/entities/reading_position.dart';
import 'package:my_reader/domain/parsers/txt_parser.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/parsers/epub_parser.dart';
import '../../domain/parsers/fb2_parser.dart';
import '../../domain/use_cases/text_transformer.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final BookEntity book;
  final int? initialCharOffset;
  const ReaderScreen({required this.book, this.initialCharOffset, super.key});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  double _currentChapterIndex = 0.0;
  List<ChapterEntity> _chapters = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final _scrollController = ScrollController();
  int _currentCharOffset = 0;
  List<ReadingPosition> _bookmarks = [];
  List<ReadingPosition> _quotes = [];
  TextSelection _selection = const TextSelection.collapsed(offset: -1);
  bool _isTextSelected = false;
  bool _showSelectionToolbar = false;
  Map<int, List<ReadingPosition>> _indexedMarks = {};
  Timer? _savePositionTimer;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final updatedBook = await DatabaseHelper.instance.getBookById(widget.book.id);
      _currentChapterIndex = updatedBook?.position ?? 0.0;

      await _loadBookmarksAndQuotes();

      List<ChapterEntity> chapters = [];

      switch (widget.book.format) {
        case 'EPUB':
          final parser = EpubParser();
          chapters = await parser.parseChapters(widget.book.path);
          break;
        case 'FB2':
          final parser = Fb2Parser();
          chapters = await parser.parseChapters(widget.book.path);
          break;
        case 'TXT':
          final parser = TxtParser();
          chapters = await parser.parseChapters(widget.book.path);
          break;
        default:
          throw Exception('Неподдерживаемый формат: ${widget.book.format}');
      }

      if (chapters.isEmpty) {
        throw Exception('Не удалось загрузить содержание книги');
      }

      setState(() {
        _chapters = chapters;
        _isLoading = false;
        _currentChapterIndex = _currentChapterIndex.clamp(0.0, _chapters.length - 1.0);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleInitialPosition();
      });

    } catch (e) {
      print('Error loading book: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Ошибка загрузки книги: ${e.toString()}';
      });
    }
  }

  Future<void> _loadBookmarksAndQuotes() async {
    try {
      final bookmarks = await DatabaseHelper.instance.getBookmarksWithPosition(widget.book.id);
      final quotes = await DatabaseHelper.instance.getQuotesWithPosition(widget.book.id);

      final allMarks = [...bookmarks, ...quotes];
      final Map<int, List<ReadingPosition>> newIndexedMarks = {};

      for (var mark in allMarks) {
        final chIdx = mark.chapterIndex.floor();
        if (!newIndexedMarks.containsKey(chIdx)) {
          newIndexedMarks[chIdx] = [];
        }
        newIndexedMarks[chIdx]!.add(mark);
      }

      // КРИТИЧЕСКИ ВАЖНО: Сортируем отметки внутри каждой главы заранее!
      for (var list in newIndexedMarks.values) {
        list.sort((a, b) => a.charOffset.compareTo(b.charOffset));
      }

      setState(() {
        _bookmarks = bookmarks;
        _quotes = quotes;
        _indexedMarks = newIndexedMarks;
      });
    } catch (e) {
      print('Error loading marks: $e');
    }
  }

  ChapterEntity? get _currentChapter {
    if (_chapters.isEmpty || _currentChapterIndex >= _chapters.length) {
      return null;
    }
    return _chapters[_currentChapterIndex.floor()];
  }

  void _savePosition() {
    // Отменяем предыдущий таймер, если он еще не сработал
    _savePositionTimer?.cancel();

    // Запускаем новый таймер на 1 секунду
    _savePositionTimer = Timer(const Duration(seconds: 1), () async {
      try {
        await DatabaseHelper.instance.updatePosition(widget.book.id, _currentChapterIndex);
        print('Позиция сохранена: $_currentChapterIndex');
      } catch (e) {
        print('Ошибка сохранения позиции: $e');
      }
    });
  }

  void _goToPosition(double chapterIndex, [int charOffset = 0]) {
    // Защита от выхода за пределы списка глав
    if (_chapters.isEmpty) return;

    final targetIdx = chapterIndex.clamp(0.0, _chapters.length - 1.0);

    setState(() {
      _currentChapterIndex = targetIdx;
      _currentCharOffset = charOffset;
      _isTextSelected = false;
      _showSelectionToolbar = false;
    });

    _savePosition();

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCharOffset(charOffset);
    });
  }

  void _scrollToCharOffset(int charOffset) {
    if (charOffset <= 0) return;

    final chapter = _currentChapter;
    if (chapter == null) return;

    // Для EPUB информируем пользователя
    if (widget.book.format == 'EPUB') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Точная навигация к строке недоступна для EPUB формата'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final textLength = chapter.content.length;
    if (textLength == 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!_scrollController.hasClients) return;

        final textRatio = charOffset / textLength;
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetPosition = (maxScroll * textRatio).clamp(0.0, maxScroll);

        _scrollController.animateTo(
          targetPosition,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  void _nextChapter() {
    if (_currentChapterIndex < _chapters.length - 1) {
      _goToPosition(_currentChapterIndex + 1.0);
    }
  }

  void _previousChapter() {
    if (_currentChapterIndex > 0) {
      _goToPosition(_currentChapterIndex - 1.0);
    }
  }

  void _showChaptersDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFEDE7D9),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Оглавление',
                  style: TextStyle(
                    color: Color(0xFF4E342E),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _chapters.isEmpty
                    ? const Center(
                  child: Text(
                    'Нет глав',
                    style: TextStyle(color: Color(0xFF4E342E)),
                  ),
                )
                    : ListView.builder(
                  itemCount: _chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = _chapters[index];
                    return ListTile(
                      leading: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: index == _currentChapterIndex.floor()
                              ? const Color(0xFF8D6E63)
                              : const Color(0xFFBCAAA4),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFF4E342E),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        chapter.title,
                        style: TextStyle(
                          color: const Color(0xFF4E342E),
                          fontWeight: index == _currentChapterIndex.floor()
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _goToPosition(index.toDouble());
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Закрыть',
                    style: TextStyle(color: Color(0xFF4E342E)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addBookmarkAtSelection() {
    if (!_selection.isValid || _selection.start == _selection.end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выделите текст для закладки'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final chapter = _currentChapter;
    if (chapter == null) return;

    String selectedText = chapter.content.substring(
      _selection.start,
      _selection.end,
    ).trim();

    if (selectedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось выделить текст'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final position = ReadingPosition(
      chapterIndex: _currentChapterIndex,
      charOffset: _selection.start,
      selectedText: selectedText,
    );

    _showBookmarkDialog(position);
  }

  void _showBookmarkDialog(ReadingPosition position) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text(
          'Добавить закладку',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (position.selectedText != null) ...[
              const Text(
                'Выделенный текст:',
                style: TextStyle(
                  color: Color(0xFF4E342E),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFBCAAA4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  position.selectedText!,
                  style: const TextStyle(color: Color(0xFF4E342E)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Комментарий',
                labelStyle: TextStyle(color: Color(0xFF4E342E)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7B5E57)),
                ),
              ),
              style: const TextStyle(color: Color(0xFF4E342E)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Color(0xFF4E342E)),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await DatabaseHelper.instance.addBookmarkWithPosition(
                  widget.book.id,
                  position,
                  controller.text.isEmpty ? 'Закладка' : controller.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Закладка добавлена'),
                    backgroundColor: Color(0xFF8D6E63),
                  ),
                );
                await _loadBookmarksAndQuotes();
                setState(() {
                  _isTextSelected = false;
                  _showSelectionToolbar = false;
                });
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Сохранить',
              style: TextStyle(color: Color(0xFF4E342E)),
            ),
          ),
        ],
      ),
    );
  }

  void _saveQuoteAtSelection() {
    if (!_selection.isValid || _selection.start == _selection.end) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выделите текст для цитаты'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final chapter = _currentChapter;
    if (chapter == null) return;

    String selectedText = chapter.content.substring(
      _selection.start,
      _selection.end,
    ).trim();

    if (selectedText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось выделить текст'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final position = ReadingPosition(
      chapterIndex: _currentChapterIndex,
      charOffset: _selection.start,
      selectedText: selectedText,
    );

    _showQuoteDialog(position, selectedText);
  }

  void _showQuoteDialog(ReadingPosition position, String selectedText) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text(
          'Сохранить цитату',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            children: [
              const Text(
                'Выделенный текст:',
                style: TextStyle(
                  color: Color(0xFF4E342E),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFBCAAA4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  selectedText,
                  style: const TextStyle(color: Color(0xFF4E342E)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Заметка (опционально)',
                  labelStyle: TextStyle(color: Color(0xFF4E342E)),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF7B5E57)),
                  ),
                ),
                style: const TextStyle(color: Color(0xFF4E342E)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Color(0xFF4E342E)),
            ),
          ),
          TextButton(
            onPressed: () => _shareQuote(selectedText),
            child: const Text(
              'Поделиться',
              style: TextStyle(color: Color(0xFF4E342E)),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await DatabaseHelper.instance.addQuoteWithPosition(
                  widget.book.id,
                  position,
                  selectedText,
                  noteController.text.isEmpty ? null : noteController.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Цитата сохранена'),
                    backgroundColor: Color(0xFF8D6E63),
                  ),
                );
                await _loadBookmarksAndQuotes();
                setState(() {
                  _isTextSelected = false;
                  _showSelectionToolbar = false;
                });
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Сохранить',
              style: TextStyle(color: Color(0xFF4E342E)),
            ),
          ),
        ],
      ),
    );
  }

  void _shareQuote(String text) {
    final shareText = '''
      Цитата из книги "${widget.book.title}"
      
      "$text"
      
      Автор: ${widget.book.author}
      Источник: ${widget.book.title}
      
      #цитата #чтение #книги #литература
        '''.trim();

    Share.share(shareText);
  }

  void _goToBookmark(ReadingPosition position) {
    if (widget.book.format == 'EPUB') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Для EPUB переход осуществляется к началу главы'),
          backgroundColor: Color(0xFF8D6E63),
          duration: Duration(seconds: 2),
        ),
      );
    }

    _goToPosition(position.chapterIndex, position.charOffset);

    if (position.selectedText != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Закладка: ${position.selectedText}'),
          backgroundColor: const Color(0xFF8D6E63),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showBookmarksDialog() {
    if (_bookmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет закладок'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFEDE7D9),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Закладки',
                  style: TextStyle(
                    color: Color(0xFF4E342E),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = _bookmarks[index];
                    final chapterTitle = bookmark.chapterIndex < _chapters.length
                        ? _chapters[bookmark.chapterIndex.floor()].title
                        : 'Глава ${bookmark.chapterIndex.floor() + 1}';

                    return ListTile(
                      leading: const Icon(Icons.bookmark, color: Color(0xFF7B5E57)),
                      title: Text(
                        bookmark.selectedText ?? 'Закладка',
                        style: const TextStyle(color: Color(0xFF4E342E)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${bookmark.note ?? ''} • $chapterTitle',
                        style: const TextStyle(color: Color(0xFF8D6E63)),
                        maxLines: 2,
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Color(0xFF7B5E57), size: 18),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteBookmark(bookmark);
                          } else if (value == 'share' && bookmark.selectedText != null) {
                            Share.share('"${bookmark.selectedText!}" - ${widget.book.author}. ${widget.book.title}.');
                          }
                        },
                        itemBuilder: (context) => [
                          if (bookmark.selectedText != null)
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share, size: 16, color: Color(0xFF7B5E57)),
                                  SizedBox(width: 8),
                                  Text('Поделиться'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Color(0xFF7B5E57)),
                                SizedBox(width: 8),
                                Text('Удалить'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _goToBookmark(bookmark);
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Закрыть',
                    style: TextStyle(color: Color(0xFF4E342E)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuotesDialog() {
    if (_quotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет цитат'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFEDE7D9),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Цитаты',
                  style: TextStyle(
                    color: Color(0xFF4E342E),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _quotes.length,
                  itemBuilder: (context, index) {
                    final quote = _quotes[index];
                    final chapterTitle = quote.chapterIndex < _chapters.length
                        ? _chapters[quote.chapterIndex.floor()].title
                        : 'Глава ${quote.chapterIndex.floor() + 1}';

                    return ListTile(
                      leading: const Icon(Icons.format_quote, color: Color(0xFF7B5E57)),
                      title: Text(
                        quote.selectedText ?? 'Цитата',
                        style: const TextStyle(color: Color(0xFF4E342E)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${quote.comment ?? ''} • $chapterTitle',
                        style: const TextStyle(color: Color(0xFF8D6E63)),
                        maxLines: 2,
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Color(0xFF7B5E57), size: 18),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteQuote(quote);
                          } else if (value == 'share' && quote.selectedText != null) {
                            Share.share('"${quote.selectedText!}" - ${widget.book.author}. ${widget.book.title}.');
                          }
                        },
                        itemBuilder: (context) => [
                          if (quote.selectedText != null)
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share, size: 16, color: Color(0xFF7B5E57)),
                                  SizedBox(width: 8),
                                  Text('Поделиться'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Color(0xFF7B5E57)),
                                SizedBox(width: 8),
                                Text('Удалить'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _goToBookmark(quote);
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Закрыть',
                    style: TextStyle(color: Color(0xFF4E342E)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBookmark(ReadingPosition bookmark) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text(
          'Удалить закладку?',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
        content: Text(
          'Вы уверены, что хотите удалить закладку "${bookmark.selectedText ?? 'без текста'}"?',
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

    if (result == true && bookmark.id != null) {
      try {
        await DatabaseHelper.instance.deleteBookmarkById(bookmark.id!);
        await _loadBookmarksAndQuotes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Закладка удалена'),
            backgroundColor: Color(0xFF8D6E63),
          ),
        );
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

  Future<void> _deleteQuote(ReadingPosition quote) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text(
          'Удалить цитату?',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
        content: Text(
          'Вы уверены, что хотите удалить цитату "${quote.selectedText ?? 'без текста'}"?',
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

    if (result == true && quote.id != null) {
      try {
        await DatabaseHelper.instance.deleteQuoteById(quote.id!);
        await _loadBookmarksAndQuotes();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Цитата удалена'),
            backgroundColor: Color(0xFF8D6E63),
          ),
        );
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

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B5E57)),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Color(0xFF8D6E63),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(
                color: Color(0xFF4E342E),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBook,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D6E63),
              ),
              child: const Text(
                'Попробовать снова',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 64,
            color: Color(0xFF8D6E63),
          ),
          SizedBox(height: 16),
          Text(
            'Книга не содержит контента',
            style: TextStyle(
              color: Color(0xFF4E342E),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpubContent(ChapterEntity chapter) {
    return LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                  child: Column( // Теперь это внутри SizedBox, всё будет ок
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          chapter.title,
                          style: const TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4E342E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSelectableEpubContent(chapter.content),
                    ],
                  ),
                ),
              ),
              if (_showSelectionToolbar && _isTextSelected)
                SelectionToolbar(
                  onAddBookmark: _addBookmarkAtSelection,
                  onSaveQuote: _saveQuoteAtSelection,
                  onShare: () {
                    // Логика получения текста для отправки
                    final selectedText = _currentChapter!.content.substring(
                      _selection.start,
                      _selection.end,
                    ).trim();
                    _shareQuote(selectedText);
                  },
                  onClose: () {
                    setState(() {
                      _showSelectionToolbar = false;
                      _isTextSelected = false;
                    });
                  },
                ),
            ],
          );
        });
  }

  Widget _buildSelectableEpubContent(String content) {
    return SelectableText.rich(
      _buildTextWithHighlights(content),
      style: const TextStyle(
        fontSize: 18.0,
        height: 1.6,
        color: Color(0xFF4E342E),
      ),
      onSelectionChanged: (selection, cause) {
        setState(() {
          _selection = selection;
          _isTextSelected = selection.isValid && selection.start != selection.end;
          _showSelectionToolbar = _isTextSelected;
        });
      },
    );
  }

  Widget _buildTextContent(ChapterEntity chapter) {
    // Используем LayoutBuilder, чтобы точно знать доступную высоту
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Ограничиваем область прокрутки размерами экрана
            SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 80), // Нижний отступ под Toolbar
                child: RepaintBoundary(
                  child: SelectableText.rich(
                    _buildTextWithHighlights(chapter.content),
                    style: const TextStyle(
                      fontSize: 18.0,
                      height: 1.6,
                      color: Color(0xFF4E342E),
                    ),
                    onSelectionChanged: (selection, cause) {
                      setState(() {
                        _selection = selection;
                        _isTextSelected = selection.isValid && selection.start != selection.end;
                        _showSelectionToolbar = _isTextSelected;
                      });
                    },
                  ),
                ),
              ),
            ),
            if (_showSelectionToolbar && _isTextSelected)
              SelectionToolbar(
                onAddBookmark: _addBookmarkAtSelection,
                onSaveQuote: _saveQuoteAtSelection,
                onShare: () {
                  final selectedText = _currentChapter!.content.substring(
                    _selection.start,
                    _selection.end,
                  ).trim();
                  _shareQuote(selectedText);
                },
                onClose: () => setState(() {
                  _showSelectionToolbar = false;
                  _isTextSelected = false;
                }),
              ),
          ],
        );
      },
    );
  }

  TextSpan _buildTextWithHighlights(String text) {
    // Просто берем уже готовый, отсортированный список для текущей главы из кэша
    final currentChapterMarks = _indexedMarks[_currentChapterIndex.floor()] ?? [];

    // Делегируем работу сервису
    return TextTransformer.buildHighlightedSpan(text, currentChapterMarks);
  }



  Widget _buildContent() {
    if (_isLoading) return _buildLoading();
    if (_errorMessage.isNotEmpty) return _buildError();
    if (_chapters.isEmpty) return _buildNoContent();

    final chapter = _currentChapter;
    if (chapter == null) return _buildError();

    if (widget.book.format == 'EPUB') {
      return _buildEpubContent(chapter);
    } else {
      return _buildTextContent(chapter);
    }
  }

  void _handleInitialPosition() {
    if (widget.initialCharOffset != null && _chapters.isNotEmpty) {
      _scrollToCharOffset(widget.initialCharOffset!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE7D9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBCAAA4),
        title: Text(
          widget.book.title,
          style: const TextStyle(color: Color(0xFF4E342E)),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_quotes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.format_quote, color: Color(0xFF7B5E57)),
              onPressed: _showQuotesDialog,
              tooltip: 'Цитаты',
            ),
          if (_bookmarks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bookmarks, color: Color(0xFF7B5E57)),
              onPressed: _showBookmarksDialog,
              tooltip: 'Закладки',
            ),
          IconButton(
            icon: const Icon(Icons.menu_book, color: Color(0xFF7B5E57)),
            onPressed: _showChaptersDialog,
            tooltip: 'Оглавление',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (_showSelectionToolbar) {
            setState(() {
              _showSelectionToolbar = false;
            });
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          // Добавляем этот параметр, чтобы дочерний виджет занимал всё пространство
          layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
            return SizedBox.expand(
              child: Stack(
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
            );
          },
          child: KeyedSubtree(
            // Ключ важен для работы AnimatedSwitcher
            key: ValueKey<double>(_currentChapterIndex),
            child: _buildContent(),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFFBCAAA4),
        height: 70, // Фиксированная высота для стабильности
        child: Row(
          children: [
            IconButton(
              onPressed: _currentChapterIndex > 0 ? _previousChapter : null,
              icon: const Icon(Icons.arrow_back, color: Color(0xFF7B5E57)),
            ),
            Expanded(
              child: InkWell(
                onTap: _showChaptersDialog,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    if (_currentChapter != null) // Защита от null
                      Text(
                        _currentChapter!.title,
                        style: const TextStyle(color: Color(0xFF4E342E), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        // Добавляем проверку на пустой список глав, чтобы не делить на 0
                        value: _chapters.isNotEmpty
                            ? (_currentChapterIndex + 1) / _chapters.length
                            : 0,
                        backgroundColor: const Color(0xFFD7CCC8),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF7B5E57)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: _currentChapterIndex < _chapters.length - 1 ? _nextChapter : null,
              icon: const Icon(Icons.arrow_forward, color: Color(0xFF7B5E57)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _savePositionTimer?.cancel(); // Останавливаем таймер
    _scrollController.dispose();
    super.dispose();
  }
}
