import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:xml/xml.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/infrastructure/epub/Epub_parser.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final BookEntity book;
  const ReaderScreen({required this.book, super.key});

  @override
  _ReaderScreenState createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  int _currentChapterIndex = 0;
  List<epub.EpubChapter>? _chapters;
  List<String>? _paragraphs;
  String? _selectedText;
  epub.EpubBook? _epubBook;

  @override
  void initState() {
    super.initState();
    if (widget.book.format == 'EPUB') {
      _loadChapters();
    } else {
      _loadParagraphs();
    }
  }

  Future<void> _loadChapters() async {
    final epubBook = await epub.EpubReader.readBook(File(widget.book.path).readAsBytesSync());
    setState(() {
      _epubBook = epubBook;
      _chapters = epubBook.Chapters ?? [];
    });
  }

  Future<void> _loadParagraphs() async {
    final content = await _loadContent();
    setState(() {
      _paragraphs = content.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    });
  }

  Future<String> _loadContent() async {
    if (widget.book.format == 'EPUB') {
      final chapter = _epubBook?.Chapters?[_currentChapterIndex];
      return chapter?.HtmlContent ?? 'Контент не найден';
    } else if (widget.book.format == 'TXT') {
      return await File(widget.book.path).readAsString();
    } else if (widget.book.format == 'FB2') {
      final xmlString = await File(widget.book.path).readAsString();
      final document = XmlDocument.parse(xmlString);
      final sections = document.findAllElements('section').toList();
      if (_currentChapterIndex < sections.length) {
        final section = sections[_currentChapterIndex];
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
  }

  void _updateProgress() {
    if (widget.book.format == 'EPUB' && _chapters != null && _chapters!.isNotEmpty) {
      final progress = ((_currentChapterIndex + 1) * 100 / _chapters!.length).round();
      DatabaseHelper.instance.updateProgress(widget.book.id, progress);
    } else if ((widget.book.format == 'TXT' || widget.book.format == 'FB2') && _paragraphs != null && _paragraphs!.isNotEmpty) {
      final progress = ((_currentChapterIndex + 1) * 100 / _paragraphs!.length).round();
      DatabaseHelper.instance.updateProgress(widget.book.id, progress);
    }
  }

  void _nextChapter() {
    setState(() {
      if ((widget.book.format == 'EPUB' && _chapters != null && _currentChapterIndex < _chapters!.length - 1) ||
          ((_paragraphs != null && _currentChapterIndex < _paragraphs!.length - 1))) {
        _currentChapterIndex++;
        _updateProgress();
      }
    });
  }

  void _previousChapter() {
    setState(() {
      if (_currentChapterIndex > 0) {
        _currentChapterIndex--;
        _updateProgress();
      }
    });
  }

  Widget _buildEpubContent(String html) {
    final regExp = RegExp(r'<img[^>]+src="([^">]+)"[^>]*>|([^<]+)', multiLine: true);
    final contentWidgets = <Widget>[];

    for (final match in regExp.allMatches(html)) {
      final imgSrc = match.group(1);
      final text = match.group(2);

      if (imgSrc != null) {
        final imageFile = _epubBook?.Content?.Images?[imgSrc];
        if (imageFile != null && imageFile.Content != null) {
          contentWidgets.add(
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Image.memory(
                Uint8List.fromList(imageFile.Content!),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, size: 50),
              ),
            ),
          );
        } else {
          contentWidgets.add(const Icon(Icons.broken_image, size: 50));
        }
      } else if (text != null && text.trim().isNotEmpty) {
        contentWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(text.trim(), style: const TextStyle(fontSize: 16)),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.book.title)),
      body: FutureBuilder<String>(
        future: _loadContent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final content = snapshot.data ?? 'Контент не найден';

          if (widget.book.format == 'EPUB') {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildEpubContent(content),
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                _paragraphs != null && _currentChapterIndex < _paragraphs!.length
                    ? _paragraphs![_currentChapterIndex]
                    : content,
                style: const TextStyle(fontSize: 16, height: 1.5),
                onSelectionChanged: (selection, cause) {
                  if (selection.isValid) {
                    setState(() {
                      _selectedText = _paragraphs != null &&
                          _currentChapterIndex < _paragraphs!.length
                          ? _paragraphs![_currentChapterIndex].substring(
                          selection.start, selection.end)
                          : content.substring(selection.start, selection.end);
                    });
                  }
                },
              ),
            );
          }
        },
      ),
      bottomNavigationBar: widget.book.format == 'TXT' || widget.book.format == 'FB2'
          ? Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: _currentChapterIndex > 0 ? _previousChapter : null,
              child: const Text('Предыдущий'),
            ),
            Text(
              'Абзац ${_currentChapterIndex + 1}/${_paragraphs?.length ?? 1}',
            ),
            ElevatedButton(
              onPressed: (_paragraphs != null && _currentChapterIndex < _paragraphs!.length - 1)
                  ? _nextChapter
                  : null,
              child: const Text('Следующий'),
            ),
          ],
        ),
      )
          : null,
    );
  }
}
