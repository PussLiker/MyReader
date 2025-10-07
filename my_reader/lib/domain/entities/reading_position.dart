class ReadingPosition {
  final int? id;
  final double chapterIndex;
  final int charOffset;
  final String? selectedText;
  final String? note;
  final String? comment;

  ReadingPosition({
    this.id,
    required this.chapterIndex,
    required this.charOffset,
    this.selectedText,
    this.note,
    this.comment,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'chapterIndex': chapterIndex,
    'charOffset': charOffset,
    'selectedText': selectedText,
    'note': note,
    'comment': comment,
  };

  factory ReadingPosition.fromJson(Map<String, dynamic> json) {
    return ReadingPosition(
      id: json['id'] as int?,
      chapterIndex: (json['chapterIndex'] as num).toDouble(),
      charOffset: json['charOffset'] as int,
      selectedText: json['selectedText'] as String?,
      note: json['note'] as String?,
      comment: json['comment'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ReadingPosition &&
              runtimeType == other.runtimeType &&
              chapterIndex == other.chapterIndex &&
              charOffset == other.charOffset;

  @override
  int get hashCode => chapterIndex.hashCode ^ charOffset.hashCode;
}