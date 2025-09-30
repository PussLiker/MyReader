import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:my_reader/data/repositories/book_repository.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  final BookEntity? book;
  const AddBookScreen({super.key, this.book});

  @override
  _AddBookScreenState createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _categoryController = TextEditingController();
  String? _filePath;
  String? _errorMessage;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.book != null) {
      _isEditMode = true;
      _titleController.text = widget.book!.title;
      _authorController.text = widget.book!.author;
      _categoryController.text = widget.book!.category ?? '';
      _filePath = widget.book!.path;
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'txt', 'fb2'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        _errorMessage = null;
      });
    }
  }

  Future<void> _saveBook() async {
    if (_filePath == null && !_isEditMode) {
      setState(() {
        _errorMessage = 'Выберите файл';
      });
      return;
    }
    if (_titleController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Введите название';
      });
      return;
    }
    if (_authorController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Введите автора';
      });
      return;
    }

    String? category = _categoryController.text;
    if (category.isEmpty) {
      category = await _showCategoryDialog();
      if (category == null || category.isEmpty) {
        setState(() {
          _errorMessage = 'Категория обязательна';
        });
        return;
      }
    }

    try {
      final repo = ref.read(bookRepositoryProvider);
      if (_isEditMode) {
        final updatedBook = widget.book!.copyWith(
          title: _titleController.text,
          author: _authorController.text,
          category: category,
        );
        await repo.updateBook(updatedBook);
      } else {
        await repo.addBook(_filePath!, categoryOverride: category);
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка сохранения книги: $e';
      });
    }
  }

  Future<String?> _showCategoryDialog() async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEDE7D9),
        title: const Text(
          'Введите категорию',
          style: TextStyle(color: Color(0xFF4E342E)),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Категория',
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
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text(
              'Сохранить',
              style: TextStyle(color: Color(0xFF4E342E)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDE7D9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBCAAA4),
        title: Text(
          _isEditMode ? 'Редактировать книгу' : 'Добавить книгу',
          style: const TextStyle(color: Color(0xFF4E342E)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название',
                labelStyle: TextStyle(color: Color(0xFF4E342E)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7B5E57)),
                ),
              ),
              style: const TextStyle(color: Color(0xFF4E342E)),
            ),
            TextField(
              controller: _authorController,
              decoration: const InputDecoration(
                labelText: 'Автор',
                labelStyle: TextStyle(color: Color(0xFF4E342E)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7B5E57)),
                ),
              ),
              style: const TextStyle(color: Color(0xFF4E342E)),
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Категория',
                labelStyle: TextStyle(color: Color(0xFF4E342E)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7B5E57)),
                ),
              ),
              style: const TextStyle(color: Color(0xFF4E342E)),
            ),
            const SizedBox(height: 16),
            if (!_isEditMode)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBCAAA4),
                  foregroundColor: const Color(0xFF4E342E),
                ),
                onPressed: _pickFile,
                child: const Text('Выбрать файл'),
              ),
            if (_filePath != null) ...[
              const SizedBox(height: 16),
              Text(
                'Выбран файл: ${_filePath!.split('/').last}',
                style: const TextStyle(color: Color(0xFF4E342E)),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBCAAA4),
                foregroundColor: const Color(0xFF4E342E),
              ),
              onPressed: _saveBook,
              child: Text(_isEditMode ? 'Обновить' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}