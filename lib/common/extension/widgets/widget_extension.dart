import 'package:flutter/material.dart';

extension WidgetExtension on Widget {
  /// Apply padding on all sides
  Padding paddingAll(double value) {
    return Padding(padding: EdgeInsets.all(value), child: this);
  }

  /// Apply symmetric padding (horizontal and vertical)
  Padding paddingSymmetric({double horizontal = 0.0, double vertical = 0.0}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      child: this,
    );
  }

  /// Apply padding only on specific sides
  Padding paddingOnly({
    double left = 0.0,
    double top = 0.0,
    double right = 0.0,
    double bottom = 0.0,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      ),
      child: this,
    );
  }

  /// Apply padding from EdgeInsets
  Padding padding(EdgeInsetsGeometry value) {
    return Padding(padding: value, child: this);
  }

  /// Apply horizontal padding
  Padding paddingHorizontal(double value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: value),
      child: this,
    );
  }

  /// Apply vertical padding
  Padding paddingVertical(double value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: value),
      child: this,
    );
  }

  /// Apply padding on left side
  Padding paddingLeft(double value) {
    return Padding(
      padding: EdgeInsets.only(left: value),
      child: this,
    );
  }

  /// Apply padding on top side
  Padding paddingTop(double value) {
    return Padding(
      padding: EdgeInsets.only(top: value),
      child: this,
    );
  }

  /// Apply padding on right side
  Padding paddingRight(double value) {
    return Padding(
      padding: EdgeInsets.only(right: value),
      child: this,
    );
  }

  /// Apply padding on bottom side
  Padding paddingBottom(double value) {
    return Padding(
      padding: EdgeInsets.only(bottom: value),
      child: this,
    );
  }

  /// Center the widget
  Center center() {
    return Center(child: this);
  }

  /// Align the widget
  Align align(Alignment alignment) {
    return Align(alignment: alignment, child: this);
  }

  /// Align to top left
  Align alignTopLeft() {
    return Align(alignment: Alignment.topLeft, child: this);
  }

  /// Align to top center
  Align alignTopCenter() {
    return Align(alignment: Alignment.topCenter, child: this);
  }

  /// Align to top right
  Align alignTopRight() {
    return Align(alignment: Alignment.topRight, child: this);
  }

  /// Align to center left
  Align alignCenterLeft() {
    return Align(alignment: Alignment.centerLeft, child: this);
  }

  /// Align to center right
  Align alignCenterRight() {
    return Align(alignment: Alignment.centerRight, child: this);
  }

  /// Align to bottom left
  Align alignBottomLeft() {
    return Align(alignment: Alignment.bottomLeft, child: this);
  }

  /// Align to bottom center
  Align alignBottomCenter() {
    return Align(alignment: Alignment.bottomCenter, child: this);
  }

  /// Align to bottom right
  Align alignBottomRight() {
    return Align(alignment: Alignment.bottomRight, child: this);
  }

  /// Wrap with Expanded
  Expanded expanded({int flex = 1}) {
    return Expanded(flex: flex, child: this);
  }

  /// Wrap with Flexible
  Flexible flexible({int flex = 1, FlexFit fit = FlexFit.loose}) {
    return Flexible(flex: flex, fit: fit, child: this);
  }

  /// Wrap with SizedBox with specific width and height
  SizedBox sizedBox({double? width, double? height}) {
    return SizedBox(width: width, height: height, child: this);
  }

  /// Wrap with SizedBox with square size
  SizedBox sizedSquare(double size) {
    return SizedBox(width: size, height: size, child: this);
  }

  /// Wrap with SizedBox with specific width
  SizedBox width(double width) {
    return SizedBox(width: width, child: this);
  }

  /// Wrap with SizedBox with specific height
  SizedBox height(double height) {
    return SizedBox(height: height, child: this);
  }

  /// Wrap with FittedBox
  FittedBox fitted({BoxFit fit = BoxFit.contain}) {
    return FittedBox(fit: fit, child: this);
  }

  /// Wrap with AspectRatio
  AspectRatio aspectRatio(double ratio) {
    return AspectRatio(aspectRatio: ratio, child: this);
  }

  /// Wrap with Opacity
  Opacity opacity(double opacity) {
    return Opacity(opacity: opacity, child: this);
  }

  /// Wrap with Visibility
  Visibility visible(bool visible, {Widget? replacement}) {
    return Visibility(
      visible: visible,
      replacement: replacement ?? const SizedBox.shrink(),
      child: this,
    );
  }

  /// Wrap with ClipRRect for rounded corners
  ClipRRect clipRRect({double radius = 8.0}) {
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: this);
  }

  /// Wrap with ClipRRect with custom border radius
  ClipRRect clipRRectCustom(BorderRadius borderRadius) {
    return ClipRRect(borderRadius: borderRadius, child: this);
  }

  /// Wrap with ClipOval
  ClipOval clipOval() {
    return ClipOval(child: this);
  }

  /// Wrap with GestureDetector for tap
  GestureDetector onTap(VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: this);
  }

  /// Wrap with InkWell for material tap effect
  InkWell inkWell({
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    BorderRadius? borderRadius,
  }) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius,
      child: this,
    );
  }

  /// Wrap with Hero for animations
  Hero hero(String tag) {
    return Hero(tag: tag, child: this);
  }

  /// Wrap with Card
  Card card({Color? color, double? elevation, EdgeInsetsGeometry? margin}) {
    return Card(
      color: color,
      elevation: elevation,
      margin: margin,
      child: this,
    );
  }

  /// Wrap with Container
  Container container({
    Color? color,
    double? width,
    double? height,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Decoration? decoration,
    AlignmentGeometry? alignment,
  }) {
    return Container(
      color: color,
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: decoration,
      alignment: alignment,
      child: this,
    );
  }

  /// Wrap with DecoratedBox
  DecoratedBox decorated(Decoration decoration) {
    return DecoratedBox(decoration: decoration, child: this);
  }

  /// Wrap with Transform.rotate
  Transform rotate(double angle) {
    return Transform.rotate(angle: angle, child: this);
  }

  /// Wrap with Transform.scale
  Transform scale(double scale) {
    return Transform.scale(scale: scale, child: this);
  }

  /// Wrap with Transform.translate
  Transform translate({double x = 0.0, double y = 0.0}) {
    return Transform.translate(offset: Offset(x, y), child: this);
  }

  /// Wrap with SafeArea
  SafeArea safeArea({
    bool top = true,
    bool bottom = true,
    bool left = true,
    bool right = true,
  }) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: this,
    );
  }

  /// Wrap with SingleChildScrollView
  SingleChildScrollView scrollable({
    Axis scrollDirection = Axis.vertical,
    EdgeInsetsGeometry? padding,
  }) {
    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      padding: padding,
      child: this,
    );
  }
}
