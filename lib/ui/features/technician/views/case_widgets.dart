import 'package:flutter/material.dart';

import '../../../../domain/models/incident_status.dart';
import '../../../../domain/models/technician_case.dart';
import '../../../core/widgets/aider_shell.dart';
import '../../../core/widgets/field_map.dart';
import '../../../core/widgets/status_badge.dart';
import '../../incident_report/views/incident_status_labels.dart';
import '../../parcel/view_models/parcel_map_projection.dart';
import '../view_models/technician_cases_view_model.dart';

const _urgentColor = Color(0xFFC62828);
const _warningColor = Color(0xFFF0701E);
const _doneColor = Color(0xFF2E7D32);

/// Plain-language message for a failed technician action.
String technicianFailureText(Object error) {
  if (error is TechnicianException) {
    return switch (error.failure) {
      TechnicianFailure.notFound => 'No encontramos este caso',
      TechnicianFailure.farmerNotFound =>
        'No encontramos a este agricultor o su parcela',
      TechnicianFailure.invalidTransition =>
        'Este caso ya no admite ese cambio',
      TechnicianFailure.noCategory =>
        'Faltan los tipos de asistencia. Conéctese una vez para cargarlos',
      TechnicianFailure.emptyText => 'Escriba el texto antes de guardar',
    };
  }
  return 'No pudimos guardar. Intente otra vez';
}

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
          StatusBadge(label: priorityLabel(item.priority), color: _urgentColor),
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

/// Chips that filter the alert list; each shows how many cases it holds.
class CaseFilterBar extends StatelessWidget {
  const CaseFilterBar({super.key, required this.viewModel});

  final TechnicianCasesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    // One scrollable line: chips never wrap into ragged rows in the narrow
    // list panel, and no checkmark so selecting does not shift their widths.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in CaseFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                showCheckmark: false,
                label: Text('${filter.label} (${viewModel.countFor(filter)})'),
                selected: viewModel.filter == filter,
                onSelected: (_) => viewModel.setFilter(filter),
              ),
            ),
        ],
      ),
    );
  }
}

/// Message of an empty alert list, aware of the active filter.
String emptyCasesMessage(CaseFilter filter) => filter == CaseFilter.all
    ? 'No hay casos en su zona por ahora.'
    : 'No hay casos con este filtro.';

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
