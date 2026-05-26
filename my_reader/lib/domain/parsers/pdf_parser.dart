// lib/data/parsers/pdf_parser.dart
import 'package:pdfrx/pdfrx.dart';
import '../../domain/entities/chapter_entity.dart';

class PdfParser {
  Future<List<ChapterEntity>> parseChapters(String filePath) async {
    final chapters = <ChapterEntity>[];

    try {
      final document = await PdfDocument.openFile(filePath);
      final pageCount = document.pages.length;

      for (int i = 0; i < pageCount; i++) {
        chapters.add(ChapterEntity(
          title: 'Страница ${i + 1}',
          content: '',
          index: i,
        ));
      }

      return chapters;
    } catch (e) {
      print('PDF parsing error: $e');
      return [];
    }
  }
}
