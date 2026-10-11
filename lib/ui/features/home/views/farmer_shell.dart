import 'package:flutter/material.dart';

/// Farmer phone shell: tab body + floating bottom bar with a raised report FAB.
class FarmerShell extends StatefulWidget {
  const FarmerShell({
    super.key,
    required this.home,
    required this.activities,
    required this.reports,
    required this.assistances,
    required this.reportBuilder,
    this.onSignOut,
  });

  final Widget home;
  final Widget activities;
  final Widget reports;
  final Widget assistances;

  /// Opens the "Reportar problema" flow (push); does not switch tabs.
  final WidgetBuilder reportBuilder;

  final VoidCallback? onSignOut;

  @override
  State<FarmerShell> createState() => _FarmerShellState();
}

class _FarmerShellState extends State<FarmerShell> {
  int _index = 0;

  static const _barHeight = 72.0;
  static const _fabSize = 64.0;

  void _openReport() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: widget.reportBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: _barHeight + _fabSize * 0.45 + bottomInset + 12,
              ),
              child: IndexedStack(
                index: _index,
                children: [
                  widget.home,
                  widget.activities,
                  widget.reports,
                  widget.assistances,
                ],
              ),
            ),
          ),
          if (widget.onSignOut != null)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: IconButton(
                  onPressed: widget.onSignOut,
                  tooltip: 'Cerrar sesión',
                  constraints: const BoxConstraints(
                    minWidth: 56,
                    minHeight: 56,
                  ),
                  icon: const Icon(
                    Icons.logout,
                    semanticLabel: 'Cerrar sesión',
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomInset + 8,
            child: _FarmerBottomBar(
              selectedIndex: _index,
              onSelect: (i) => setState(() => _index = i),
              onReport: _openReport,
              barHeight: _barHeight,
              fabSize: _fabSize,
              background: scheme.surfaceContainerHigh,
              activeColor: scheme.primary,
              inactiveColor: scheme.onSurfaceVariant,
              fabColor: scheme.secondary,
              fabForeground: scheme.onSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmerBottomBar extends StatelessWidget {
  const _FarmerBottomBar({
    required this.selectedIndex,
    required this.onSelect,
    required this.onReport,
    required this.barHeight,
    required this.fabSize,
    required this.background,
    required this.activeColor,
    required this.inactiveColor,
    required this.fabColor,
    required this.fabForeground,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onReport;
  final double barHeight;
  final double fabSize;
  final Color background;
  final Color activeColor;
  final Color inactiveColor;
  final Color fabColor;
  final Color fabForeground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: barHeight + fabSize * 0.45,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: background,
              elevation: 8,
              shadowColor: const Color(0x66000000),
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                height: barHeight,
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: 'Inicio',
                      selected: selectedIndex == 0,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      onTap: () => onSelect(0),
                    ),
                    _NavItem(
                      icon: Icons.edit_note_outlined,
                      selectedIcon: Icons.edit_note,
                      label: 'Actividades',
                      selected: selectedIndex == 1,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      onTap: () => onSelect(1),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: onReport,
                        borderRadius: BorderRadius.circular(16),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Reportar',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: fabColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.fact_check_outlined,
                      selectedIcon: Icons.fact_check,
                      label: 'Reportes',
                      selected: selectedIndex == 2,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      onTap: () => onSelect(2),
                    ),
                    _NavItem(
                      icon: Icons.groups_outlined,
                      selectedIcon: Icons.groups,
                      label: 'Asistencias',
                      selected: selectedIndex == 3,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      onTap: () => onSelect(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            child: Semantics(
              button: true,
              label: 'Reportar problema',
              child: Tooltip(
                message: 'Reportar problema',
                child: Material(
                  color: fabColor,
                  elevation: 6,
                  shadowColor: const Color(0x66000000),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onReport,
                    child: SizedBox(
                      width: fabSize,
                      height: fabSize,
                      child: Icon(
                        Icons.report_problem,
                        color: fabForeground,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? activeColor : inactiveColor;
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      fontSize: 12,
    );

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 26),
            const SizedBox(height: 2),
            Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
