class ReadingPosition {
  final int? id;
  final double chapterIndex; // Номер главы
  final double position;     // Процент скролла (0.0 - 1.0)
  final int charOffset;
  final String? selectedText;
  final String? note;
  final String? comment;

  ReadingPosition({
    this.id,
    required this.chapterIndex,
    this.position = 0.0, // Значение по умолчанию
    required this.charOffset,
    this.selectedText,
    this.note,
    this.comment,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'chapterIndex': chapterIndex,
    'position': position,
    'charOffset': charOffset,
    'selectedText': selectedText,
    'note': note,
    'comment': comment,
  };

  factory ReadingPosition.fromMap(Map<String, dynamic> map) {
    return ReadingPosition(
      id: map['id'] as int?,
      // Используем num и проверяем на null перед toDouble
      chapterIndex: (map['chapter_index'] as num? ?? 0).toDouble(),
      position: (map['position'] as num? ?? 0.0).toDouble(),
      charOffset: (map['char_offset'] as num? ?? 0).toInt(),
      selectedText: map['selected_text'] as String?,
      note: map['note'] as String?,
      comment: map['comment'] as String?,
    );
  }

  // Обновим сравнение, чтобы оно учитывало и позицию
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ReadingPosition &&
              runtimeType == other.runtimeType &&
              chapterIndex == other.chapterIndex &&
              position == other.position &&
              charOffset == other.charOffset;

  @override
  int get hashCode => chapterIndex.hashCode ^ position.hashCode ^ charOffset.hashCode;
}