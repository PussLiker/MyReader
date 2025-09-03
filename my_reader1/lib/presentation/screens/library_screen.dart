import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/infrastructure/epub/epub_parser.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Моя библиотека'),
      ),
      body: FutureBuilder<List<BookEntity>>(
        future: ref.read(bookProvider).getBooks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final books = snapshot.data ?? [];
          if (books.isEmpty) {
            return const Center(child: Text('Нет книг в библиотеке'));
          }
          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return Card(
                child: ListTile(
                  title: Text(book.title),
                  subtitle: Text('${book.author} | ${book.category} | ${book.progress}%'),
                  onTap: () {
                    Navigator.pushNamed(context, '/reader', arguments: book);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            // Выбор файла
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              allowedExtensions: ['epub', 'fb2', 'txt'],
              type: FileType.custom,
            );
            if (result != null && result.files.single.path != null) {
              String path = result.files.single.path!;
              String format = path.split('.').last.toUpperCase();
              if (!['EPUB', 'FB2', 'TXT'].contains(format)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Неподдерживаемый формат: $format')),
                );
                return;
              }

              // Извлечение метаданных
              String title = result.files.single.name;
              String author = 'Неизвестен';
              String category = 'Другое';

              if (format == 'EPUB') {
                final parser = EpubParser();
                final metadata = await parser.parseMetadata(path);
                title = metadata['title']!;
                author = metadata['author']!;
                category = metadata['category']!;
              } else if (format == 'TXT') {
                // Для TXT используем имя файла как заголовок
                title = result.files.single.name.replaceAll('.txt', '');
              } else if (format == 'FB2') {
                // Для FB2 пока заглушка, позже добавим парсинг через xml
                title = result.files.single.name.replaceAll('.fb2', '');
              }

              // Добавление книги
              await ref.read(bookProvider).addBook(
                title: title,
                authorFirstName: author,
                path: path,
                format: format,
                category: category,
              );

              // Обновить UI
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Книга добавлена')),
              );
              (context as Element).markNeedsBuild();
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ошибка: $e')),
            );
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}