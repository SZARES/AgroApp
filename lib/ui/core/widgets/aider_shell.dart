import 'package:flutter/material.dart';

import 'empty_state.dart';

/// One entry of the console navigation.
@immutable
class AiderNavItem {
  const AiderNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.atBottom = false,
  });

  final String id;
  final String label;
  final IconData icon;

  /// Pinned to the bottom of the sidebar (alerts).
  final bool atBottom;
}

/// Narrow icon-only sidebar: modules on top, alerts and the user menu below.
class AiderSidebar extends StatelessWidget {
  const AiderSidebar({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    required this.userName,
    required this.onSignOut,
    this.alertCount = 0,
  });

  final List<AiderNavItem> items;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final String userName;
  final VoidCallback onSignOut;

  /// The alerts badge is hidden while this is 0.
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = items.where((item) => !item.atBottom);
    final bottom = items.where((item) => item.atBottom);

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Icon(Icons.eco, size: 32, color: scheme.primary),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  for (final item in top)
                    _NavButton(
                      item: item,
                      selected: item.id == selectedId,
                      onTap: () => onSelect(item.id),
                    ),
                ],
              ),
            ),
            for (final item in bottom)
              _NavButton(
                item: item,
                selected: item.id == selectedId,
                badgeCount: alertCount,
                onTap: () => onSelect(item.id),
              ),
            const SizedBox(height: 8),
            _UserMenu(userName: userName, onSignOut: onSignOut),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final AiderNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget icon = Icon(
      item.icon,
      size: 28,
      color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
    );
    if (badgeCount > 0) {
      icon = Badge(label: Text('$badgeCount'), child: icon);
    }
    return Tooltip(
      message: item.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({required this.userName, required this.onSignOut});

  final String userName;
  final VoidCallback onSignOut;

  static const _signOut = 'sign_out';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = userName.trim().isEmpty
        ? '?'
        : userName.trim()[0].toUpperCase();
    return PopupMenuButton<String>(
      tooltip: userName.isEmpty ? 'Mi cuenta' : userName,
      onSelected: (value) {
        if (value == _signOut) onSignOut();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _signOut,
          child: Row(
            children: [
              Icon(Icons.logout),
              SizedBox(width: 12),
              Text('Cerrar sesión'),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 22,
        backgroundColor: scheme.primaryContainer,
        child: Text(
          initial,
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

/// A selectable card of the list panel.
@immutable
class AiderListItem {
  const AiderListItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.leading,
    this.footer,
    this.searchText,
  });

  final String id;
  final String title;
  final String? subtitle;
  final Widget? leading;

  /// Shown under the subtitle (for example status chips).
  final Widget? footer;

  /// Extra text the list search also matches (email, DNI, ...).
  final String? searchText;
}

/// Middle panel: a search field above selectable cards.
class AiderListPanel extends StatefulWidget {
  const AiderListPanel({
    super.key,
    required this.title,
    required this.items,
    required this.selectedId,
    required this.onSelect,
    this.emptyMessage = 'Todavía no hay nada para mostrar.',
    this.header,
    this.body,
  });

  /// Controls above the search field (section switcher, filters).
  final Widget? header;

  /// Replaces the list (loading or error states); search stays visible.
  final Widget? body;

  final String title;
  final List<AiderListItem> items;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final String emptyMessage;

  @override
  State<AiderListPanel> createState() => _AiderListPanelState();
}

class _AiderListPanelState extends State<AiderListPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needle = _query.trim().toLowerCase();
    final visible = [
      for (final item in widget.items)
        if (needle.isEmpty ||
            item.title.toLowerCase().contains(needle) ||
            (item.subtitle?.toLowerCase().contains(needle) ?? false) ||
            (item.searchText?.toLowerCase().contains(needle) ?? false))
          item,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (widget.header != null) ...[
              widget.header!,
              const SizedBox(height: 12),
            ],
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Buscar',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.body != null
                  ? widget.body!
                  : visible.isEmpty
                  ? Center(
                      child: Text(
                        widget.items.isEmpty
                            ? widget.emptyMessage
                            : 'No se encontró nada con esa búsqueda.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        final selected = item.id == widget.selectedId;
                        return Card(
                          color: selected
                              ? theme.colorScheme.primaryContainer
                              : null,
                          child: ListTile(
                            leading: item.leading,
                            title: Text(item.title),
                            isThreeLine: item.footer != null,
                            subtitle:
                                item.subtitle == null && item.footer == null
                                ? null
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (item.subtitle != null)
                                        Text(item.subtitle!),
                                      if (item.footer != null) item.footer!,
                                    ],
                                  ),
                            selected: selected,
                            onTap: () => widget.onSelect(item.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large right-hand area with floating controls and an orange CTA slot.
class AiderMainArea extends StatelessWidget {
  const AiderMainArea({
    super.key,
    required this.child,
    this.floatingControls = const [],
    this.cta,
  });

  final Widget child;

  /// Small buttons floated at the top right (filters, layers, ...).
  final List<Widget> floatingControls;

  /// Bottom-right call to action; use [AiderCtaButton].
  final Widget? cta;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (floatingControls.isNotEmpty)
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final control in floatingControls) ...[
                  control,
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        if (cta != null) Positioned(right: 24, bottom: 24, child: cta!),
      ],
    );
  }
}

/// The orange call-to-action button of the main area.
class AiderCtaButton extends StatelessWidget {
  const AiderCtaButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size(0, 60)),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

/// Main-area placeholder for a module whose data is not wired yet.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({super.key, required this.item});

  final AiderNavItem item;

  static const message = 'Este módulo se activa en la siguiente etapa';

  @override
  Widget build(BuildContext context) {
    return EmptyState(icon: item.icon, title: item.label, message: message);
  }
}
