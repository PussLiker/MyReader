import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:epubx/epubx.dart';
import 'dart:io';

class ReaderScreen extends ConsumerWidget {
  final BookEntity book;

  const ReaderScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book.title),
      ),
      body: FutureBuilder<String>(
        future: _loadContent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText(
                snapshot.data ?? 'Контент не найден',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<String> _loadContent() async {
    try {
      if (book.format == 'TXT') {
        final file = File(book.path);
        return await file.readAsString();
      } else if (book.format == 'EPUB') {
        final file = File(book.path);
        final bytes = await file.readAsBytes();
        final epub = await EpubReader.readBook(bytes);
        // Извлекаем текст первой главы (для MVP)
        final chapters = epub.Chapters ?? [];
        if (chapters.isEmpty) return 'Нет глав';
        final chapter = chapters.first;
        return chapter.HtmlContent ?? 'Контент главы не найден';
      } else {
        return 'Формат ${book.format} пока не поддерживается';
      }
    } catch (e) {
      throw Exception('Не удалось загрузить книгу: $e');
    }
  }
}