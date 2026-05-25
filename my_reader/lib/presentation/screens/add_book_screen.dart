import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:epubx/epubx.dart';
import 'package:xml/xml.dart' as xml;
import 'package:path/path.dart' as path;
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:my_reader/domain/use_cases/add_book.dart';
import 'package:my_reader/presentation/providers/book_provider.dart';

import '../../app_colors.dart';
import '../widgets/ThemeToggleButton.dart'; // ДОБАВЛЕНО

class AddBookScreen extends ConsumerStatefulWidget {
  final BookEntity? book;

  const AddBookScreen({super.key, this.book});

  @override
  _AddBookScreenState createState() => _AddBookScreenState();
}

class _AddBookScreenState extends ConsumerState<AddBookScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _categoryController = TextEditingController();
  String? _filePath;
  String? _fileFormat;
  String? _errorMessage;
  bool _isEditMode = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.book != null) {
      _isEditMode = true;
      _titleController.text = widget.book!.title;
      _authorController.text = widget.book!.author;
      _categoryController.text = widget.book!.category ?? '';
      _filePath = widget.book!.path;
      _fileFormat = widget.book!.format;
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;
      final extension = path.extension(selectedPath).toLowerCase();
      if (!['.epub', '.fb2', '.txt'].contains(extension)) {
        setState(() {
          _errorMessage = 'Поддерживаются только EPUB, FB2, TXT файлы';
        });
        return;
      }

      setState(() {
        _filePath = selectedPath;
        _fileFormat = extension.substring(1);
        _errorMessage = null;
      });

      try {
        final file = File(_filePath!);
        if (_fileFormat == 'epub') {
          final epub = await EpubReader.readBook(file.readAsBytesSync());
          if (_titleController.text.isEmpty) {
            _titleController.text =
                epub.Title ?? path.basenameWithoutExtension(_filePath!);
          }
          if (_authorController.text.isEmpty) {
            _authorController.text = epub.Author ?? 'Unknown';
          }
          if (_categoryController.text.isEmpty) {
            final subjects = epub.Schema?.Package?.Metadata?.Subjects;
            _categoryController.text =
                subjects?.isNotEmpty == true ? subjects!.first : 'Fiction';
          }
        } else if (_fileFormat == 'fb2') {
          final content = await file.readAsString();
          final document = xml.XmlDocument.parse(content);
          final titleInfo = document.findAllElements('title-info').firstOrNull;
          if (titleInfo != null) {
            if (_titleController.text.isEmpty) {
              _titleController.text =
                  titleInfo.findElements('book-title').firstOrNull?.text ??
                      path.basenameWithoutExtension(_filePath!);
            }
            if (_authorController.text.isEmpty) {
              final author = titleInfo.findElements('author').firstOrNull;
              final firstName =
                  author?.findElements('first-name').firstOrNull?.text ?? '';
              final lastName =
                  author?.findElements('last-name').firstOrNull?.text ?? '';
              _authorController.text = '$firstName $lastName'.trim();
              if (_authorController.text.isEmpty)
                _authorController.text = 'Unknown';
            }
            if (_categoryController.text.isEmpty) {
              _categoryController.text =
                  titleInfo.findElements('genre').firstOrNull?.text ??
                      'Fiction';
            }
          }
        } else if (_fileFormat == 'txt') {
          if (_titleController.text.isEmpty) {
            _titleController.text = path.basenameWithoutExtension(_filePath!);
          }
          if (_categoryController.text.isEmpty) {
            _categoryController.text = 'Text';
          }
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Ошибка парсинга файла: $e';
        });
      }
    } else {
      setState(() {
        _errorMessage = 'Файл не выбран';
      });
    }
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_filePath == null && !_isEditMode) {
      setState(() {
        _errorMessage = 'Выберите файл';
      });
      return;
    }

    final repo = ref.read(bookRepositoryProvider);
    final addBookUseCase = AddBook(repo);

    try {
      if (_isEditMode) {
        final updatedBook = BookEntity(
          id: widget.book!.id,
          title: _titleController.text.trim(),
          author: _authorController.text.trim(),
          path: _filePath ?? widget.book!.path,
          format: _fileFormat ?? widget.book!.format,
          coverPath: widget.book?.coverPath,
          progress: widget.book?.progress ?? 0,
          position: widget.book?.position ?? 0.0,
          category: _categoryController.text.trim().isEmpty
              ? null
              : _categoryController.text.trim(),
        );

        await repo.updateBook(updatedBook);
      } else {
        await addBookUseCase(
          filePath: _filePath!,
          title: _titleController.text.trim(),
          author: _authorController.text.trim(),
          category: _categoryController.text.trim().isEmpty
              ? 'Fiction'
              : _categoryController.text.trim(),
        );
      }

      // Инвалидируем ВСЕ провайдеры книг
      ref.invalidate(getBooksProvider(null));
      ref.invalidate(getAllBooksProvider);

      // Обновляем категории
      ref.invalidate(getCategoriesProvider);

      // ДОБАВЛЕНО: Очищаем пустые категории из БД
      await repo.cleanupOrphanedCategories();

      if (mounted) {
        // Возвращаем true, а не просто закрываем
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Ошибка при сохранении: $e');
      setState(() {
        _errorMessage = 'Ошибка сохранения: $e';
      });
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Это поле обязательно для заполнения';
    }
    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _categoryController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.accent,
        title: Text(
          _isEditMode ? 'Редактировать книгу' : 'Добавить книгу',
          style: TextStyle(
            color: colors.mainText,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: const [
          ThemeToggleButton(),
        ],
        iconTheme: IconThemeData(color: colors.mainText),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Поля ввода используем как пример для остальных
                _buildTextFormField(
                    controller: _titleController,
                    label: 'Название *',
                    colors: colors),
                const SizedBox(height: 16),
                _buildTextFormField(
                    controller: _authorController,
                    label: 'Автор *',
                    colors: colors),
                const SizedBox(height: 16),
                _buildTextFormField(
                    controller: _categoryController,
                    label: 'Категория *',
                    colors: colors),
                const SizedBox(height: 16),

                if (!_isEditMode)
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: Icon(Icons.attach_file, color: colors.mainText),
                    label: const Text('Выбрать файл'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.border,
                      // или colors.cardBackground
                      foregroundColor: colors.mainText,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),

                if (_filePath != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.insert_drive_file,
                          color: colors.secondaryText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Выбран файл: ${_filePath!.split('/').last}',
                          style: TextStyle(color: colors.mainText),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saveBook,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    _isEditMode ? 'Обновить' : 'Сохранить',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Удобный метод, чтобы не дублировать код полей
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required AppColors colors,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.mainText),
        enabledBorder:
            OutlineInputBorder(borderSide: BorderSide(color: colors.border)),
        focusedBorder:
            OutlineInputBorder(borderSide: BorderSide(color: colors.mainText)),
      ),
      style: TextStyle(color: colors.mainText),
      validator: (value) => value?.isEmpty == true ? 'Обязательное поле' : null,
    );
  }
}
