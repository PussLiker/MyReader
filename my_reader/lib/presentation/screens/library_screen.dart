import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';
import 'package:my_reader/presentation/screens/add_book_screen.dart';
import 'package:my_reader/presentation/screens/reader_screen.dart';
import 'package:my_reader/presentation/screens/bookmarks_screen.dart';
import 'package:my_reader/presentation/screens/quotes_screen.dart';
import 'package:my_reader/app_colors.dart';

import '../widgets/ThemeToggleButton.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
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
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _refreshData() async {
    ref.invalidate(getBooksProvider(_selectedCategory));
    ref.invalidate(getBooksProvider(null));
    ref.invalidate(getAllBooksProvider);
    ref.invalidate(getCategoriesProvider);
    await _loadCategories();
  }

  Future<void> _editBook(BookEntity book, AppColors colors) async {
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
              backgroundColor: colors.accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при обновлении книги: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteBook(BookEntity book, AppColors colors) async {
    if (_isDeleting) return;
    _isDeleting = true;
    try {
      final repo = ref.read(bookRepositoryProvider);
      await repo.deleteBook(book.id);
      await _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Книга успешно удалена'),
            backgroundColor: colors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      _isDeleting = false;
    }
  }

  Future<void> _showDeleteConfirmation(
      BookEntity book, AppColors colors) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.background,
        title: Text('Удалить книгу?', style: TextStyle(color: colors.mainText)),
        content: Text('Вы уверены, что хотите удалить "${book.title}"?',
            style: TextStyle(color: colors.mainText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: colors.mainText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteBook(book, colors);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final booksAsync = ref.watch(getAllBooksProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.accent,
        title: Text(
          'Моя библиотека',
          style: TextStyle(color: colors.mainText, fontWeight: FontWeight.w600),
        ),
        actions: const [
          ThemeToggleButton(),
        ],
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: colors.mainText),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: _buildDrawer(colors),
      body: Column(
        children: [
          _buildSearchAndFilter(colors),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              backgroundColor: colors.background,
              color: colors.accent,
              child: booksAsync.when(
                data: (books) => _buildBooksList(books, colors),
                loading: () => _buildLoadingState(colors),
                error: (error, stack) => _buildErrorState(error, colors),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(AppColors colors) {
    return Drawer(
      backgroundColor: colors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colors.accent),
            child: Text('Меню',
                style: TextStyle(color: colors.mainText, fontSize: 24)),
          ),
          ListTile(
            leading: Icon(Icons.add, color: colors.secondaryText),
            title: Text('Добавить книгу',
                style: TextStyle(color: colors.mainText)),
            onTap: () async {
              Navigator.pop(context);
              final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddBookScreen()));
              if (result == true) await _refreshData();
            },
          ),
          ListTile(
            leading: Icon(Icons.bookmark, color: colors.secondaryText),
            title: Text('Закладки', style: TextStyle(color: colors.mainText)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BookmarksScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.format_quote, color: colors.secondaryText),
            title: Text('Цитаты', style: TextStyle(color: colors.mainText)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const QuotesScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(AppColors colors) {
    final categoriesAsync = ref.watch(getCategoriesProvider);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Поиск по названию...',
              hintStyle: TextStyle(color: colors.secondaryText),
              labelText: 'Поиск',
              labelStyle: TextStyle(color: colors.mainText),
              border: OutlineInputBorder(
                  borderSide: BorderSide(color: colors.border)),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colors.border)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: colors.mainText)),
              prefixIcon: Icon(Icons.search, color: colors.secondaryText),
            ),
            style: TextStyle(color: colors.mainText),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),
          categoriesAsync.when(
            data: (categories) {
              final displayCategories = ['Все категории', ...categories];
              return DropdownButton<String?>(
                hint: Text('Выберите категорию',
                    style: TextStyle(color: colors.mainText)),
                value: _selectedCategory,
                isExpanded: true,
                underline: Container(height: 1, color: colors.border),
                items: displayCategories
                    .map((cat) => DropdownMenuItem(
                          value: cat == 'Все категории' ? null : cat,
                          child: Text(cat,
                              style: TextStyle(color: colors.mainText)),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val),
              );
            },
            loading: () => CircularProgressIndicator(color: colors.accent),
            error: (err, _) =>
                Text('Ошибка: $err', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksList(List<BookEntity> books, AppColors colors) {
    final filtered = books
        .where((b) =>
            b.title.toLowerCase().contains(_searchQuery.toLowerCase()) &&
            (_selectedCategory == null || b.category == _selectedCategory))
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));

    if (filtered.isEmpty) {
      return Center(
          child: Text('Нет книг', style: TextStyle(color: colors.mainText)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: filtered.length,
      itemBuilder: (context, i) => _buildBookItem(filtered[i], colors),
    );
  }

  Widget _buildBookItem(BookEntity book, AppColors colors) {
    return Card(
      color: colors.cardBackground,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        title: Text(book.title,
            style:
                TextStyle(color: colors.mainText, fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${book.author}${book.category != null ? ' • ${book.category}' : ''}',
            style: TextStyle(color: colors.mainText)),
        leading: Container(
          width: 50,
          height: 70,
          decoration: BoxDecoration(
              color: colors.accent, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.menu_book, color: Colors.white, size: 30),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: colors.secondaryText),
          onSelected: (val) => val == 'edit'
              ? _editBook(book, colors)
              : _showDeleteConfirmation(book, colors),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
            const PopupMenuItem(
                value: 'delete',
                child: Text('Удалить', style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ReaderScreen(book: book))),
      ),
    );
  }

  Widget _buildLoadingState(AppColors colors) => Center(
      child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(colors.accent)));

  Widget _buildErrorState(Object error, AppColors colors) => Center(
        child: Column(children: [
          Text('Ошибка: $error', style: TextStyle(color: colors.mainText)),
          ElevatedButton(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(backgroundColor: colors.accent),
              child: const Text('Повторить')),
        ]),
      );

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
