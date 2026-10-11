import 'package:flutter/material.dart';

import '../../../../domain/models/incident_status.dart';
import '../../../../domain/models/technician_case.dart';
import '../../../core/widgets/aider_shell.dart';
import '../../../core/widgets/field_map.dart';
import '../../../core/widgets/status_badge.dart';
import '../../incident_report/views/incident_status_labels.dart';
import '../../parcel/view_models/parcel_map_projection.dart';

const _urgentColor = Color(0xFFC62828);
const _warningColor = Color(0xFFF0701E);
const _doneColor = Color(0xFF2E7D32);

String priorityLabel(CasePriority priority) => switch (priority) {
  CasePriority.high => 'Urgente',
  CasePriority.medium => 'Prioridad media',
  CasePriority.low => 'Prioridad baja',
};

Color statusColor(BuildContext context, IncidentStatus status) =>
    switch (status) {
      IncidentStatus.reported => _urgentColor,
      IncidentStatus.underReview => _warningColor,
      IncidentStatus.visitScheduled => Theme.of(context).colorScheme.tertiary,
      IncidentStatus.attended => Theme.of(context).colorScheme.primary,
      IncidentStatus.closed => _doneColor,
    };

/// Status, urgency and pending-sync markers of a case.
class CaseChips extends StatelessWidget {
  const CaseChips({super.key, required this.item});

  final TechnicianCase item;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusBadge(
          label: incidentStatusName(item.status),
          color: statusColor(context, item.status),
        ),
        if (item.isOpen && item.priority == CasePriority.high)
          StatusBadge(
            label: priorityLabel(item.priority),
            color: _urgentColor,
          ),
        if (item.photoCount > 0)
          Tooltip(
            message: '${item.photoCount} fotos',
            child: Icon(
              Icons.photo_camera_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        if (item.isPending)
          Tooltip(
            message: 'Guardado en el dispositivo, por enviar',
            child: Icon(
              Icons.cloud_upload_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
      ],
    );
  }
}

/// Selectable cards of the alert inbox.
List<AiderListItem> caseListItems(List<TechnicianCase> cases) {
  return [
    for (final c in cases)
      AiderListItem(
        id: c.id,
        title: c.symptom,
        subtitle:
            '${c.farmerName} · ${c.parcelName}'
            '${c.cropName == null ? '' : ' · ${c.cropName}'}',
        searchText: incidentStatusName(c.status),
        footer: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: CaseChips(item: c),
        ),
      ),
  ];
}

/// Parcels with a pin per open case; tapping a pin opens that case.
class CasesMap extends StatelessWidget {
  const CasesMap({
    super.key,
    required this.data,
    required this.onOpenCase,
    this.height = 360,
  });

  final TechnicianMapData data;
  final ValueChanged<String> onOpenCase;
  final double height;

  @override
  Widget build(BuildContext context) {
    final projected = projectParcels(
      data.parcels,
      caseByParcel: data.caseByParcel,
    );
    if (projected.fields.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Todavía no hay parcelas con ubicación en su zona'),
        ),
      );
    }
    return FieldMap(
      fields: projected.fields,
      pins: projected.pins,
      onPinTap: onOpenCase,
      height: height,
    );
  }
}
