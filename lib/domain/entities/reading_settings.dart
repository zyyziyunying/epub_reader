import 'package:flutter/material.dart';

enum ReaderTheme { light, dark, sepia }

class ReadingSettings {
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final ReaderTheme theme;
  final double horizontalPadding;
  final double verticalPadding;
  final double paragraphSpacing;

  const ReadingSettings({
    this.fontSize = 18.0,
    this.lineHeight = 1.8,
    this.fontFamily = 'System',
    this.theme = ReaderTheme.light,
    this.horizontalPadding = 20.0,
    this.verticalPadding = 16.0,
    this.paragraphSpacing = 12.0,
  });

  ReadingSettings copyWith({
    double? fontSize,
    double? lineHeight,
    String? fontFamily,
    ReaderTheme? theme,
    double? horizontalPadding,
    double? verticalPadding,
    double? paragraphSpacing,
  }) {
    return ReadingSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      fontFamily: fontFamily ?? this.fontFamily,
      theme: theme ?? this.theme,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      verticalPadding: verticalPadding ?? this.verticalPadding,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
    );
  }

  Color get backgroundColor {
    switch (theme) {
      case ReaderTheme.light:
        return const Color(0xFFFFFBF5);
      case ReaderTheme.dark:
        return const Color(0xFF1A1A1A);
      case ReaderTheme.sepia:
        return const Color(0xFFF5E6D3);
    }
  }

  Color get textColor {
    switch (theme) {
      case ReaderTheme.light:
        return const Color(0xFF333333);
      case ReaderTheme.dark:
        return const Color(0xFFE0E0E0);
      case ReaderTheme.sepia:
        return const Color(0xFF5B4636);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'font_size': fontSize,
      'line_height': lineHeight,
      'font_family': fontFamily,
      'theme': theme.index,
      'horizontal_padding': horizontalPadding,
      'vertical_padding': verticalPadding,
      'paragraph_spacing': paragraphSpacing,
    };
  }

  factory ReadingSettings.fromMap(Map<String, dynamic> map) {
    return ReadingSettings(
      fontSize: map['font_size'] as double? ?? 18.0,
      lineHeight: map['line_height'] as double? ?? 1.8,
      fontFamily: map['font_family'] as String? ?? 'System',
      theme: ReaderTheme.values[map['theme'] as int? ?? 0],
      horizontalPadding: map['horizontal_padding'] as double? ?? 20.0,
      verticalPadding: map['vertical_padding'] as double? ?? 16.0,
      paragraphSpacing: map['paragraph_spacing'] as double? ?? 12.0,
    );
  }
}
