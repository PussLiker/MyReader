import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:xml/xml.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:share_plus/share_plus.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final BookEntity book;
  const ReaderScreen({required this.book, super.key});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  int _currentPosition = 0;
  List<epub.EpubChapter>? _chapters;
  List<String>? _paragraphs;
  String? _selectedText;
  epub.EpubBook? _epubBook;
  int _totalPositions = 1;
  final _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      if (widget.book.format == 'EPUB') {
        final epubBook = await epub.EpubReader.readBook(await File(widget.book.path).readAsBytes());
        setState(() {
          _epubBook = epubBook;
          _chapters = epubBook.Chapters?.where((c) => c.HtmlContent != null).toList() ?? [];
          _totalPositions = _chapters!.length > 0 ? _chapters!.length : 1;
          _currentPosition = _currentPosition.clamp(0, _totalPositions - 1);
        });
      } else {
        final content = await _loadRawContent();
        setState(() {
          _paragraphs = content.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
          _totalPositions = _paragraphs!.length > 0 ? _paragraphs!.length : 1;
          _currentPosition = _currentPosition.clamp(0, _totalPositions - 1);
        });
      }
      await _updateProgress();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ошибка загрузки книги: $e',
            style: const TextStyle(color: Color(0xFF4E342E)),
          ),
          backgroundColor: const Color(0xFFBCAAA4),
        ),
      );
    }
  }

  Future<String> _loadRawContent() async {
    try {
      if (widget.book.format == 'EPUB') {
        final chapter = _chapters != null && _currentPosition < _chapters!.length
            ? _chapters![_currentPosition]
            : null;
        return chapter?.HtmlContent ?? 'Контент не найден';
      } else if (widget.book.format == 'TXT') {
        final content = await File(widget.book.path).readAsString();
        return content.isNotEmpty ? content : 'Контент не найден';
      } else if (widget.book.format == 'FB2') {
        final xmlString = await File(widget.book.path).readAsString();
        final document = XmlDocument.parse(xmlString);
        final sections = document.findAllElements('section').toList();
        if (_currentPosition < sections.length) {
          final section = sections[_currentPosition];
          final paragraphs = section.findAllElements('p').map((p) {
            final text = p.text.trim();
            final isBold = p.findElements('strong').isNotEmpty;
            final isItalic = p.findElements('emphasis').isNotEmpty;
            return '<p${isBold ? ' style="font-weight: bold;"' : ''}${isItalic ? ' style="font-style: italic;"' : ''}>$text</p>';
          }).join('\n');
          return paragraphs.isNotEmpty ? paragraphs : 'Контент не найден';
        }
        return 'Контент не найден';
      }
      return 'Формат не поддерживается';
    } catch (e) {
      return 'Ошибка загрузки: $e';
    }
  }

  Future<void> _updateProgress() async {
    if (_totalPositions > 0) {
      final progress = ((_currentPosition + 1) * 100 ~/ _totalPositions).clamp(0, 100);
      await DatabaseHelper.instance.updateProgress(widget.book.id, progress);
    }
  }

  void _nextPosition() {
    setState(() {
      if (_currentPosition < _totalPositions - 1) {
        _currentPosition++;
        _contentKey.currentState?.setState(() {});
        _updateProgress();
      }
    });
  }

  void _previousPosition() {
    setState(() {
      if (_currentPosition > 0) {
        _currentPosition--;
        _contentKey.currentState?.setState(() {});
        _updateProgress();
      }
    });
  }

  void _addBookmarkDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text(
          'Добавить закладку',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
        content: TextField(
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
              await DatabaseHelper.instance.addBookmark(
                widget.book.id,
                _currentPosition,
                controller.text.isEmpty ? 'Закладка' : controller.text,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Закладка добавлена',
                    style: TextStyle(color: Color(0xFF4E342E)),
                  ),
                  backgroundColor: Color(0xFFBCAAA4),
                ),
              );
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

  void _saveQuoteDialog(String selectedText) {
    if (selectedText.isEmpty) return;
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text(
          'Сохранить цитату',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedText,
              style: const TextStyle(color: Color(0xFF4E342E)),
            ),
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
              await DatabaseHelper.instance.addQuote(
                widget.book.id,
                _currentPosition,
                selectedText,
                noteController.text.isEmpty ? null : noteController.text,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Цитата сохранена',
                    style: TextStyle(color: Color(0xFF4E342E)),
                  ),
                  backgroundColor: Color(0xFFBCAAA4),
                ),
              );
            },
            child: const Text(
              'Сохранить',
              style: TextStyle(color: Color(0xFF4E342E)),
            ),
          ),
          TextButton(
            onPressed: () {
              Share.share(selectedText);
              Navigator.pop(context);
            },
            child: const Text(
              'Поделиться',
              style: TextStyle(color: Color(0xFF4E342E)),
            ),
          ),
        ],
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
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add, color: Color(0xFF7B5E57)),
            onPressed: _addBookmarkDialog,
          ),
        ],
      ),
      body: FutureBuilder<String>(
        key: _contentKey,
        future: _loadRawContent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B5E57)),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка загрузки контента: ${snapshot.error}',
                style: const TextStyle(color: Color(0xFF4E342E)),
              ),
            );
          }
          final content = snapshot.data ?? 'Контент не найден';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: widget.book.format == 'EPUB'
                ? Html(
              data: content,
              style: {
                'body': Style(
                  fontSize: FontSize(16.0),
                  color: const Color(0xFF4E342E),
                ),
                'p': Style(margin: Margins.all(8.0)),
                'img': Style(
                  // Заглушка для сломанных изображений
                  display: Display.block,
                  width: Width(100),
                  height: Height(100),
                  backgroundColor: const Color(0xFF7B5E57),
                ),
              },
              onLinkTap: (url, _, __) => print('Tapped link: $url'),
            )
                : SelectableText(
              _paragraphs != null && _currentPosition < _paragraphs!.length
                  ? _paragraphs![_currentPosition]
                  : content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Color(0xFF4E342E),
              ),
              onSelectionChanged: (selection, cause) {
                if (selection.isValid) {
                  final text = _paragraphs != null &&
                      _currentPosition < _paragraphs!.length
                      ? _paragraphs![_currentPosition].substring(
                      selection.start.clamp(0, _paragraphs![_currentPosition].length),
                      selection.end.clamp(0, _paragraphs![_currentPosition].length))
                      : content.substring(
                      selection.start.clamp(0, content.length),
                      selection.end.clamp(0, content.length));
                  setState(() {
                    _selectedText = text;
                  });
                  _saveQuoteDialog(text);
                }
              },
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFFBCAAA4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _currentPosition > 0 ? _previousPosition : null,
              icon: const Icon(Icons.arrow_back, color: Color(0xFF7B5E57)),
            ),
            Text(
              widget.book.format == 'EPUB'
                  ? 'Глава ${_currentPosition + 1}/$_totalPositions'
                  : widget.book.format == 'FB2'
                  ? 'Секция ${_currentPosition + 1}/$_totalPositions'
                  : 'Абзац ${_currentPosition + 1}/$_totalPositions',
              style: const TextStyle(color: Color(0xFF4E342E)),
            ),
            IconButton(
              onPressed: _currentPosition < _totalPositions - 1 ? _nextPosition : null,
              icon: const Icon(Icons.arrow_forward, color: Color(0xFF7B5E57)),
            ),
          ],
        ),
      ),
    );
  }
}