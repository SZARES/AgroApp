import 'package:flutter/material.dart';

import '../../../../domain/models/parcel.dart';
import '../../../core/widgets/field_map.dart';
import '../../../core/widgets/status_badge.dart';
import '../view_models/parcel_map_projection.dart';
import 'parcel_view.dart' show formatHectares, parcelStatusBadge;

/// Detail of one parcel: map, area, crop and status.
class ParcelDetailView extends StatelessWidget {
  const ParcelDetailView({super.key, required this.parcel});

  final Parcel parcel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final badge = parcelStatusBadge(context, parcel);
    final map = projectParcels([parcel]);

    return Scaffold(
      appBar: AppBar(title: Text(parcel.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Detalle del terreno', style: textTheme.titleLarge),
                ),
                StatusBadge(label: badge.label, color: badge.color),
              ],
            ),
            const SizedBox(height: 16),
            if (map.fields.isNotEmpty) ...[
              FieldMap(fields: map.fields, pins: map.pins),
              const SizedBox(height: 20),
            ] else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 36,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Este terreno aún no tiene ubicación en el mapa',
                          style: textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _DetailCard(
              icon: Icons.landscape_outlined,
              title: 'Nombre',
              value: parcel.name,
            ),
            const SizedBox(height: 12),
            _DetailCard(
              icon: Icons.straighten,
              title: 'Área',
              value: parcel.areaHectares == null
                  ? 'Sin área registrada'
                  : '${formatHectares(parcel.areaHectares!)} hectáreas',
            ),
            const SizedBox(height: 12),
            _DetailCard(
              icon: Icons.agriculture,
              title: 'Cultivo',
              value: parcel.cropName ?? 'Sin cultivo activo',
            ),
            const SizedBox(height: 12),
            _DetailCard(
              icon: Icons.report_problem_outlined,
              title: 'Problemas abiertos',
              value: parcel.openIncidents == 0
                  ? 'Ninguno'
                  : parcel.openIncidents == 1
                  ? '1 problema por atender'
                  : '${parcel.openIncidents} problemas por atender',
              highlight: parcel.openIncidents > 0,
            ),
            const SizedBox(height: 12),
            _DetailCard(
              icon: parcel.pendingSync
                  ? Icons.cloud_upload_outlined
                  : Icons.cloud_done_outlined,
              title: 'Sincronización',
              value: parcel.pendingSync
                  ? 'Guardado en el teléfono, por enviar'
                  : 'Guardado en el servidor',
            ),
            if (parcel.center != null) ...[
              const SizedBox(height: 12),
              _DetailCard(
                icon: Icons.place_outlined,
                title: 'Ubicación',
                value:
                    '${parcel.center!.latitude.toStringAsFixed(5)}, '
                    '${parcel.center!.longitude.toStringAsFixed(5)}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(value, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
