import 'dart:io';
import 'package:epubx/epubx.dart' as epub;
import 'package:my_reader/data/db/database_helper.dart';
import 'package:my_reader/domain/entities/book_entity.dart';
import 'package:path/path.dart' as path;
import 'package:xml/xml.dart';
import '../../domain/entities/reading_position.dart';

class BookRepository {
  final DatabaseHelper databaseHelper;

  BookRepository(this.databaseHelper);

  Future<List<BookEntity>> getBooks([String? category]) async {
    final allBooks = await databaseHelper.getBooks();
    if (category == null || category.isEmpty) return allBooks;
    return allBooks.where((book) => book.category == category).toList();
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
        if (categoryOverride == null && metadata?.Subjects != null && metadata!.Subjects!.isNotEmpty) {
          category = metadata.Subjects!.first;
        }
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
      } catch (e) {
        print('Error reading FB2: $e');
      }
    } else if (format == 'txt') {
      category = 'Text';
    }

    final book = BookEntity(
      id: 0,
      title: title,
      author: author,
      path: filePath,
      format: format.toUpperCase(),
      coverPath: null,
      progress: 0,
      position: 0.0,
      category: category,
    );

    return await databaseHelper.insertBook(book);
  }

  Future<void> updateReadingStatus(int bookId, int chapterIndex, double positionPercent) async {
    await databaseHelper.updatePosition(bookId, chapterIndex, positionPercent);
  }

  Future<void> deleteBook(int bookId) async {
    await databaseHelper.deleteBook(bookId);
  }

  Future<List<String>> getCategories() async {
    return await databaseHelper.getCategories();
  }

  // ЗАКЛАДКИ
  Future<int> addBookmark(int bookId, ReadingPosition position, String note) async {
    return await databaseHelper.addBookmarkWithPosition(bookId, position, note);
  }

  Future<List<ReadingPosition>> getBookmarks(int bookId) async {
    return await databaseHelper.getBookmarksWithPosition(bookId);
  }

  Future<void> deleteBookmark(int bookmarkId) async {
    await databaseHelper.deleteBookmarkById(bookmarkId);
  }

  // ЦИТАТЫ
  Future<int> addQuote(int bookId, ReadingPosition position, String quoteText, String? comment) async {
    return await databaseHelper.addQuoteWithPosition(bookId, position, quoteText, comment);
  }

  Future<List<ReadingPosition>> getQuotes(int bookId) async {
    return await databaseHelper.getQuotesWithPosition(bookId);
  }

  Future<void> deleteQuote(int quoteId) async {
    await databaseHelper.deleteQuoteById(quoteId);
  }
}