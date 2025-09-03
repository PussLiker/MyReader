// my_reader/lib/presentation/screens/library_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';

class LibraryScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Моя библиотека'),
      ),
      body: FutureBuilder<List<BookEntity>>(
        future: ref.read(bookProvider).getBooks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }
          final books = snapshot.data ?? [];
          if (books.isEmpty) {
            return Center(child: Text('Нет книг в библиотеке'));
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
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Добавление книги (заглушка)')),
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}