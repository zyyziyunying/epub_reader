import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../domain/entities/reader_document.dart';
import '../../../../domain/entities/reading_settings.dart';

class ReaderDocumentContent extends StatelessWidget {
  const ReaderDocumentContent({
    super.key,
    required this.document,
    required this.settings,
    required this.showDivider,
  });

  final ReaderDocument document;
  final ReadingSettings settings;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: settings.backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: settings.horizontalPadding,
        vertical: settings.verticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 16),
            child: Text(
              document.title,
              style: TextStyle(
                fontSize: settings.fontSize * 1.3,
                fontWeight: FontWeight.bold,
                color: settings.textColor,
                fontFamily: settings.fontFamily == 'System'
                    ? null
                    : settings.fontFamily,
              ),
            ),
          ),
          Html(
            data: document.htmlContent,
            style: {
              'body': Style(
                fontSize: FontSize(settings.fontSize),
                lineHeight: LineHeight(settings.lineHeight),
                color: settings.textColor,
                fontFamily: settings.fontFamily == 'System'
                    ? null
                    : settings.fontFamily,
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
              'p': Style(
                margin: Margins.only(bottom: settings.paragraphSpacing),
              ),
              'h1': Style(
                fontSize: FontSize(settings.fontSize * 1.5),
                fontWeight: FontWeight.bold,
                margin: Margins.only(
                  top: settings.paragraphSpacing * 2,
                  bottom: settings.paragraphSpacing,
                ),
              ),
              'h2': Style(
                fontSize: FontSize(settings.fontSize * 1.3),
                fontWeight: FontWeight.bold,
                margin: Margins.only(
                  top: settings.paragraphSpacing * 1.5,
                  bottom: settings.paragraphSpacing,
                ),
              ),
              'h3': Style(
                fontSize: FontSize(settings.fontSize * 1.15),
                fontWeight: FontWeight.bold,
                margin: Margins.only(
                  top: settings.paragraphSpacing,
                  bottom: settings.paragraphSpacing * 0.5,
                ),
              ),
              'img': Style(
                width: Width(100, Unit.percent),
                margin: Margins.symmetric(vertical: settings.paragraphSpacing),
              ),
              'a': Style(
                color: Theme.of(context).colorScheme.primary,
                textDecoration: TextDecoration.underline,
              ),
              'blockquote': Style(
                margin: Margins.symmetric(
                  vertical: settings.paragraphSpacing,
                  horizontal: settings.horizontalPadding,
                ),
                padding: HtmlPaddings.only(left: 16),
                border: Border(
                  left: BorderSide(
                    color: settings.textColor.withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
                fontStyle: FontStyle.italic,
              ),
            },
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Divider(
                color: settings.textColor.withValues(alpha: 0.2),
                thickness: 1,
              ),
            ),
        ],
      ),
    );
  }
}
