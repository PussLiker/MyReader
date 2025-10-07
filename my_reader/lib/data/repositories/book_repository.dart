import 'dart:io';
import 'dart:convert';
import 'package:epubx/epubx.dart' as epub;
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

import '../../domain/entities/reading_position.dart';

class BookRepository {
  final DatabaseHelper databaseHelper;

  BookRepository(this.databaseHelper);

  Future<List<BookEntity>> getBooks([String? category]) async {
    return category == null
        ? await databaseHelper.getBooks()
        : await databaseHelper.getBooksByCategory(category);
  }

  Future<int> addBook(
      String filePath, {
        String? categoryOverride,
        String? titleOverride,
        String? authorOverride,
      }) async {
    final format = path.extension(filePath).toLowerCase().replaceFirst('.', '');
    String title = titleOverride ?? path.basenameWithoutExtension(filePath);
    String author = authorOverride ?? 'Unknown';
    String category = categoryOverride ?? 'Fiction';

    if (format == 'epub') {
      try {
        final bytes = await File(filePath).readAsBytes();
        final epubBook = await epub.EpubReader.readBook(bytes);

        title = epubBook.Title ?? title;
        author = epubBook.Author ?? author;

        final metadata = epubBook.Schema?.Package?.Metadata;
        if (metadata != null && metadata.Subjects != null && metadata.Subjects!.isNotEmpty) {
          category = metadata.Subjects!.join(', ');
        }

        print('EPUB book added: $title by $author');
      } catch (e) {
        print('Error reading EPUB: $e');
      }
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
        if (categoryOverride == null) {
          category = genre ?? 'Fiction';
        }

        print('FB2 book added: $title by $author');
      } catch (e) {
        print('Error reading FB2: $e');
      }
    } else if (format == 'txt') {
      category = 'Text';
      print('TXT book added: $title by $author');
    } else {
      throw Exception('Unsupported file format: $format');
    }

    if (!await databaseHelper.categoryExists(category)) {
      await databaseHelper.insertCategory(category);
    }

    final book = BookEntity(
      id: 0,
      title: title,
      author: author,
      path: filePath,
      format: format.toUpperCase(),
      coverPath: null,
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

  Future<int> addBookmark(int bookId, double position, String note) async {
    final positionObj = ReadingPosition(
      chapterIndex: position,
      charOffset: 0,
      selectedText: note,
    );
    return await databaseHelper.addBookmarkWithPosition(bookId, positionObj, note);
  }

  Future<List<Map<String, dynamic>>> getBookmarks(int bookId) async {
    return await databaseHelper.getBookmarksWithDetails(bookId);
  }

  Future<void> deleteBookmark(int bookmarkId) async {
    await databaseHelper.deleteBookmarkById(bookmarkId);
  }

  Future<int> addQuote(int bookId, double position, String quoteText, String? comment) async {
    final positionObj = ReadingPosition(
      chapterIndex: position,
      charOffset: 0,
      selectedText: quoteText,
    );
    return await databaseHelper.addQuoteWithPosition(bookId, positionObj, quoteText, comment);
  }

  Future<List<Map<String, dynamic>>> getQuotes(int bookId) async {
    return await databaseHelper.getQuotesWithDetails(bookId);
  }

  Future<void> deleteQuote(int quoteId) async {
    await databaseHelper.deleteQuoteById(quoteId);
  }
}