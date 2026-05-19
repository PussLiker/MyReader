import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/reader_settings.dart';

class SettingsService {
  static const String _fontSizeKey = 'global_font_size';
  static const String _fontFamilyKey = 'global_font_family';
  static const String _lineHeightKey = 'global_line_height';

  Future<ReaderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return ReaderSettings(
      fontSize: prefs.getDouble(_fontSizeKey) ?? 18.0,
      fontFamily: prefs.getString(_fontFamilyKey) ?? 'serif',
      lineHeight: prefs.getDouble(_lineHeightKey) ?? 1.4,
    );
  }

  Future<void> saveSettings(ReaderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, settings.fontSize);
    await prefs.setString(_fontFamilyKey, settings.fontFamily);
    await prefs.setDouble(_lineHeightKey, settings.lineHeight);
  }
}