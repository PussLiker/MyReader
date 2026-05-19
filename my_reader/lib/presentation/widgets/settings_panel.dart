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
  late ReaderSettings _localSettings;

  @override
  void initState() {
    super.initState();
    _localSettings = widget.settings;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFEDE7D9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Индикатор свайпа
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 20),
            decoration: BoxDecoration(
              color: const Color(0xFFBCAAA4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            "Настройки текста",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Color(0xFF4E342E),
            ),
          ),
          const SizedBox(height: 20),

          // Размер шрифта
          _buildSliderRow(
            icon: Icons.text_fields,
            label: 'Размер шрифта',
            value: _localSettings.fontSize,
            min: 14,
            max: 32,
            onChanged: (val) {
              setState(() => _localSettings = _localSettings.copyWith(fontSize: val));
              widget.onSettingsChanged(_localSettings);
            },
          ),

          const SizedBox(height: 20),

          // Высота строки
          _buildSliderRow(
            icon: Icons.format_line_spacing,
            label: 'Высота строки',
            value: _localSettings.lineHeight,
            min: 1.0,
            max: 1.8,
            divisions: 12,
            formatValue: (val) => val.toStringAsFixed(1),
            onChanged: (val) {
              setState(() => _localSettings = _localSettings.copyWith(lineHeight: val));
              widget.onSettingsChanged(_localSettings);
            },
          ),

          const SizedBox(height: 20),

          // Выбор шрифта
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F1EB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD7CCC8)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _localSettings.fontFamily,
                isExpanded: true,
                dropdownColor: const Color(0xFFEDE7D9),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF7B5E57)),
                style: const TextStyle(color: Color(0xFF4E342E), fontSize: 16),
                items: const [
                  DropdownMenuItem(
                    value: 'serif',
                    child: Text('С засечками', style: TextStyle(fontFamily: 'serif')),
                  ),
                  DropdownMenuItem(
                    value: 'sans-serif',
                    child: Text('Без засечек', style: TextStyle(fontFamily: 'sans-serif')),
                  ),
                  DropdownMenuItem(
                    value: 'monospace',
                    child: Text('Моноширинный', style: TextStyle(fontFamily: 'monospace')),
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

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    int divisions = 18,
    String Function(double)? formatValue,
    required Function(double) onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: const Color(0xFF7B5E57)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6D4C41),
                  fontSize: 12,
                ),
              ),
              Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                activeColor: const Color(0xFF7B5E57),
                inactiveColor: const Color(0xFFD7CCC8),
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            formatValue != null ? formatValue(value) : '${value.toInt()}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF4E342E),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}