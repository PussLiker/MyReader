class ReadingPosition {
  final int? id;
  final double chapterIndex;
  final double position;
  final int charOffset;
  final String? selectedText;
  final String? title;
  final String? note;
  final String? comment;
  final int? color;

  ReadingPosition({
    this.id,
    required this.chapterIndex,
    this.position = 0.0,
    required this.charOffset,
    this.selectedText,
    this.title,
    this.note,
    this.comment,
    this.color,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'chapter_index': chapterIndex,
        'position': position,
        'char_offset': charOffset,
        'selected_text': selectedText,
        'title': title,
        'note': note,
        'comment': comment,
        'color': color,
      };

  factory ReadingPosition.fromMap(Map<String, dynamic> map) {
    return ReadingPosition(
      id: map['id'] as int?,
      chapterIndex: (map['chapter_index'] as num? ?? 0).toDouble(),
      position: (map['position'] as num? ?? 0.0).toDouble(),
      charOffset: (map['char_offset'] as num? ?? 0).toInt(),
      selectedText: map['selected_text'] as String?,
      title: map['title'] as String?,
      note: map['note'] as String?,
      comment: map['comment'] as String?,
      color: map['color'] as int?,
    );
  }

  ReadingPosition copyWith({
    int? id,
    double? chapterIndex,
    double? position,
    int? charOffset,
    String? selectedText,
    String? title,
    String? note,
    String? comment,
    int? color,
  }) {
    return ReadingPosition(
      id: id ?? this.id,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      position: position ?? this.position,
      charOffset: charOffset ?? this.charOffset,
      selectedText: selectedText ?? this.selectedText,
      title: title ?? this.title,
      note: note ?? this.note,
      comment: comment ?? this.comment,
      color: color ?? this.color,
    );
  }
}
