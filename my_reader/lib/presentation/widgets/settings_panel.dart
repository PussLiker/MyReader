import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../../app_colors.dart';
import '../providers/theme_provider.dart';

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
    // Получаем доступ к системе тем
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: colors.background, // Используем фон темы
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          Consumer(builder: (context, ref, _) {
            final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
            final colors = Theme.of(context).extension<AppColors>()!;

            return SwitchListTile(
              title:
                  Text("Темная тема", style: TextStyle(color: colors.mainText)),
              value: isDark,
              activeColor: colors.accent,
              onChanged: (val) {
                ref.read(themeModeProvider.notifier).state =
                    val ? ThemeMode.dark : ThemeMode.light;
              },
            );
          }),
          // Индикатор свайпа
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 20),
            decoration: BoxDecoration(
              color: colors.border, // Используем цвет границы для индикатора
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            "Настройки текста",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: colors.mainText, // Цвет текста из темы
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
            colors: colors,
            // Передаем объект цветов
            onChanged: (val) {
              setState(() =>
                  _localSettings = _localSettings.copyWith(fontSize: val));
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
            colors: colors,
            formatValue: (val) => val.toStringAsFixed(1),
            onChanged: (val) {
              setState(() =>
                  _localSettings = _localSettings.copyWith(lineHeight: val));
              widget.onSettingsChanged(_localSettings);
            },
          ),

          const SizedBox(height: 20),

          // Выбор шрифта
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: colors.cardBackground, // Фон контейнера выбора шрифта
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _localSettings.fontFamily,
                isExpanded: true,
                dropdownColor: colors.background,
                // Цвет выпадающего списка
                icon: Icon(Icons.arrow_drop_down, color: colors.secondaryText),
                style: TextStyle(color: colors.mainText, fontSize: 16),
                items: const [
                  DropdownMenuItem(
                      value: 'serif',
                      child: Text('С засечками',
                          style: TextStyle(fontFamily: 'serif'))),
                  DropdownMenuItem(
                      value: 'sans-serif',
                      child: Text('Без засечек',
                          style: TextStyle(fontFamily: 'sans-serif'))),
                  DropdownMenuItem(
                      value: 'monospace',
                      child: Text('Моноширинный',
                          style: TextStyle(fontFamily: 'monospace'))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _localSettings =
                        _localSettings.copyWith(fontFamily: val));
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
    required AppColors colors, // Добавили цвета
    int divisions = 18,
    String Function(double)? formatValue,
    required Function(double) onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: colors.secondaryText),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: colors.secondaryText, fontSize: 12)),
              Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                activeColor: colors.accent,
                // Акцентный цвет слайдера
                inactiveColor: colors.border,
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
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.mainText,
                fontSize: 14),
          ),
        ),
      ],
    );
  }
}
