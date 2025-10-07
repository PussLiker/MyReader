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
  final List<String> _categories = ['Все категории'];
  final TextEditingController _searchController = TextEditingController();
  bool _isDeleting = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final repo = ref.read(bookRepositoryProvider);
      final allCategories = await repo.getCategories();

      // Фильтруем категории, оставляя только те, в которых есть книги
      final nonEmptyCategories = <String>[];
      for (final category in allCategories) {
        final books = await repo.getBooks(category);
        if (books.isNotEmpty) {
          nonEmptyCategories.add(category);
        }
      }

      setState(() {
        _categories
          ..clear()
          ..addAll(['Все категории', ...nonEmptyCategories]);

        // Проверяем, существует ли выбранная категория в обновленном списке
        if (_selectedCategory != null &&
            _selectedCategory != 'Все категории' &&
            !nonEmptyCategories.contains(_selectedCategory)) {
          _selectedCategory = null;
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _refreshData() async {
    // Инвалидируем все провайдеры книг
    ref.invalidate(getBooksProvider(_selectedCategory));
    ref.invalidate(getBooksProvider(null));
    await _loadCategories();
  }

  Future<void> _editBook(BookEntity book) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddBookScreen(book: book)),
      );

      if (result is Map && result['result'] == true) {
        await _refreshData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Книга успешно обновлена'),
              backgroundColor: const Color(0xFF8D6E63),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error editing book: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при обновлении книги: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteBook(BookEntity book) async {
    if (_isDeleting) return;

    _isDeleting = true;
    try {
      final repo = ref.read(bookRepositoryProvider);
      await repo.deleteBook(book.id);

      // Обновляем данные
      await _refreshData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Книга успешно удалена'),
            backgroundColor: const Color(0xFF8D6E63),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error deleting book: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении книги: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      _isDeleting = false;
    }
  }

  Future<void> _showDeleteConfirmation(BookEntity book) async {
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
      await _deleteBook(book);
    }
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
          style: TextStyle(
              color: Color(0xFF4E342E),
              fontWeight: FontWeight.w600),
          ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF4E342E)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),

      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              backgroundColor: const Color(0xFFEDE7D9),
              color: const Color(0xFF8D6E63),
              child: booksAsync.when(
                data: (books) => _buildBooksList(books),
                loading: () => _buildLoadingState(),
                error: (error, stack) => _buildErrorState(error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFEDE7D9),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFFBCAAA4),
            ),
            child: Text(
              'Меню',
              style: TextStyle(
                color: Color(0xFF4E342E),
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

              if (result is Map && result['result'] == true) {
                await _refreshData();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Книга успешно добавлена'),
                      backgroundColor: const Color(0xFF8D6E63),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
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
    );
  }

  Widget _buildSearchAndFilter() {
    // Убедимся, что выбранная категория существует в списке
    final validSelectedCategory = _categories.contains(_selectedCategory == null
        ? 'Все категории'
        : _selectedCategory)
        ? _selectedCategory
        : null;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode, // ДОБАВИТЬ ЭТУ СТРОКУ
            decoration: const InputDecoration(
              labelText: 'Поиск по названию',
              labelStyle: TextStyle(color: Color(0xFF4E342E)),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF7B5E57)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF7B5E57)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF4E342E)),
              ),
            ),
            style: const TextStyle(color: Color(0xFF4E342E)),
            autofocus: false,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            onTap: () {
              // Опционально: автоматически фокусироваться только при явном тапе
              _searchFocusNode.requestFocus();
            },
          ),
          const SizedBox(height: 16),
          DropdownButton<String?>(
            hint: const Text(
              'Выберите категорию',
              style: TextStyle(color: Color(0xFF4E342E)),
            ),
            value: validSelectedCategory,
            isExpanded: true,
            items: _categories
                .map((category) => DropdownMenuItem(
              value: category == 'Все категории' ? null : category,
              child: Text(
                category,
                style: const TextStyle(color: Color(0xFF4E342E)),
              ),
            ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBooksList(List<BookEntity> books) {
    final filteredBooks = books.where((book) {
      final matchesSearch = book.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || book.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList()
      ..sort((a, b) => b.id.compareTo(a.id));

    if (filteredBooks.isEmpty) {
      return const Center(
        child: Text(
          'Нет книг',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: filteredBooks.length,
      itemBuilder: (context, index) {
        final book = filteredBooks[index];
        return _buildBookItem(book);
      },
    );
  }

  Widget _buildBookItem(BookEntity book) {
    return Card(
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
          '${book.author}${book.category != null ? ' • ${book.category}' : ''}',
          style: const TextStyle(color: Color(0xFF4E342E)),
        ),

        // В методе _buildBookItem замените leading на:
        leading: Container(
          width: 50,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFF8D6E63),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.menu_book,
            color: Colors.white,
            size: 30,
          ),
        ),
        // Альтернативный вариант - меню с тремя точками
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF7B5E57)),
          onSelected: (value) {
            if (value == 'edit') {
              _editBook(book);
            } else if (value == 'delete') {
              _showDeleteConfirmation(book);
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Color(0xFF7B5E57), size: 20),
                  SizedBox(width: 8),
                  Text('Редактировать'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Color(0xFF7B5E57), size: 20),
                  SizedBox(width: 8),
                  Text('Удалить'),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReaderScreen(book: book),
            ),
          );
        },
        // Долгое нажатие для удаления
        onLongPress: () => _showDeleteConfirmation(book),
      ),
    );
  }

  Widget _buildDefaultCover(BookEntity book) {
    return Container(
      width: 50,
      height: 70,
      color: Colors.brown[300],
      child: Icon(
        Icons.book,
        color: Colors.white,
        size: 30,
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B5E57)),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ошибка загрузки книг: $error',
            style: const TextStyle(color: Color(0xFF4E342E)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8D6E63),
              foregroundColor: Colors.white,
            ),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }
}
