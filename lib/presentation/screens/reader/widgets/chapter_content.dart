import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../domain/entities/chapter.dart';
import '../../../../domain/entities/reading_settings.dart';

class ChapterContent extends StatefulWidget {
  final Chapter chapter;
  final ReadingSettings settings;
  final Function(double)? onScrollPositionChanged;

  const ChapterContent({
    super.key,
    required this.chapter,
    required this.settings,
    this.onScrollPositionChanged,
  });

  @override
  State<ChapterContent> createState() => _ChapterContentState();
}

class _ChapterContentState extends State<ChapterContent> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      final position = _scrollController.offset / _scrollController.position.maxScrollExtent;
      widget.onScrollPositionChanged?.call(position.clamp(0.0, 1.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.settings.backgroundColor,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: widget.settings.horizontalPadding,
          vertical: widget.settings.verticalPadding + MediaQuery.of(context).padding.top,
        ),
        child: Html(
          data: widget.chapter.content,
          style: {
            'body': Style(
              fontSize: FontSize(widget.settings.fontSize),
              lineHeight: LineHeight(widget.settings.lineHeight),
              color: widget.settings.textColor,
              fontFamily: widget.settings.fontFamily == 'System' ? null : widget.settings.fontFamily,
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
            ),
            'p': Style(
              margin: Margins.only(bottom: widget.settings.paragraphSpacing),
            ),
            'h1': Style(
              fontSize: FontSize(widget.settings.fontSize * 1.5),
              fontWeight: FontWeight.bold,
              margin: Margins.only(
                top: widget.settings.paragraphSpacing * 2,
                bottom: widget.settings.paragraphSpacing,
              ),
            ),
            'h2': Style(
              fontSize: FontSize(widget.settings.fontSize * 1.3),
              fontWeight: FontWeight.bold,
              margin: Margins.only(
                top: widget.settings.paragraphSpacing * 1.5,
                bottom: widget.settings.paragraphSpacing,
              ),
            ),
            'h3': Style(
              fontSize: FontSize(widget.settings.fontSize * 1.15),
              fontWeight: FontWeight.bold,
              margin: Margins.only(
                top: widget.settings.paragraphSpacing,
                bottom: widget.settings.paragraphSpacing * 0.5,
              ),
            ),
            'img': Style(
              width: Width(100, Unit.percent),
              margin: Margins.symmetric(vertical: widget.settings.paragraphSpacing),
            ),
            'a': Style(
              color: Theme.of(context).colorScheme.primary,
              textDecoration: TextDecoration.underline,
            ),
            'blockquote': Style(
              margin: Margins.symmetric(
                vertical: widget.settings.paragraphSpacing,
                horizontal: widget.settings.horizontalPadding,
              ),
              padding: HtmlPaddings.only(left: 16),
              border: Border(
                left: BorderSide(
                  color: widget.settings.textColor.withValues(alpha: 0.3),
                  width: 3,
                ),
              ),
              fontStyle: FontStyle.italic,
            ),
          },
        ),
      ),
    );
  }
}
