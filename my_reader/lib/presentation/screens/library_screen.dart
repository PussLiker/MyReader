import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';
import 'package:my_reader/presentation/screens/add_book.dart';
import 'package:my_reader/presentation/screens/reader_screen.dart';
import 'package:my_reader/presentation/screens/bookmarks_screen.dart';
import 'package:my_reader/presentation/screens/quotes_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  List<String> _categories = [];
  List<BookEntity> _books = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final repo = ref.read(bookRepositoryProvider);
    final categories = await repo.getCategories();
    setState(() {
      _categories = ['Все категории', ...categories];
      _selectedCategory = _selectedCategory ?? 'Все категории';
    });
  }

  Future<void> _editBook(BookEntity book) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddBookScreen(book: book)),
    );
    if (result == true) {
      ref.invalidate(getBooksProvider(null)); // Принудительно обновляем все категории
      ref.invalidate(getBooksProvider(_selectedCategory)); // Обновляем текущую категорию
      await _loadCategories(); // Обновляем категории
      // Даём время провайдеру обновиться
      await Future.delayed(const Duration(milliseconds: 100));
      final updatedBooks = await ref.read(getBooksProvider(_selectedCategory).future);
      setState(() {
        _books = updatedBooks;
        print('Books after edit: ${_books.length}'); // Дебаг-лог
      });
    }
  }

  Future<bool?> _confirmDeleteBook(BookEntity book) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text(
          'Удалить книгу?',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
        content: Text(
          'Вы уверены, что хотите удалить "${book.title}"?',
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
    if (result == true) {
      final repo = ref.read(bookRepositoryProvider);
      await repo.deleteBook(book.id);
      ref.invalidate(getBooksProvider(null)); // Принудительно обновляем все категории
      ref.invalidate(getBooksProvider(_selectedCategory)); // Обновляем текущую категорию
      await _loadCategories(); // Обновляем категории
      // Даём время провайдеру обновиться
      await Future.delayed(const Duration(milliseconds: 100));
      final updatedBooks = await ref.read(getBooksProvider(_selectedCategory).future);
      setState(() {
        _books = updatedBooks;
        print('Books after delete: ${_books.length}'); // Дебаг-лог
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(getBooksProvider(_selectedCategory));

    return Scaffold(
      backgroundColor: const Color(0xFFEDE7D9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBCAAA4),
        title: const Text(
          'Моя библиотека',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF4E342E)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFFEDE7D9),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFBCAAA4),
              ),
              child: Text(
                'Меню',
                style: TextStyle(
                  color: const Color(0xFF4E342E),
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add, color: Color(0xFF7B5E57)),
              title: const Text(
                'Добавить книгу',
                style: TextStyle(color: Color(0xFF4E342E)),
              ),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const AddBookScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
                if (result == true) {
                  ref.invalidate(getBooksProvider(null)); // Принудительно обновляем все категории
                  ref.invalidate(getBooksProvider(_selectedCategory)); // Обновляем текущую категорию
                  await _loadCategories(); // Обновляем категории
                  // Даём время провайдеру обновиться
                  await Future.delayed(const Duration(milliseconds: 100));
                  final updatedBooks = await ref.read(getBooksProvider(_selectedCategory).future);
                  setState(() {
                    _books = updatedBooks;
                    print('Books after add: ${_books.length}'); // Дебаг-лог
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark, color: Color(0xFF7B5E57)),
              title: const Text(
                'Закладки',
                style: TextStyle(color: Color(0xFF4E342E)),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const BookmarksScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_quote, color: Color(0xFF7B5E57)),
              title: const Text(
                'Цитаты',
                style: TextStyle(color: Color(0xFF4E342E)),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const QuotesScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Поиск по названию',
                    labelStyle: const TextStyle(color: Color(0xFF4E342E)),
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF7B5E57)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF7B5E57)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF4E342E)),
                    ),
                  ),
                  style: const TextStyle(color: Color(0xFF4E342E)),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButton<String?>(
                  hint: const Text(
                    'Выберите категорию',
                    style: TextStyle(color: Color(0xFF4E342E)),
                  ),
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _categories
                      .map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(
                      category,
                      style: const TextStyle(color: Color(0xFF4E342E)),
                    ),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value == 'Все категории' ? null : value;
                    });
                    ref.invalidate(getBooksProvider(_selectedCategory)); // Принудительное обновление
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: booksAsync.when(
              data: (books) {
                print('Books from provider: ${books.length}'); // Дебаг-лог
                _books = books.where((book) {
                  final matchesSearch =
                  book.title.toLowerCase().contains(_searchQuery.toLowerCase());
                  final matchesCategory = _selectedCategory == null ||
                      _selectedCategory == 'Все категории' ||
                      book.category == _selectedCategory;
                  return matchesSearch && matchesCategory;
                }).toList()
                  ..sort((a, b) => b.id.compareTo(a.id)); // Сортировка по новизне
                print('Filtered books: ${_books.length}'); // Дебаг-лог
                if (_books.isEmpty) {
                  return const Center(
                    child: Text(
                      'Нет книг',
                      style: TextStyle(color: Color(0xFF4E342E)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _books.length,
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    return Dismissible(
                      key: Key(book.id.toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await _confirmDeleteBook(book);
                      },
                      child: Card(
                        color: const Color(0xFFBCAAA4),
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
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
                          leading: const Icon(
                            Icons.book,
                            color: Color(0xFF7B5E57),
                            size: 50,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF7B5E57)),
                            onPressed: () => _editBook(book),
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
                      ),
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
          ),
        ],
      ),
    );
  }
}