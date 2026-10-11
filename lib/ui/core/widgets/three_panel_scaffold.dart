import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Web console layout: narrow sidebar, list panel and a large main area.
///
/// Below [wideBreakpoint] the main area takes the full width and the sidebar
/// and list panel move into a drawer (opened from the app bar).
class ThreePanelScaffold extends StatelessWidget {
  const ThreePanelScaffold({
    super.key,
    required this.sidebar,
    required this.mainArea,
    this.listPanel,
    this.title,
    this.narrowActions = const [],
    this.scaffoldKey,
    this.listPanelWidth = 340,
    this.sidebarWidth = 72,
  });

  static const wideBreakpoint = 900.0;

  /// True when a layout this wide shows the three panels side by side.
  static bool isWide(double width) => width >= wideBreakpoint;

  /// Icon-only navigation; [sidebarWidth] wide.
  final Widget sidebar;

  /// Search and selectable cards; optional.
  final Widget? listPanel;

  final Widget mainArea;

  /// Shown in the app bar of the narrow layout.
  final Widget? title;
  final List<Widget> narrowActions;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final double listPanelWidth;
  final double sidebarWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelColor = Theme.of(context).colorScheme.surfaceContainerLow;
    if (isWide(width)) {
      return Scaffold(
        key: scaffoldKey,
        body: Row(
          children: [
            SizedBox(width: sidebarWidth, child: sidebar),
            if (listPanel != null)
              SizedBox(
                width: listPanelWidth,
                child: ColoredBox(color: panelColor, child: listPanel),
              ),
            Expanded(child: mainArea),
          ],
        ),
      );
    }
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(title: title, actions: narrowActions),
      drawer: Drawer(
        width: math.min(
          sidebarWidth + (listPanel == null ? 0 : listPanelWidth),
          width - 16,
        ),
        child: SafeArea(
          child: Row(
            children: [
              SizedBox(width: sidebarWidth, child: sidebar),
              if (listPanel != null)
                Expanded(
                  child: ColoredBox(color: panelColor, child: listPanel),
                ),
            ],
          ),
        ),
      ),
      body: mainArea,
    );
  }
}
