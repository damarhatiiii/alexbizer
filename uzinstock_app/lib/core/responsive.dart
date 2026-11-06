import 'package:flutter/material.dart';

/// Breakpoints for responsive layout.
class Breakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  bool get isMobile => screenWidth < Breakpoints.mobile;
  bool get isTablet => screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.tablet;
  bool get isDesktop => screenWidth >= Breakpoints.tablet;
  bool get showBottomNav => isMobile;
  bool get showRail => !isMobile;
}
