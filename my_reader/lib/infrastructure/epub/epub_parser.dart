import 'dart:io';
import 'package:xml/xml.dart';

class EpubParser {
  Future<String> parseFb2Content(String filePath) async {
    final xmlString = await File(filePath).readAsString();
    final document = XmlDocument.parse(xmlString);
    final sections = document.findAllElements('section').toList();
    final paragraphs = sections.isNotEmpty
        ? sections.first.findAllElements('p').map((p) => p.text).join('\n\n')
        : 'Контент не найден';
    return paragraphs;
  }
}