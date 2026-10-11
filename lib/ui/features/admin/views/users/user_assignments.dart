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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Zonas', style: Theme.of(context).textTheme.titleMedium),
        if (zones.isEmpty) const Text('Todavía no hay zonas creadas.'),
        for (final zone in zones)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _selected.contains('${zone['id']}'),
            title: Text('${zone['name']}'),
            onChanged: (value) => setState(() {
              value == true
                  ? _selected.add('${zone['id']}')
                  : _selected.remove('${zone['id']}');
            }),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('save_zones'),
          onPressed: widget.viewModel.busy
              ? null
              : () =>
                    widget.viewModel.saveZones(widget.user, _selected.toList()),
          child: const Text('Guardar zonas'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Parcelas asignadas',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (widget.user.zoneIds.isEmpty)
          const Text('Asigne primero una zona para ver sus parcelas.')
        else if (parcels.isEmpty)
          const Text('Todavía no hay parcelas en las zonas de esta persona.'),
        for (final parcel in parcels)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _selected.contains('${parcel['id']}'),
            title: Text('${parcel['name'] ?? 'Parcela'}'),
            onChanged: (value) => setState(() {
              value == true
                  ? _selected.add('${parcel['id']}')
                  : _selected.remove('${parcel['id']}');
            }),
          ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('save_parcels'),
          onPressed: widget.viewModel.busy || parcels.isEmpty
              ? null
              : () => widget.viewModel.saveParcels(
                  widget.user,
                  _selected.toList(),
                ),
          child: const Text('Guardar parcelas'),
        ),
      ],
    );
  }
}
