import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app_colors.dart';
import '../../domain/entities/Selection.dart';
import '../../domain/entities/reader_settings.dart';
import '../../domain/parsers/pdf_parser.dart';
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
  bool _isLoadingPage = false;
  final GlobalKey _richTextKey = GlobalKey();
  PageController? _pdfPageController;

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
      if (_isPdfBook) {
        if (_pdfPageController != null && _pdfPageController!.hasClients) {
          final pageIndex = _pdfPageController!.page?.round() ?? 0;
          print('Saving PDF position: page $pageIndex'); // Отладка
          await DatabaseHelper.instance.updatePosition(
            widget.book.id,
            pageIndex,
            0.0,
          );
        }
      } else {
        if (!_scrollController.hasClients) return;

        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        final double percent =
            maxScroll > 0 ? (currentScroll / maxScroll) : 0.0;

        await DatabaseHelper.instance.updatePosition(
          widget.book.id,
          _currentChapterIndex.toInt(),
          percent,
        );
      }
    });
  }

  // Немедленное сохранение (для стрелочек)
  Future<void> _immediateSavePosition() async {
    if (_isPdfBook) {
      if (_pdfPageController != null && _pdfPageController!.hasClients) {
        final pageIndex = _pdfPageController!.page?.round() ?? 0;
        print('Immediate saving PDF position: page $pageIndex');
        await DatabaseHelper.instance.updatePosition(
          widget.book.id,
          pageIndex,
          0.0,
        );
      }
    }
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
        case 'PDF':
          final parser = PdfParser();
          chapters = await parser.parseChapters(widget.book.path);

          // Восстанавливаем сохранённую позицию
          if (updatedBook != null && updatedBook.progress > 0) {
            _currentChapterIndex =
                updatedBook.progress.toDouble().clamp(0, chapters.length - 1);
          } else if (widget.book.progress > 0) {
            _currentChapterIndex =
                widget.book.progress.toDouble().clamp(0, chapters.length - 1);
          }
          break;
        default:
          throw Exception('Неподдерживаемый формат: ${widget.book.format}');
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
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScrollPosition(percent);
    });
  }

  void _nextChapter() {
    if (_isPdfBook) {
      if (_pdfPageController != null && _pdfPageController!.hasClients) {
        final currentPage = _pdfPageController!.page?.round() ?? 0;
        if (currentPage < _chapters.length - 1) {
          _pdfPageController!
              .nextPage(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          )
              .then((_) {
            _immediateSavePosition();
            _updateCurrentChapterIndex();
          });
        }
      }
    } else {
      if (_currentChapterIndex < _chapters.length - 1) {
        _goToPosition(_currentChapterIndex + 1.0);
      }
    }
  }

  void _previousChapter() {
    if (_isPdfBook) {
      if (_pdfPageController != null && _pdfPageController!.hasClients) {
        final currentPage = _pdfPageController!.page?.round() ?? 0;
        if (currentPage > 0) {
          _pdfPageController!
              .previousPage(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          )
              .then((_) {
            _immediateSavePosition();
            _updateCurrentChapterIndex();
          });
        }
      }
    } else {
      if (_currentChapterIndex > 0) {
        _goToPosition(_currentChapterIndex - 1.0);
      }
    }
  }

  void _updateCurrentChapterIndex() {
    if (_pdfPageController != null && _pdfPageController!.hasClients) {
      final page = _pdfPageController!.page?.round() ?? 0;
      setState(() {
        _currentChapterIndex = page.toDouble();
      });
    }
  }

  void _showChaptersDialog() {
    final colors = Theme.of(context).extension<AppColors>()!;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: colors.background,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Оглавление',
                  style: TextStyle(
                    color: colors.mainText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _chapters.isEmpty
                    ? Center(
                        child: Text(
                          'Нет глав',
                          style: TextStyle(color: colors.mainText),
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
                                    ? colors.accent
                                    : colors.border,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: colors.mainText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              chapter.title,
                              style: TextStyle(
                                color: colors.mainText,
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
                  child: Text(
                    'Закрыть',
                    style: TextStyle(color: colors.mainText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveQuoteAtSelection() async {
    final colors = Theme.of(context).extension<AppColors>()!;
    if (!_selection.isValid || _selection.start == _selection.end) return;

    final chapter = _currentChapter;
    if (chapter == null) return;

    final String selectedText =
        chapter.content.substring(_selection.start, _selection.end).trim();
    if (selectedText.isEmpty) return;

    final repo = ref.read(bookRepositoryProvider);
    final exists = await repo.anyMarkExists(widget.book.id, _selection.start);

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Уже есть метка'),
          backgroundColor: colors.secondaryText));
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

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Цитата сохранена'),
          backgroundColor: colors.secondaryText,
          duration: Duration(seconds: 1)));
    }
  }

  Future<bool?> _showQuoteDialog(
      ReadingPosition position, String selectedText) {
    final noteController = TextEditingController();
    // Достаем цвета здесь, так как мы внутри метода State
    final colors = Theme.of(context).extension<AppColors>()!;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.background,
        // Используем фоновый цвет из темы
        title: Text(
          'Сохранить цитату',
          style: TextStyle(color: colors.mainText, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Выделенный текст:',
                  style: TextStyle(color: colors.secondaryText, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.border.withOpacity(0.3),
                    // Легкий оттенок границы
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    selectedText,
                    style: TextStyle(
                        color: colors.mainText, fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Ваш комментарий',
                    labelStyle: TextStyle(color: colors.secondaryText),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: colors.accent, width: 2),
                    ),
                  ),
                  style: TextStyle(color: colors.mainText),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: colors.accent)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await DatabaseHelper.instance.addQuoteWithPosition(
                  widget.book.id,
                  position,
                  selectedText,
                  noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                );

                if (!context.mounted) return;
                Navigator.pop(context, true);
              } catch (e) {
                debugPrint("Ошибка сохранения цитаты: $e");
                Navigator.pop(context, false);
              }
            },
            child: Text(
              'Сохранить',
              style: TextStyle(
                  color: colors.secondaryText, fontWeight: FontWeight.bold),
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
    if (_isPdfBook) {
      // Для PDF переходим на нужную страницу
      if (_pdfPageController != null && _pdfPageController!.hasClients) {
        final targetPage =
            mark.chapterIndex.toInt().clamp(0, _chapters.length - 1);
        await _pdfPageController!.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        setState(() {
          _currentChapterIndex = targetPage.toDouble();
        });
      }
    } else {
      // Для обычных книг
      setState(() {
        _currentChapterIndex = mark.chapterIndex;
      });

      await Future.delayed(const Duration(milliseconds: 300));

      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        _scrollController.animateTo(
          maxScroll * mark.position,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  void _showBookmarksDialog() {
    final colors = Theme.of(context).extension<AppColors>()!;

    if (_bookmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Нет закладок'),
          backgroundColor: colors.accent, // Используем акцент вместо оранжевого
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: colors.background, // Используем фон темы
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Закладки',
                  style: TextStyle(
                    color: colors.mainText, // Основной цвет текста
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
                          color: bookmark.color != null
                              ? Color(bookmark.color!)
                              : colors.accent),
                      title: Text(
                        bookmark.title ?? 'Закладка',
                        style: TextStyle(color: colors.mainText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${bookmark.note ?? ''} • $chapterTitle',
                        style: TextStyle(color: colors.secondaryText),
                        // Вторичный текст
                        maxLines: 2,
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: colors.mainText),
                        onPressed: () => _deleteBookmark(bookmark),
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
                  child:
                      Text('Закрыть', style: TextStyle(color: colors.mainText)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Внутри State класса, где доступны AppColors:

  void _showQuotesDialog() {
    final colors = Theme.of(context).extension<AppColors>()!;
    if (_quotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Нет цитат'), backgroundColor: colors.accent),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: colors.background,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Цитаты',
                    style: TextStyle(
                        color: colors.mainText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
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
                      leading:
                          Icon(Icons.format_quote, color: colors.secondaryText),
                      title: Text(quote.selectedText ?? 'Цитата',
                          style: TextStyle(color: colors.mainText),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text('${quote.comment ?? ''} • $chapterTitle',
                          style: TextStyle(color: colors.secondaryText),
                          maxLines: 2),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
                            color: colors.secondaryText, size: 18),
                        onSelected: (value) {
                          if (value == 'delete')
                            _deleteQuote(quote);
                          else if (value == 'share' &&
                              quote.selectedText != null) {
                            Share.share(
                                '"${quote.selectedText!}" - ${widget.book.author}. ${widget.book.title}.');
                          }
                        },
                        itemBuilder: (context) => [
                          if (quote.selectedText != null)
                            PopupMenuItem(
                                value: 'share',
                                child: Row(children: [
                                  Icon(Icons.share,
                                      size: 16, color: colors.secondaryText),
                                  const SizedBox(width: 8),
                                  const Text('Поделиться')
                                ])),
                          PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete,
                                    size: 16, color: colors.secondaryText),
                                const SizedBox(width: 8),
                                const Text('Удалить')
                              ])),
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
                    child: Text('Закрыть',
                        style: TextStyle(color: colors.mainText))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteBookmark(ReadingPosition bookmark) async {
    final colors = Theme.of(context).extension<AppColors>()!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.background,
        title:
            Text('Удалить закладку?', style: TextStyle(color: colors.mainText)),
        content: Text(
            'Удалить закладку "${bookmark.selectedText ?? 'без текста'}"?',
            style: TextStyle(color: colors.mainText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Отмена',
                  style: TextStyle(color: colors.secondaryText))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (result == true && bookmark.id != null) {
      try {
        await DatabaseHelper.instance.deleteBookmarkById(bookmark.id!);
        await _loadBookmarksAndQuotes();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Закладка удалена'),
            backgroundColor: colors.accent));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteQuote(ReadingPosition quote) async {
    final colors = Theme.of(context).extension<AppColors>()!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.background,
        title:
            Text('Удалить цитату?', style: TextStyle(color: colors.mainText)),
        content: Text('Удалить цитату "${quote.selectedText ?? 'без текста'}"?',
            style: TextStyle(color: colors.mainText)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Отмена',
                  style: TextStyle(color: colors.secondaryText))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (result == true && quote.id != null) {
      try {
        await DatabaseHelper.instance.deleteQuoteById(quote.id!);
        await _refreshUI();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Цитата удалена'),
            backgroundColor: colors.accent));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildLoading() => Center(
      child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(
              Theme.of(context).extension<AppColors>()!.accent)));

  Widget _buildError() {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colors.secondaryText),
            const SizedBox(height: 16),
            Text(_errorMessage,
                style: TextStyle(color: colors.mainText, fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadBook,
                style: ElevatedButton.styleFrom(backgroundColor: colors.accent),
                child: const Text('Повторить',
                    style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  Widget _buildNoContent() {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book_outlined,
            size: 64,
            color: colors.mainText,
          ),
          SizedBox(height: 16),
          Text(
            'Книга не содержит контента',
            style: TextStyle(
              color: colors.secondaryText,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentBottomSheet(dynamic mark) {
    final TextEditingController commentController =
        TextEditingController(text: mark.comment);
    final colors = Theme.of(context).extension<AppColors>()!; // Доступ к теме

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75),
            decoration: BoxDecoration(
              color: colors.background, // Динамический фон
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: colors.border,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Заметка',
                                  style: TextStyle(
                                      fontFamily:
                                          _readerSettings.fontFamily ?? 'Serif',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: colors.mainText)),
                              IconButton(
                                  icon: Icon(Icons.share_outlined,
                                      color: colors.secondaryText),
                                  onPressed: () =>
                                      _shareQuote(mark.selectedText!.trim())),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: colors.cardBackground,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('"${mark.selectedText}"',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: colors.secondaryText,
                                    height: 1.4)),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: commentController,
                            maxLines: null,
                            cursorColor: colors.accent,
                            style:
                                TextStyle(color: colors.mainText, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Напишите заметку...',
                              hintStyle: TextStyle(color: colors.secondaryText),
                              filled: true,
                              fillColor: colors.cardBackground,
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: colors.accent, width: 1.5)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: colors.border, width: 1)),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
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
                                color: Colors.redAccent),
                            label: const Text('Удалить',
                                style: TextStyle(color: Colors.redAccent))),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await DatabaseHelper.instance.updateQuoteComment(
                                mark.id!,
                                commentController.text.trim().isEmpty
                                    ? null
                                    : commentController.text.trim());
                            await _refreshUI();
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor: Colors.white),
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

  // В reader_screen.dart, добавь в класс _ReaderScreenState:

  bool get _isPdfBook {
    return widget.book.format.toUpperCase() == 'PDF';
  }

  Widget _buildEpubContent(ChapterEntity chapter) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    final TextStyle titleStyle = TextStyle(
      fontFamily: _readerSettings.fontFamily ?? 'Serif',
      fontSize: (_readerSettings.fontSize ?? 18.0) + 6,
      height: 1.3,
      fontWeight: FontWeight.bold,
      color: colors.mainText, // Динамический цвет
    );

    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: Material(
          color: colors.cardBackground, // Динамический цвет
          child: Stack(
            children: [
              Theme(
                data: Theme.of(context).copyWith(
                  textSelectionTheme: TextSelectionThemeData(
                    selectionColor: colors.accent.withOpacity(0.3),
                    selectionHandleColor: colors.accent,
                  ),
                ),
                child: SelectionArea(
                  onSelectionChanged: (content) {
                    if (content == null || content.plainText.isEmpty) {
                      setState(() {
                        _isTextSelected = false;
                        _showSelectionToolbar = false;
                      });
                      return;
                    }
                    final int startOffset =
                        chapter.content.indexOf(content.plainText);
                    if (startOffset != -1) {
                      _selection = TextSelection(
                          baseOffset: startOffset,
                          extentOffset: startOffset + content.plainText.length);
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
                            child: Text(chapter.title,
                                style: titleStyle,
                                textAlign: TextAlign.center)),
                        const SizedBox(height: 24),
                        ...TextTransformer.buildTextBlocks(
                          chapter.content,
                          _indexedMarks[_currentChapterIndex.floor()] ?? [],
                          _readerSettings,
                          (mark) => _showCommentBottomSheet(mark),
                          colors,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
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
                      _shareQuote(chapter.content
                          .substring(_selection.start, _selection.end)
                          .trim());
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
    });
  }

// Метод _buildTextContent переделывается аналогично, просто замени цвета в Material на colors.cardBackground

  Widget _buildTextContent(ChapterEntity chapter) {
    // Используем расширение темы с фоллбэком на светлую тему
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: Material(
          color: colors.cardBackground, // Исправлено: теперь динамический цвет
          child: Theme(
            data: Theme.of(context).copyWith(
              textSelectionTheme: TextSelectionThemeData(
                selectionColor: colors.accent.withOpacity(0.3),
                selectionHandleColor: colors.accent,
              ),
            ),
            child: SelectionArea(
              onSelectionChanged: (content) {
                if (content == null || content.plainText.isEmpty) {
                  setState(() {
                    _isTextSelected = false;
                    _showSelectionToolbar = false;
                  });
                  return;
                }
                final int startOffset =
                    chapter.content.indexOf(content.plainText);
                if (startOffset != -1) {
                  _selection = TextSelection(
                      baseOffset: startOffset,
                      extentOffset: startOffset + content.plainText.length);
                  setState(() {
                    _isTextSelected = true;
                    _showSelectionToolbar = true;
                  });
                }
              },
              contextMenuBuilder: (context, state) => const SizedBox.shrink(),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 160),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...TextTransformer.buildTextBlocks(
                          chapter.content,
                          _indexedMarks[_currentChapterIndex.floor()] ?? [],
                          _readerSettings,
                          (mark) => _showCommentBottomSheet(mark),
                          colors, // Передаем объект colors в трансформатор
                        ),
                      ],
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
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
                          _shareQuote(chapter.content
                              .substring(_selection.start, _selection.end)
                              .trim());
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
          ),
        ),
      );
    });
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
    final colors = Theme.of(context).extension<AppColors>()!;
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
      backgroundColor: colors.cardBackground,
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
              Text("Редактирование",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.mainText)),
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
                                  ? Border.all(color: colors.mainText, width: 3)
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
                  backgroundColor: colors.accent,
                  foregroundColor: colors.cardBackground,
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
                child: Text('Сохранить изменения',
                    style: TextStyle(color: colors.mainText)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _renderBookmarkMarkers() {
    final colors = Theme.of(context).extension<AppColors>()!;
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
              color: bookmark.color != null
                  ? Color(bookmark.color!)
                  : colors.secondaryText,
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(3)),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Отображение PDF (всегда как картинки)
  Widget _buildPdfContent() {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      color: colors.background,
      child: PdfDocumentViewBuilder.file(
        widget.book.path,
        builder: (context, document) {
          if (document == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Загружаем сохранённую позицию
          final savedPage = widget.book.progress;
          print('Opening PDF at saved page: $savedPage');

          if (_pdfPageController == null || !_pdfPageController!.hasClients) {
            _pdfPageController = PageController(
              initialPage: savedPage.clamp(0, document.pages.length - 1),
            );

            // Синхронизируем _currentChapterIndex
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _currentChapterIndex = savedPage.toDouble();
                });
              }
            });
          }

          return PageView.builder(
            controller: _pdfPageController,
            itemCount: document.pages.length,
            onPageChanged: (index) {
              print('Page changed to: $index');
              setState(() {
                _currentChapterIndex = index.toDouble();
              });
              _savePosition(); // Сохраняем при свайпе
            },
            itemBuilder: (context, index) {
              return SizedBox.expand(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 3.0,
                  child: PdfPageView(
                    document: document,
                    pageNumber: index + 1,
                    alignment: Alignment.center,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return _buildLoading();
    if (_errorMessage.isNotEmpty) return _buildError();
    if (_chapters.isEmpty) return _buildNoContent();

    // Для PDF используем специальный виджет
    if (_isPdfBook) {
      return _buildPdfContent();
    }

    final chapter = _currentChapter;
    if (chapter == null) return _buildError();

    // EPUB, FB2, TXT
    if (widget.book.format == 'EPUB') {
      return _buildEpubContent(chapter);
    } else {
      return _buildTextContent(chapter);
    }
  }


  @override
  Widget build(BuildContext context) {
    // Доступ к системе тем
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background, // Динамический фон
      appBar: AppBar(
        backgroundColor: colors.accent, // Акцентный AppBar
        title: Text(
          widget.book.title,
          style: TextStyle(color: colors.mainText), // Цвет текста
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_quotes.isNotEmpty)
            IconButton(
              icon: Icon(Icons.format_quote, color: colors.mainText),
              onPressed: _showQuotesDialog,
              tooltip: 'Цитаты',
            ),
          if (_bookmarks.isNotEmpty)
            IconButton(
              icon: Icon(Icons.bookmarks, color: colors.mainText),
              onPressed: _showBookmarksDialog,
              tooltip: 'Закладки',
            ),
          IconButton(
            icon: Icon(Icons.menu_book, color: colors.mainText),
            onPressed: _showChaptersDialog,
            tooltip: 'Оглавление',
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_showSelectionToolbar) {
            setState(() => _showSelectionToolbar = false);
          }
        },
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _buildContent(),
            ),
            ..._renderBookmarkMarkers()
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: colors.accent,
        height: 70,
        child: Row(
          children: [
            // Кнопка назад
            IconButton(
              onPressed: _isPdfBook
                  ? (_pdfPageController != null &&
                          _pdfPageController!.hasClients &&
                          (_pdfPageController!.page?.round() ?? 0) > 0
                      ? _previousChapter
                      : null)
                  : (_currentChapterIndex > 0 ? _previousChapter : null),
              icon: Icon(Icons.arrow_back, color: colors.mainText),
            ),

            IconButton(
              icon: Icon(Icons.text_fields_outlined, color: colors.mainText),
              onPressed: _showSettings,
            ),

            // Индикатор прогресса / информация
            Expanded(
              child: InkWell(
                onTap: _isPdfBook ? null : _showChaptersDialog,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isPdfBook)
                      Text(
                        'Страница ${(_pdfPageController?.page?.round() ?? 0) + 1} / ${_chapters.length}',
                        style: TextStyle(color: colors.mainText, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      )
                    else if (_currentChapter != null)
                      Text(
                        _currentChapter!.title,
                        style: TextStyle(color: colors.mainText, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _isPdfBook && _chapters.isNotEmpty
                            ? ((_pdfPageController?.page?.round() ?? 0) + 1) /
                                _chapters.length
                            : _currentChapterProgress,
                        backgroundColor: colors.border,
                        valueColor: AlwaysStoppedAnimation(colors.mainText),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Кнопка закладки
            IconButton(
              onPressed: _showAddBookmarkDialog,
              icon: Icon(Icons.bookmark_add_outlined, color: colors.mainText),
            ),

            // Кнопка вперед
            IconButton(
              onPressed: _isPdfBook
                  ? (_pdfPageController != null &&
                          _pdfPageController!.hasClients &&
                          (_pdfPageController!.page?.round() ?? 0) <
                              _chapters.length - 1
                      ? _nextChapter
                      : null)
                  : (_currentChapterIndex < _chapters.length - 1
                      ? _nextChapter
                      : null),
              icon: Icon(Icons.arrow_forward, color: colors.mainText),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    if (_isPdfBook) {
      // Показываем сообщение, что настройки недоступны
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Настройки текста недоступны для PDF-файлов'),
          backgroundColor:
              Theme.of(context).extension<AppColors>()?.secondaryText,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

          final settingsService = SettingsService();
          await settingsService.saveSettings(newSettings);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _restoreScrollPosition(currentPercent);
          });
        },
      ),
    );
  }

  Future<void> _showAddBookmarkDialog() async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    final colors = Theme.of(context).extension<AppColors>()!;

    // Палитра теперь может быть слегка скорректирована под яркость темы,
    // если захочешь, но здесь используем те же пастельные тона
    final List<Color> palette = [
      const Color(0xFFEF9A9A),
      const Color(0xFFFFF59D),
      const Color(0xFFA5D6A7),
      const Color(0xFF90CAF9),
      const Color(0xFFCE93D8),
    ];

    int selectedColorValue = palette[0].value;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.background,
      // Используем динамический фон
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
                Text("Новая закладка",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colors.mainText)),
                const SizedBox(height: 15),
                TextField(
                  controller: titleController,
                  style: TextStyle(color: colors.mainText),
                  decoration: InputDecoration(
                    labelText: 'Название',
                    labelStyle: TextStyle(color: colors.secondaryText),
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.accent)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  style: TextStyle(color: colors.mainText),
                  decoration: InputDecoration(
                    labelText: 'Описание',
                    labelStyle: TextStyle(color: colors.secondaryText),
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.accent)),
                  ),
                ),
                const SizedBox(height: 20),
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
                                        color: colors.mainText, width: 3)
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
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: () async {
                    final int currentPage;
                    if (_isPdfBook) {
                      currentPage = _pdfPageController?.page?.round() ?? 0;
                    } else {
                      currentPage = _currentChapterIndex.toInt();
                    }

                    final newBookmark = ReadingPosition(
                      chapterIndex: _isPdfBook
                          ? (_pdfPageController?.page?.round() ?? 0).toDouble()
                          : _currentChapterIndex,
                      position: _isPdfBook ? 0.0 : _getCurrentScrollPercent(),
                      charOffset: _isPdfBook ? 0 : _getVisibleCharOffset(),
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
                    await _refreshUI();
                  },
                  child: const Text('Сохранить',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
      if (_isPdfBook) {
        // Для PDF восстанавливаем страницу
        if (_pdfPageController != null && _pdfPageController!.hasClients) {
          final savedPage = widget.book.progress;
          if (savedPage > 0 && savedPage < _chapters.length) {
            _pdfPageController!.jumpToPage(savedPage);
            _currentChapterIndex = savedPage.toDouble();
          }
        }
      } else {
        // Для текстовых книг
        if (_scrollController.hasClients) {
          // Твой код восстановления скролла, если нужен
        }
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
