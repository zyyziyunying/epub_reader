import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/reading_settings.dart';
import '../../../providers/book_providers.dart';

class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readingSettingsProvider);
    final notifier = ref.read(readingSettingsProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Reading Settings',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              // 字体大小
              _buildSettingRow(
                context,
                icon: Icons.text_fields,
                label: 'Font Size',
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: settings.fontSize > 12
                          ? () => notifier.setFontSize(settings.fontSize - 2)
                          : null,
                    ),
                    Text(
                      '${settings.fontSize.toInt()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: settings.fontSize < 32
                          ? () => notifier.setFontSize(settings.fontSize + 2)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 行间距
              _buildSettingRow(
                context,
                icon: Icons.format_line_spacing,
                label: 'Line Height',
                child: Expanded(
                  child: Slider(
                    value: settings.lineHeight,
                    min: 1.2,
                    max: 2.5,
                    divisions: 13,
                    label: settings.lineHeight.toStringAsFixed(1),
                    onChanged: (value) => notifier.setLineHeight(value),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 主题选择
              _buildSettingRow(
                context,
                icon: Icons.palette,
                label: 'Theme',
                child: Row(
                  children: [
                    _buildThemeButton(
                      context,
                      theme: ReaderTheme.light,
                      isSelected: settings.theme == ReaderTheme.light,
                      color: const Color(0xFFFFFBF5),
                      label: 'Light',
                      onTap: () => notifier.setTheme(ReaderTheme.light),
                    ),
                    const SizedBox(width: 8),
                    _buildThemeButton(
                      context,
                      theme: ReaderTheme.sepia,
                      isSelected: settings.theme == ReaderTheme.sepia,
                      color: const Color(0xFFF5E6D3),
                      label: 'Sepia',
                      onTap: () => notifier.setTheme(ReaderTheme.sepia),
                    ),
                    const SizedBox(width: 8),
                    _buildThemeButton(
                      context,
                      theme: ReaderTheme.dark,
                      isSelected: settings.theme == ReaderTheme.dark,
                      color: const Color(0xFF1A1A1A),
                      label: 'Dark',
                      onTap: () => notifier.setTheme(ReaderTheme.dark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 边距
              _buildSettingRow(
                context,
                icon: Icons.format_indent_increase,
                label: 'Margins',
                child: Expanded(
                  child: Slider(
                    value: settings.horizontalPadding,
                    min: 8,
                    max: 48,
                    divisions: 10,
                    label: '${settings.horizontalPadding.toInt()}',
                    onChanged: (value) => notifier.setHorizontalPadding(value),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        child,
      ],
    );
  }

  Widget _buildThemeButton(
    BuildContext context, {
    required ReaderTheme theme,
    required bool isSelected,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: theme == ReaderTheme.dark ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
