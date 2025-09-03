import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:my_reader/data/repositories/book_repository.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';

class AddBookScreen extends ConsumerStatefulWidget {
  const AddBookScreen({super.key});

  @override
  _AddBookScreenState createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _categoryController = TextEditingController();
  String? _filePath;
  String? _errorMessage;

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
      final repo = ref.read(bookRepositoryProvider);
      try {
        await repo.addBook(result.files.single.path!);
        final books = await repo.getBooks();
        final book = books.firstWhere((book) => book.path == _filePath);
        _titleController.text = book.title;
        _authorController.text = book.author;
        _categoryController.text = book.category ?? 'Fiction';
      } catch (e) {
        setState(() {
          _errorMessage = 'Ошибка чтения метаданных: $e';
        });
      }
    }
  }

  Future<void> _saveBook() async {
    if (_filePath == null) {
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
    try {
      final repo = ref.read(bookRepositoryProvider);
      await repo.addBook(_filePath!);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка добавления книги: $e';
      });
    }
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
      appBar: AppBar(
        title: const Text('Добавить книгу'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            TextField(
              controller: _authorController,
              decoration: const InputDecoration(labelText: 'Автор'),
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Категория (опционально)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickFile,
              child: const Text('Выбрать файл'),
            ),
            if (_filePath != null) ...[
              const SizedBox(height: 16),
              Text('Выбран файл: ${_filePath!.split('/').last}'),
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
              onPressed: _saveBook,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}