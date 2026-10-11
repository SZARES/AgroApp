import 'package:flutter/material.dart';

import '../../../../../domain/models/admin/admin_user.dart';
import '../../view_models/users_view_model.dart';

/// Multi-select of the zones a technician or supervisor works in.
class UserZonesEditor extends StatefulWidget {
  const UserZonesEditor({
    super.key,
    required this.viewModel,
    required this.user,
  });

  final AdminUsersViewModel viewModel;
  final AdminUser user;

  @override
  State<UserZonesEditor> createState() => _UserZonesEditorState();
}

class _UserZonesEditorState extends State<UserZonesEditor> {
  late final Set<String> _selected = {...widget.user.zoneIds};

  @override
  Widget build(BuildContext context) {
    final zones = widget.viewModel.zones;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Zonas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (zones.isEmpty)
          const Text('Todavía no hay zonas creadas.')
        else
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < zones.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    dense: true,
                    value: _selected.contains('${zones[i]['id']}'),
                    title: Text(
                      '${zones[i]['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onChanged: (value) => setState(() {
                      value == true
                          ? _selected.add('${zones[i]['id']}')
                          : _selected.remove('${zones[i]['id']}');
                    }),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const ValueKey('save_zones'),
          onPressed: widget.viewModel.busy
              ? null
              : () =>
                    widget.viewModel.saveZones(widget.user, _selected.toList()),
          icon: widget.viewModel.busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 18),
          label: const Text('Guardar zonas'),
        ),
      ],
    );
  }
}

/// Parcels (from the technician's zones) assigned to a technician.
class TechnicianParcelsEditor extends StatefulWidget {
  const TechnicianParcelsEditor({
    super.key,
    required this.viewModel,
    required this.user,
  });

  final AdminUsersViewModel viewModel;
  final AdminUser user;

  @override
  State<TechnicianParcelsEditor> createState() =>
      _TechnicianParcelsEditorState();
}

class _TechnicianParcelsEditorState extends State<TechnicianParcelsEditor> {
  late final Set<String> _selected = {
    ...widget.viewModel.assignedParcelIds(widget.user.id),
  };

  @override
  Widget build(BuildContext context) {
    final parcels = widget.viewModel.assignableParcels(widget.user);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Parcelas asignadas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (widget.user.zoneIds.isEmpty)
          const Text('Asigne primero una zona para ver sus parcelas.')
        else if (parcels.isEmpty)
          const Text('Todavía no hay parcelas en las zonas de esta persona.')
        else
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < parcels.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    dense: true,
                    value: _selected.contains('${parcels[i]['id']}'),
                    title: Text(
                      '${parcels[i]['name'] ?? 'Parcela'}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onChanged: (value) => setState(() {
                      value == true
                          ? _selected.add('${parcels[i]['id']}')
                          : _selected.remove('${parcels[i]['id']}');
                    }),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const ValueKey('save_parcels'),
          onPressed: widget.viewModel.busy || parcels.isEmpty
              ? null
              : () => widget.viewModel.saveParcels(
                  widget.user,
                  _selected.toList(),
                ),
          icon: widget.viewModel.busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check, size: 18),
          label: const Text('Guardar parcelas'),
        ),
      ],
    );
  }
}
