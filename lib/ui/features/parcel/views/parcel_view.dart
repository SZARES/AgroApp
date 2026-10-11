import 'package:flutter/material.dart';

import '../../../core/widgets/field_map.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../mock/mock_data.dart';
import '../../incident_report/views/case_status_view.dart';

class ParcelView extends StatelessWidget {
  const ParcelView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi parcela')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FieldMap(
              fields: mockMapFields,
              pins: mockMapPins,
              onAddField: () => ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Próximamente'))),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parcela total', style: textTheme.titleMedium),
                    Text(
                      '${mockTotalHectares.toStringAsFixed(1)} ha',
                      style: textTheme.headlineMedium,
                    ),
                    Text(
                      '${mockFields.length} campos',
                      style: textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Mis campos', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final field in mockFields) _FieldCard(field: field),
            const SizedBox(height: 24),
            Text('Mis reportes', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final caseItem in mockCases)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  title: Text(caseItem.problem, style: textTheme.titleMedium),
                  subtitle: Text(
                    '${caseItem.field} · ${caseItem.reportedAt}',
                    style: textTheme.bodyMedium,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 32),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CaseStatusView(caseItem: caseItem),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.field});

  final MockField field;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final style = _statusStyle(field.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(field.name, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Cultivo: ${field.crop} · ${field.hectares} ha',
                    style: textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusBadge(label: style.label, color: style.color),
          ],
        ),
      ),
    );
  }
}

({String label, Color color}) _statusStyle(FieldStatus status) {
  return switch (status) {
    FieldStatus.good => (label: 'Bien', color: const Color(0xFF8BD450)),
    FieldStatus.review => (label: 'Revisar', color: const Color(0xFFFFA040)),
    FieldStatus.pending => (label: 'Pendiente', color: const Color(0xFFB0BEC5)),
  };
}
