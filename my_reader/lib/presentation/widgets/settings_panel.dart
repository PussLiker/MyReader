import 'package:flutter/material.dart';
import '../../../domain/entities/reader_settings.dart';

class SettingsPanel extends StatefulWidget {
  final ReaderSettings settings;
  final Function(ReaderSettings) onSettingsChanged;

  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  // Локальное состояние для плавной работы UI
  late ReaderSettings _localSettings;

  @override
  void initState() {
    super.initState();
    _localSettings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    // Чтобы панель не перекрывалась навигацией, добавим отступ снизу (Safe Area)
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFEDE7D9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 20),
            decoration: BoxDecoration(
              color: Colors.brown.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text("Настройки текста",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4E342E))
          ),
          const SizedBox(height: 20),

          // 1. Управление размером шрифта
          Row(
            children: [
              const Icon(Icons.text_fields, size: 20, color: Color(0xFF7B5E57)),
              Expanded(
                child: Slider(
                  value: _localSettings.fontSize,
                  min: 14,
                  max: 32,
                  divisions: 18,
                  activeColor: const Color(0xFF7B5E57),
                  inactiveColor: const Color(0xFFD7CCC8),
                  onChanged: (val) {
                    setState(() => _localSettings = _localSettings.copyWith(fontSize: val));
                    widget.onSettingsChanged(_localSettings);
                  },
                ),
              ),
              Text("${_localSettings.fontSize.toInt()}",
                  style: const TextStyle(fontWeight: FontWeight.bold)
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 2. Выбор шрифта (с исправлением названия и набором шрифтов)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBCAAA4)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                // ПРОВЕРКА: Если текущий шрифт не входит в список, выбираем 'serif' по умолчанию
                value: ['serif', 'sans-serif', 'monospace'].contains(_localSettings.fontFamily)
                    ? _localSettings.fontFamily
                    : 'serif',
                isExpanded: true,
                dropdownColor: const Color(0xFFEDE7D9),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7B5E57)),
                items: const [
                  DropdownMenuItem(
                    value: 'serif',
                    child: Text('С засечками (Книжный)', style: TextStyle(fontFamily: 'serif')),
                  ),
                  DropdownMenuItem(
                    value: 'sans-serif',
                    child: Text('Без засечек (Современный)', style: TextStyle(fontFamily: 'sans-serif')),
                  ),
                  DropdownMenuItem(
                    value: 'monospace',
                    child: Text('Моноширинный (Код)', style: TextStyle(fontFamily: 'monospace')),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _localSettings = _localSettings.copyWith(fontFamily: val));
                    widget.onSettingsChanged(_localSettings);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}