import 'dart:async';
import 'package:flutter/rendering.dart';

import '../../domain/entities/Selection.dart';
import '../../domain/entities/reader_settings.dart';
import '../../domain/use_cases/settings_service.dart';
import '../providers/book_provider.dart';
import '../widgets/highlight_painter.dart';
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
import '../widgets/settings_panel.dart';
import 'package:flutter/gestures.dart';

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
  late var _scrollController = ScrollController();
  int _currentCharOffset = 0;
  List<ReadingPosition> _bookmarks = [];
  List<ReadingPosition> _quotes = [];
  TextSelection _selection = const TextSelection.collapsed(offset: -1);
  bool _isTextSelected = false;
  bool _showSelectionToolbar = false;
  Map<int, List<ReadingPosition>> _indexedMarks = {};
  Timer? _savePositionTimer;
  late ReaderSettings _readerSettings;
  double _currentChapterProgress = 0.0; // Процент внутри главы (0.0 - 1.0)
  Selection? activeSelection;
  List<Highlight> highlights = [];
  bool _hasActiveSelection = false;
  Key _textKey = UniqueKey();
  final GlobalKey _richTextKey = GlobalKey();

  double _getCurrentScrollPercent() {
    if (_scrollController.hasClients) {
      final max = _scrollController.position.maxScrollExtent;
      final current = _scrollController.offset;
      return max > 0 ? (current / max) : 0.0;
    }
    return 0.0;
  }

  void _savePosition() {
    _savePositionTimer?.cancel();
    _savePositionTimer = Timer(const Duration(seconds: 1), () async {
      if (!_scrollController.hasClients) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      // Вычисляем процент
      final double percent = maxScroll > 0 ? (currentScroll / maxScroll) : 0.0;

      try {
        await DatabaseHelper.instance.updatePosition(
            widget.book.id,
            _currentChapterIndex.toInt(), // Глава -> progress
            percent // Процент -> position
            );
      } catch (e) {
        print('Ошибка сохранения в БД: $e');
      }
    });
  }

  void _restoreScrollPosition(double percent, {int retryCount = 0}) async {
    print("Попытка перехода на процент: $percent (попытка $retryCount)");

    // Защита от бесконечной рекурсии — максимум 5 попыток
    if (retryCount > 5) {
      print("Превышено количество попыток восстановления позиции");
      return;
    }

    await Future.delayed(const Duration(milliseconds: 300));

    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;

      // Если высота еще не рассчитана (бывает на больших текстах)
      if (maxScroll <= 100) {
        await Future.delayed(const Duration(milliseconds: 200));
        _restoreScrollPosition(percent, retryCount: retryCount + 1);
        return;
      }

      final target = maxScroll * percent.clamp(0.0, 1.0);

      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      _updateProgressBar(); // Твоя старая логика
      if (mounted) setState(() {}); // <-- Обязательно для перерисовки маркеров
    });

    _loadBook();
  }

  void _updateProgressBar() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;

      setState(() {
        _currentChapterProgress =
            maxScroll > 0 ? (currentScroll / maxScroll) : 0.0;
      });

      // Вызываем сохранение (оно у нас с Debounce, так что в БД не заспамит)
      _savePosition();
    }
  }

  // Оставляем один универсальный метод для индексации
  void _refreshTextMarkers() {
    final Map<int, List<ReadingPosition>> newMap = {};
    final allMarks = [..._bookmarks, ..._quotes];

    for (var mark in allMarks) {
      final int chapterIdx = mark.chapterIndex.floor();
      newMap.putIfAbsent(chapterIdx, () => []).add(mark);
    }

    setState(() {
      _indexedMarks = newMap;
    });
  }

  Future<void> _loadBook() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Загружаем глобальные настройки
      final settingsService = SettingsService();
      _readerSettings = await settingsService.loadSettings();

      // 1. Получаем данные из БД для сверки
      final updatedBook =
          await DatabaseHelper.instance.getBookById(widget.book.id);

      // Определяем целевую главу (приоритет у данных из Navigator.push)
      double targetChapter = (widget.book.progress > 0
              ? widget.book.progress
              : (updatedBook?.progress ?? 0))
          .toDouble();

      // Определяем целевой процент скролла
      final double targetPercent = widget.book.position > 0
          ? widget.book.position
          : (updatedBook?.position ?? 0.0);

      final bookmarks = await DatabaseHelper.instance
          .getBookmarksWithPosition(widget.book.id);
      final quotes =
          await DatabaseHelper.instance.getQuotesWithPosition(widget.book.id);

      // 2. Парсинг контента
      List<ChapterEntity> chapters = [];
      switch (widget.book.format.toUpperCase()) {
        case 'EPUB':
          chapters = await EpubParser().parseChapters(widget.book.path);
          break;
        case 'FB2':
          chapters = await Fb2Parser().parseChapters(widget.book.path);
          break;
        case 'TXT':
          chapters = await TxtParser().parseChapters(widget.book.path);
          break;
        default:
          throw Exception('Неподдерживаемый формат');
      }

      if (chapters.isEmpty) throw Exception('Книга пуста');
      if (!mounted) return;

      // 3. Обновляем состояние одним блоком
      setState(() {
        _chapters = chapters;
        _bookmarks = bookmarks;
        _quotes = quotes;

        // Защита от выхода за границы списка глав
        _currentChapterIndex =
            targetChapter.clamp(0.0, (chapters.length - 1).toDouble());
        _isLoading = false;
      });

      // Генерируем карту меток (курсив/выделение)
      _refreshTextMarkers();

      // 4. Восстанавливаем позицию после отрисовки кадра

      if (targetPercent > 0) {
        // Выполняем после того, как Flutter построит дерево виджетов
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreScrollPosition(targetPercent);
        });
      }
    } catch (e) {
      print('ОШИБКА ЗАГРУЗКИ: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Не удалось загрузить книгу. Проверьте файл.";
        });
      }
    }
  }

  Future<void> _loadBookmarksAndQuotes() async {
    try {
      final bookmarks = await DatabaseHelper.instance
          .getBookmarksWithPosition(widget.book.id);
      final quotes =
          await DatabaseHelper.instance.getQuotesWithPosition(widget.book.id);

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

        _textKey = UniqueKey();
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

  void _goToPosition(double chapterIndex,
      {double percent = 0.0, int charOffset = 0}) {
    if (_chapters.isEmpty) return;

    setState(() {
      _currentChapterIndex =
          chapterIndex.clamp(0.0, (_chapters.length - 1).toDouble());
      _isLoading = false; // На случай если вызвали во время загрузки
    });

    // Ждем, пока Flutter отрисует новую главу, и скроллим к проценту
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScrollPosition(percent);
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
                                fontWeight:
                                    index == _currentChapterIndex.floor()
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

  void _addBookmarkAtSelection() async {
    final repo = ref.read(bookRepositoryProvider);

    // Проверяем существование ЛЮБОЙ метки (закладка или цитата)
    final exists = await repo.anyMarkExists(widget.book.id, _selection.start);

    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('На этом месте уже есть закладка или цитата'),
            backgroundColor: Color(0xFF8D6E63),
            // Тот же цвет, что у основной темы
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Рассчитываем процент скролла
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentOffset = _scrollController.offset;
    final scrollPercent = maxScroll > 0 ? (currentOffset / maxScroll) : 0.0;

    final selectedText = _chapters[_currentChapterIndex.toInt()]
        .content
        .substring(
          _selection.start,
          _selection.end,
        )
        .trim();

    final position = ReadingPosition(
      chapterIndex: _currentChapterIndex,
      position: scrollPercent,
      charOffset: _selection.start,
      selectedText: selectedText,
    );

    // Внутри onPressed у кнопки "Сохранить" в диалоге:
    await DatabaseHelper.instance.addBookmarkWithPosition(
      widget.book.id, // 1. ID книги
      position, // 2. Объект позиции
      "Моя закладка", // Название
      "", // Описание (пустая строка)
      0xFF7B5E57, // 5. Цвет
    );

    await _loadBookmarksAndQuotes();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Закладка добавлена'),
          backgroundColor: Color(0xFF8D6E63),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _saveQuoteAtSelection() async {
    if (!_selection.isValid || _selection.start == _selection.end) return;

    final chapter = _currentChapter;
    if (chapter == null) return;

    final String selectedText =
        chapter.content.substring(_selection.start, _selection.end).trim();
    if (selectedText.isEmpty) return;

    final repo = ref.read(bookRepositoryProvider);
    final exists = await repo.anyMarkExists(widget.book.id, _selection.start);

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Уже есть метка'), backgroundColor: Color(0xFF8D6E63)));
      return;
    }

    final position = ReadingPosition(
      chapterIndex: _currentChapterIndex,
      position: _getCurrentScrollPercent(),
      charOffset: _selection.start,
      selectedText: selectedText,
    );

    final bool? isSaved = await _showQuoteDialog(position, selectedText);

    if (isSaved == true) {
      // ВМЕСТО РУЧНОГО setState С КЛЮЧОМ, ВЫЗЫВАЕМ БЕСШОВНОЕ ОБНОВЛЕНИЕ
      await _refreshUI();

      setState(() {
        _isTextSelected = false;
        _showSelectionToolbar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Цитата сохранена'),
          backgroundColor: Color(0xFF8D6E63),
          duration: Duration(seconds: 1)));
    }
  }

  Future<bool?> _showQuoteDialog(
      ReadingPosition position, String selectedText) {
    final noteController = TextEditingController();

    // Возвращаем результат showDialog (true если сохранили, null если отменили)
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text(
          'Сохранить цитату',
          style:
              TextStyle(color: Color(0xFF4E342E), fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            // Заменил ListView на SingleChildScrollView для лучшей работы с клавиатурой
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выделенный текст:',
                  style: TextStyle(color: Color(0xFF4E342E), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7CCC8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    selectedText,
                    style: const TextStyle(
                        color: Color(0xFF4E342E), fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Ваш комментарий',
                    labelStyle: TextStyle(color: Color(0xFF7B5E57)),
                    focusedBorder: UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: Color(0xFF4E342E), width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Color(0xFF4E342E)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            // Возвращаем false
            child: const Text('Отмена',
                style: TextStyle(color: Color(0xFF7B5E57))),
          ),
          TextButton(
            onPressed: () async {
              try {
                // Сохраняем в БД
                await DatabaseHelper.instance.addQuoteWithPosition(
                  widget.book.id,
                  position,
                  selectedText,
                  noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                );

                if (!context.mounted) return;
                Navigator.pop(
                    context, true); // Возвращаем true - сигнал к обновлению UI
              } catch (e) {
                print("Ошибка сохранения цитаты: $e");
                Navigator.pop(context, false);
              }
            },
            child: const Text(
              'Сохранить',
              style: TextStyle(
                  color: Color(0xFF4E342E), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _shareQuote(String text) {
    final shareText = '''
      "$text" – ${widget.book.author}. ${widget.book.title}.
      '''
        .trim();

    Share.share(shareText);
  }

  void _goToBookmark(ReadingPosition mark) async {
    // 1. Сначала переключаем главу
    setState(() {
      _currentChapterIndex = mark.chapterIndex;
    });

    // 2. КРИТИЧНО: Ждем, пока Flutter отрисует новую главу (300мс обычно хватает)
    await Future.delayed(const Duration(milliseconds: 300));

    // 3. Теперь скроллим к проценту
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;

      _scrollController.animateTo(
        maxScroll * mark.position,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
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
                    final chapterTitle =
                        bookmark.chapterIndex < _chapters.length
                            ? _chapters[bookmark.chapterIndex.floor()].title
                            : 'Глава ${bookmark.chapterIndex.floor() + 1}';

                    return ListTile(
                      leading: Icon(Icons.bookmark,
                          color: Color(bookmark.color ?? 0xFFEF9A9A)),
                      title: Text(
                        bookmark.title ?? 'Закладка',
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
                        icon: const Icon(Icons.more_vert,
                            color: Color(0xFF7B5E57), size: 18),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteBookmark(bookmark);
                          } else if (value == 'share' &&
                              bookmark.selectedText != null) {
                            Share.share(
                                '"${bookmark.selectedText!}" - ${widget.book.author}. ${widget.book.title}.');
                          }
                        },
                        itemBuilder: (context) => [
                          if (bookmark.selectedText != null)
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share,
                                      size: 16, color: Color(0xFF7B5E57)),
                                  SizedBox(width: 8),
                                  Text('Поделиться'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete,
                                    size: 16, color: Color(0xFF7B5E57)),
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
                      leading: const Icon(Icons.format_quote,
                          color: Color(0xFF7B5E57)),
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
                        icon: const Icon(Icons.more_vert,
                            color: Color(0xFF7B5E57), size: 18),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteQuote(quote);
                          } else if (value == 'share' &&
                              quote.selectedText != null) {
                            Share.share(
                                '"${quote.selectedText!}" - ${widget.book.author}. ${widget.book.title}.');
                          }
                        },
                        itemBuilder: (context) => [
                          if (quote.selectedText != null)
                            const PopupMenuItem(
                              value: 'share',
                              child: Row(
                                children: [
                                  Icon(Icons.share,
                                      size: 16, color: Color(0xFF7B5E57)),
                                  SizedBox(width: 8),
                                  Text('Поделиться'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete,
                                    size: 16, color: Color(0xFF7B5E57)),
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
        title: const Text('Удалить цитату?',
            style: TextStyle(color: Color(0xFF4E342E))),
        content: Text(
            'Вы уверены, что хотите удалить цитату "${quote.selectedText ?? 'без текста'}"?',
            style: const TextStyle(color: Color(0xFF4E342E))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена',
                  style: TextStyle(color: Color(0xFF4E342E)))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить',
                  style: TextStyle(color: Color(0xFF4E342E)))),
        ],
      ),
    );

    if (result == true && quote.id != null) {
      try {
        await DatabaseHelper.instance.deleteQuoteById(quote.id!);

        // Используем БЕСШОВНОЕ обновление
        await _refreshUI();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Цитата удалена'),
              backgroundColor: Color(0xFF8D6E63)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red));
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
    final TextStyle titleStyle = TextStyle(
      fontFamily: _readerSettings.fontFamily ?? 'Serif',
      fontSize: (_readerSettings.fontSize ?? 18.0) + 6,
      height: 1.3,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF3E2723),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Material(
            color: const Color(0xFFF5F2EB),
            child: Stack(
              children: [
                Theme(
                  data: ThemeData(
                    textSelectionTheme: const TextSelectionThemeData(
                      selectionColor: Color(0x26D4A373),
                      selectionHandleColor: Color(0xFFD4A373),
                    ),
                  ),
                  child: SelectionArea(
                    onSelectionChanged: (SelectedContent? content) {
                      if (content == null || content.plainText.isEmpty) {
                        setState(() {
                          _isTextSelected = false;
                          _showSelectionToolbar = false;
                        });
                        return;
                      }

                      final String selectedText = content.plainText;
                      final int startOffset =
                          chapter.content.indexOf(selectedText);

                      if (startOffset != -1) {
                        _selection = TextSelection(
                          baseOffset: startOffset,
                          extentOffset: startOffset + selectedText.length,
                        );
                        setState(() {
                          _isTextSelected = true;
                          _showSelectionToolbar = true;
                        });
                      }
                    },
                    contextMenuBuilder: (context, state) =>
                        const SizedBox.shrink(),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              chapter.title,
                              style: titleStyle,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Разворачиваем сгенерированные блоки контента главы
                          ...TextTransformer.buildTextBlocks(
                            chapter.content,
                            _indexedMarks[_currentChapterIndex.floor()] ?? [],
                            _readerSettings,
                            (mark) => _showCommentBottomSheet(mark),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.fastOutSlowIn,
                  bottom: _showSelectionToolbar && _isTextSelected ? 0 : -100,
                  left: 0,
                  right: 0,
                  child: SelectionToolbar(
                    onSaveQuote: () {
                      _saveQuoteAtSelection();
                      setState(() {
                        _showSelectionToolbar = false;
                        _isTextSelected = false;
                      });
                    },
                    onShare: () {
                      if (_selection.start != -1 && _selection.end != -1) {
                        final textToShare = chapter.content
                            .substring(
                              _selection.start,
                              _selection.end,
                            )
                            .trim();
                        _shareQuote(textToShare);
                      }
                    },
                    onClose: () => setState(() {
                      _showSelectionToolbar = false;
                      _isTextSelected = false;
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCommentBottomSheet(dynamic mark) {
    final TextEditingController commentController =
        TextEditingController(text: mark.comment);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Позволяет шторке подниматься выше половины экрана
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        // Используем Padding с viewInsets, чтобы контент сдвигался вверх на высоту клавиатуры
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            // Ограничиваем максимальную высоту в 75% экрана, чтобы шторка не прыгала на весь экран
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFFDFBF7),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                // Шторка сожмется под размер контента, если текста мало
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0DCD3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Скроллируемая часть
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Заметка к цитате',
                                style: TextStyle(
                                  fontFamily:
                                      _readerSettings.fontFamily ?? 'Serif',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF3E2723),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_outlined,
                                    color: Color(0xFF8B7E74)),
                                tooltip: 'Поделиться цитатой',
                                onPressed: () {
                                  if (mark.selectedText != null &&
                                      mark.selectedText!.isNotEmpty) {
                                    _shareQuote(mark.selectedText!.trim());
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F2EB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            width: double.infinity,
                            child: Text(
                              '"${mark.selectedText}"',
                              style: TextStyle(
                                fontFamily:
                                    _readerSettings.fontFamily ?? 'Serif',
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFF6D4C41),
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: commentController,
                            maxLines: null,
                            minLines: 3,
                            autofocus: false,
                            cursorColor: const Color(0xFFD4A373),
                            style: const TextStyle(
                                color: Color(0xFF2B1D11), fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Напишите свои мысли или заметку...',
                              hintStyle:
                                  const TextStyle(color: Color(0xFFA69F96)),
                              filled: true,
                              fillColor: const Color(0xFFFBF9F5),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFFD4A373), width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFFEFEBE4), width: 1),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Панель кнопок (фиксированно снизу шторки, но над клавиатурой)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteQuote(mark);
                          },
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          label: const Text('Удалить',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отмена',
                              style: TextStyle(color: Color(0xFF8B7E74))),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          // Внутри _showCommentBottomSheet, в кнопке "Сохранить":
                          onPressed: () async {
                            final String newComment =
                                commentController.text.trim();
                            Navigator.pop(context);

                            // Прямо передаем null, если строка пустая
                            final String? valueToUpdate =
                                newComment.isEmpty ? null : newComment;

                            // 1. Обновляем БД (метод выше сам обработает null)
                            await DatabaseHelper.instance
                                .updateQuoteComment(mark.id!, valueToUpdate);

                            // 2. Обновляем UI
                            await _refreshUI();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4A373),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          child: const Text('Сохранить',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextContent(ChapterEntity chapter) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Material(
            color: const Color(0xFFF5F2EB), // Цвет страницы книги
            child: Stack(
              children: [
                Theme(
                  data: ThemeData(
                    textSelectionTheme: const TextSelectionThemeData(
                      selectionColor: Color(0x26D4A373),
                      // Элегантное янтарное выделение при зажатии
                      selectionHandleColor: Color(0xFFD4A373),
                    ),
                  ),
                  child: SelectionArea(
                    onSelectionChanged: (SelectedContent? content) {
                      if (content == null || content.plainText.isEmpty) {
                        setState(() {
                          _isTextSelected = false;
                          _showSelectionToolbar = false;
                        });
                        return;
                      }

                      final String selectedText = content.plainText;
                      final int startOffset =
                          chapter.content.indexOf(selectedText);

                      if (startOffset != -1) {
                        _selection = TextSelection(
                          baseOffset: startOffset,
                          extentOffset: startOffset + selectedText.length,
                        );
                        setState(() {
                          _isTextSelected = true;
                          _showSelectionToolbar = true;
                        });
                      }
                    },
                    contextMenuBuilder: (context, state) =>
                        const SizedBox.shrink(),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 160),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        // Генерируем массив текстовых параграфов и коробочек-цитат
                        children: TextTransformer.buildTextBlocks(
                          chapter.content,
                          _indexedMarks[_currentChapterIndex.floor()] ?? [],
                          _readerSettings,
                          (mark) => _showCommentBottomSheet(mark),
                        ),
                      ),
                    ),
                  ),
                ),

                // Контекстный тулбар управления цитатами
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.fastOutSlowIn,
                  bottom: _showSelectionToolbar && _isTextSelected ? 0 : -100,
                  left: 0,
                  right: 0,
                  child: SelectionToolbar(
                    onSaveQuote: () {
                      _saveQuoteAtSelection();
                      setState(() {
                        _showSelectionToolbar = false;
                        _isTextSelected = false;
                      });
                    },
                    onShare: () {
                      if (_selection.start != -1 && _selection.end != -1) {
                        final textToShare = chapter.content
                            .substring(
                              _selection.start,
                              _selection.end,
                            )
                            .trim();
                        _shareQuote(textToShare);
                      }
                    },
                    onClose: () => setState(() {
                      _showSelectionToolbar = false;
                      _isTextSelected = false;
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _getVisibleCharOffset() {
    if (!_scrollController.hasClients) return 0;

    // Примерная логика: вычисляем офсет на основе процента прокрутки
    // Если у тебя есть более точный способ (через GlobalKey или RenderBox), лучше использовать его
    final double maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return 0;

    final double progress = _scrollController.offset / maxScroll;
    final int totalChars = _currentChapter?.content.length ?? 0;

    return (totalChars * progress).toInt();
  }

  double _calculateTopOffset(int charOffset) {
    if (!_scrollController.hasClients) return 0;

    // 1. Общее количество символов в главе
    final int totalChars = _currentChapter?.content.length ?? 1;

    // 2. Общая высота скроллируемого контента (не экрана, а всего текста)
    final double totalScrollHeight =
        _scrollController.position.maxScrollExtent +
            _scrollController.position.viewportDimension;

    // 3. Где маркер должен быть относительно начала всей главы (в пикселях)
    final double markerAbsolutePosition =
        (charOffset / totalChars) * totalScrollHeight;

    // 4. Вычитаем текущий скролл, чтобы получить позицию относительно верха экрана
    final double relativePosition =
        markerAbsolutePosition - _scrollController.offset;

    return relativePosition;
  }

  Future<void> _showEditBookmarkDialog(ReadingPosition bookmark) async {
    final titleController = TextEditingController(text: bookmark.title);
    final noteController = TextEditingController(text: bookmark.note);
    int selectedColorValue = bookmark.color ?? 0xFF7B5E57;

    // Эстетичная палитра
    final List<Color> palette = [
      const Color(0xFFEF9A9A), // Мягкий пыльно-розовый
      const Color(0xFFFFF59D), // Нежный кремово-желтый
      const Color(0xFFA5D6A7), // Светлый мятный
      const Color(0xFF90CAF9), // Приглушенный небесно-голубой
      const Color(0xFFCE93D8), // Легкий лавандовый
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F4F0),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          // padding с viewInsets.bottom поднимает меню над клавиатурой
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 45,
              top: 25,
              left: 25,
              right: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // Меню минимально по размеру контента
            children: [
              const Text("Редактирование",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E))),
              const SizedBox(height: 15),
              TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                      labelText: 'Название', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                      labelText: 'Описание', border: OutlineInputBorder())),
              const SizedBox(height: 20),

              // Палитра
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: palette
                    .map((color) => GestureDetector(
                          onTap: () => setModalState(
                              () => selectedColorValue = color.value),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: selectedColorValue == color.value
                                  ? Border.all(
                                      color: const Color(0xFF4E342E), width: 3)
                                  : null,
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4)
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),

              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D6E63),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () async {
                  final updated = bookmark.copyWith(
                    title: titleController.text,
                    note: noteController.text,
                    color: selectedColorValue,
                  );
                  await DatabaseHelper.instance.updateBookmark(updated);
                  Navigator.pop(context);
                  await _refreshUI();
                },
                child: const Text('Сохранить изменения'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _renderBookmarkMarkers() {
    final viewportHeight = _scrollController.hasClients
        ? _scrollController.position.viewportDimension
        : 0.0;

    return _bookmarks
        .where((b) => b.chapterIndex == _currentChapterIndex)
        .map((bookmark) {
      final top = _calculateTopOffset(bookmark.charOffset);

      // Если маркер за пределами экрана — возвращаем пустой виджет (не рисуем)
      if (top < 0 || top > viewportHeight) return const SizedBox.shrink();

      return Positioned(
        right: 0,
        top: top,
        child: GestureDetector(
          onTap: () => _showEditBookmarkDialog(bookmark),
          child: Container(
            width: 6,
            height: 24,
            decoration: BoxDecoration(
              color: Color(bookmark.color ?? 0xFF7B5E57),
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(3)),
            ),
          ),
        ),
      );
    }).toList();
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

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettingsPanel(
        settings: _readerSettings,
        onSettingsChanged: (newSettings) async {
          final double currentPercent = _currentChapterProgress;

          setState(() {
            _readerSettings = newSettings;
          });

          // ДОБАВЛЕНО: Сохраняем глобальные настройки
          final settingsService = SettingsService();
          await settingsService.saveSettings(newSettings);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _restoreScrollPosition(currentPercent);
          });
        },
      ),
    );
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
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_showSelectionToolbar) {
            setState(() {
              _showSelectionToolbar = false;
            });
          }
        },
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: _buildContent(),
            ),
            ..._renderBookmarkMarkers()
          ],
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
            IconButton(
              icon: const Icon(Icons.text_fields_outlined,
                  color: Color(0xFF7B5E57)),
              onPressed: _showSettings,
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
                        style: const TextStyle(
                            color: Color(0xFF4E342E), fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: // Внутри BottomAppBar -> Expanded -> Column:
                          LinearProgressIndicator(
                        value: _currentChapterProgress,
                        // Теперь это процент внутри текущей главы
                        backgroundColor: const Color(0xFFD7CCC8),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFF7B5E57)),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: _showAddBookmarkDialog,
              icon: const Icon(Icons.bookmark_add_outlined,
                  color: Color(0xFF7B5E57)),
            ),
            IconButton(
              onPressed: _currentChapterIndex < _chapters.length - 1
                  ? _nextChapter
                  : null,
              icon: const Icon(Icons.arrow_forward, color: Color(0xFF7B5E57)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddBookmarkDialog() async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();

    // Эстетичная палитра (цвета в стиле твоего приложения)
    final List<Color> palette = [
      const Color(0xFFEF9A9A), // Мягкий пыльно-розовый
      const Color(0xFFFFF59D), // Нежный кремово-желтый
      const Color(0xFFA5D6A7), // Светлый мятный
      const Color(0xFF90CAF9), // Приглушенный небесно-голубой
      const Color(0xFFCE93D8), // Легкий лавандовый
    ];

    int selectedColorValue = palette[0].value;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F4F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 45,
                top: 25,
                left: 25,
                right: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Новая закладка",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4E342E))),
                const SizedBox(height: 15),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                      labelText: 'Название', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                      labelText: 'Описание', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                // Эстетичная палитра
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: palette
                      .map((color) => GestureDetector(
                            onTap: () => setModalState(
                                () => selectedColorValue = color.value),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: selectedColorValue == color.value
                                    ? Border.all(
                                        color: const Color(0xFF4E342E),
                                        width: 3)
                                    : null,
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12, blurRadius: 4)
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 25),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D6E63),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () async {
                    // ЛОГИКА СОХРАНЕНИЯ
                    final newBookmark = ReadingPosition(
                      chapterIndex: _currentChapterIndex,
                      position: _getCurrentScrollPercent(),
                      charOffset: _getVisibleCharOffset(),
                      title: titleController.text.isEmpty
                          ? "Закладка"
                          : titleController.text,
                      note: noteController.text,
                      color: selectedColorValue,
                    );

                    await DatabaseHelper.instance.addBookmarkWithPosition(
                      widget.book.id!,
                      newBookmark,
                      newBookmark.title ?? 'Закладка',
                      newBookmark.note ?? "",
                      newBookmark.color!,
                    );

                    Navigator.pop(context);
                    await _refreshUI(); // Обновление маркеров на экране
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Внутри класса _ReaderScreenState
  @override
  void dispose() {
    _savePositionTimer?.cancel();
    if (_scrollController.hasClients) {
      _performImmediateSave();
    }
    _scrollController.removeListener(_updateProgressBar);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshUI() async {
    final double currentScroll =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    final bookmarks =
        await DatabaseHelper.instance.getBookmarksWithPosition(widget.book.id);
    final quotes =
        await DatabaseHelper.instance.getQuotesWithPosition(widget.book.id);

    final Map<int, List<ReadingPosition>> newMap = {};
    for (var mark in [...bookmarks, ...quotes]) {
      newMap.putIfAbsent(mark.chapterIndex.floor(), () => []).add(mark);
    }

    setState(() {
      _quotes = quotes;
      _bookmarks = bookmarks;
      _indexedMarks = newMap;
    });

    // Восстанавливаем позицию
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(currentScroll);
      }
    });
  }

  Future<void> _performImmediateSave() async {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final percent =
          maxScroll > 0 ? (_scrollController.offset / maxScroll) : 0.0;

      await DatabaseHelper.instance.updatePosition(
        widget.book.id,
        _currentChapterIndex.toInt(),
        percent,
      );
    }
  }
}
