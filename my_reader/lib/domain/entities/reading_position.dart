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

  ReadingPosition copyWith({
    int? id,
    double? chapterIndex,
    double? position,
    int? charOffset,
    String? selectedText,
    String? note,
    String? comment,
  }) {
    return ReadingPosition(
      id: id ?? this.id,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      position: position ?? this.position,
      charOffset: charOffset ?? this.charOffset,
      selectedText: selectedText ?? this.selectedText,
      note: note ?? this.note,
      comment: comment ?? this.comment, // Сюда прилетит обновленная заметка
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ReadingPosition &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              chapterIndex == other.chapterIndex &&
              position == other.position &&
              charOffset == other.charOffset &&
              comment == other.comment;

  @override
  int get hashCode =>
      id.hashCode ^
      chapterIndex.hashCode ^
      position.hashCode ^
      charOffset.hashCode ^
      comment.hashCode;
 }