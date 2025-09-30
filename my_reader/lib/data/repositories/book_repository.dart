import 'dart:io';
import 'package:epubx/epubx.dart';
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';

class BookRepository {
  final DatabaseHelper databaseHelper;

  BookRepository(this.databaseHelper);

  Future<List<BookEntity>> getBooks() async {
    return await databaseHelper.getBooks();
  }

  Future<int> addBook(String filePath, {String? categoryOverride}) async {
    final format = path.extension(filePath).toLowerCase().replaceFirst('.', '');
    String title = path.basenameWithoutExtension(filePath);
    String author = 'Unknown';
    String? category;

    if (format == 'epub') {
      try {
        final epub = await EpubReader.readBook(await File(filePath).readAsBytes());
        title = epub.Title ?? title;
        author = epub.Author ?? author;
        final metadata = epub.Schema?.Package?.Metadata;
        if (metadata != null && metadata.Subjects != null && metadata.Subjects!.isNotEmpty) {
          category = metadata.Subjects!.join(', ');
        } else {
          category = 'Fiction';
        }
      } catch (e) {
        print('Error reading EPUB: $e');
        category = 'Fiction';
      }
    } else if (format == 'txt') {
      category = 'Text';
    } else if (format == 'fb2') {
      try {
        final xmlString = await File(filePath).readAsString();
        final document = XmlDocument.parse(xmlString);
        final bookTitle = document.findAllElements('book-title').firstOrNull?.text;
        final authorFirstName = document.findAllElements('first-name').firstOrNull?.text;
        final authorLastName = document.findAllElements('last-name').firstOrNull?.text;
        final genre = document.findAllElements('genre').firstOrNull?.text;
        title = bookTitle ?? title;
        author = authorFirstName != null && authorLastName != null
            ? '$authorFirstName $authorLastName'
            : author;
        category = genre ?? 'Fiction';
      } catch (e) {
        print('Error reading FB2: $e');
        category = 'Fiction';
      }
    } else {
      throw Exception('Unsupported file format: $format');
    }

    category = categoryOverride ?? category;
    if (category != null && !await databaseHelper.categoryExists(category)) {
      await databaseHelper.insertCategory(category);
    }

    final book = BookEntity(
      id: 0,
      title: title,
      author: author,
      path: filePath,
      format: format.toUpperCase(),
      coverPath: null, // Обложки пока не поддерживаются
      progress: 0,
      category: category,
    );

    return await databaseHelper.insertBook(book);
  }

  Future<void> updateBook(BookEntity book) async {
    await databaseHelper.updateBook(book);
  }

  Future<void> deleteBook(int bookId) async {
    await databaseHelper.deleteBook(bookId);
  }

  Future<List<String>> getCategories() async {
    return await databaseHelper.getCategories();
  }

  Future<void> updateProgress(int bookId, int progress) async {
    await databaseHelper.updateProgress(bookId, progress);
  }

  Future<int> addBookmark(int bookId, int position, String note) async {
    return await databaseHelper.addBookmark(bookId, position, note);
  }

  Future<List<Map<String, dynamic>>> getBookmarks(int bookId) async {
    return await databaseHelper.getBookmarks(bookId);
  }

  Future<void> deleteBookmark(int bookmarkId) async {
    await databaseHelper.deleteBookmark(bookmarkId);
  }

  Future<int> addQuote(int bookId, int position, String quoteText, String? comment) async {
    return await databaseHelper.addQuote(bookId, position, quoteText, comment);
  }

  Future<List<Map<String, dynamic>>> getQuotes(int bookId) async {
    return await databaseHelper.getQuotes(bookId);
  }

  Future<void> deleteQuote(int quoteId) async {
    await databaseHelper.deleteQuote(quoteId);
  }
}