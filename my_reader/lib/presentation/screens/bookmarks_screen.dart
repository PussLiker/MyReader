import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';
import 'package:my_reader/presentation/screens/reader_screen.dart';

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(getBooksProvider(null));

    return Scaffold(
      backgroundColor: const Color(0xFFEDE7D9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBCAAA4),
        title: const Text(
          'Закладки',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
      ),
      body: booksAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return const Center(
              child: Text(
                'Нет книг',
                style: TextStyle(color: Color(0xFF4E342E)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: DatabaseHelper.instance.getBookmarks(book.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text(
                        'Загрузка...',
                        style: TextStyle(color: Color(0xFF4E342E)),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return ListTile(
                      title: Text(
                        'Ошибка: ${snapshot.error}',
                        style: const TextStyle(color: Color(0xFF4E342E)),
                      ),
                    );
                  }
                  final bookmarks = snapshot.data ?? [];
                  if (bookmarks.isEmpty) {
                    return Container(); // Пропускаем книги без закладок
                  }
                  return ExpansionTile(
                    title: Text(
                      book.title,
                      style: const TextStyle(
                        color: Color(0xFF4E342E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      book.author,
                      style: const TextStyle(color: Color(0xFF4E342E)),
                    ),
                    children: bookmarks.map((bookmark) {
                      return Dismissible(
                        key: Key(bookmark['id'].toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) async {
                          await DatabaseHelper.instance.deleteBookmark(bookmark['id']);
                          ref.refresh(getBooksProvider(null)); // Обновляем, чтобы триггернуть rebuild
                        },
                        child: ListTile(
                          title: Text(
                            'Позиция: ${bookmark['position']}',
                            style: const TextStyle(color: Color(0xFF4E342E)),
                          ),
                          subtitle: Text(
                            bookmark['note'],
                            style: const TextStyle(color: Color(0xFF4E342E)),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReaderScreen(book: book),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B5E57)),
          ),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Ошибка: $error',
            style: const TextStyle(color: Color(0xFF4E342E)),
          ),
        ),
      ),
    );
  }
}