class ReaderSettings {
  final double fontSize;
  final String fontFamily;
  final double lineHeight;

  const ReaderSettings({
    this.fontSize = 18.0,
    this.fontFamily = 'Georgia',
    this.lineHeight = 1.6,
  });

  // Метод для удобного копирования настроек (нужен для Riverpod/State)
  ReaderSettings copyWith({
    double? fontSize,
    String? fontFamily,
    double? lineHeight,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      lineHeight: lineHeight ?? this.lineHeight,
    );
  }
}