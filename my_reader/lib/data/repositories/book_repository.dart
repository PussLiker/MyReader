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

  Future<void> addBook(String filePath) async {
    final format = path.extension(filePath).toLowerCase().replaceFirst('.', '');
    String title = path.basenameWithoutExtension(filePath);
    String author = 'Unknown';
    String? coverPath;
    String? category;

    if (format == 'epub') {
      try {
        final epub = await EpubReader.readBook(File(filePath).readAsBytesSync());
        title = epub.Title ?? title;
        author = epub.Author ?? author;
        if (epub.CoverImage != null) {
          final coverFile = File('${filePath}_cover.jpg');
          coverPath = coverFile.path;
        }
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

    final book = BookEntity(
      id: 0,
      title: title,
      author: author,
      path: filePath,
      format: format.toUpperCase(),
      coverPath: coverPath,
      category: category,
    );

    await databaseHelper.insertBook(book);
  }

  Future<void> updateProgress(int bookId, int progress) async {
    await databaseHelper.updateProgress(bookId, progress);
  }

  Future<void> addBookmark(int bookId, int chapterIndex, String description) async {
    await databaseHelper.addBookmark(bookId, chapterIndex, description);
  }

  Future<List<Map<String, dynamic>>> getBookmarks(int bookId) async {
    return await databaseHelper.getBookmarks(bookId);
  }

  Future<void> addQuote(int bookId, int chapterIndex, String quoteText) async {
    await databaseHelper.addQuote(bookId, chapterIndex, quoteText);
  }

  Future<List<Map<String, dynamic>>> getQuotes(int bookId) async {
    return await databaseHelper.getQuotes(bookId);
  }
}