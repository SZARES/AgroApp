import 'package:flutter/material.dart';

import '../../../core/widgets/status_badge.dart';
import '../../../mock/mock_data.dart';
import 'technician_case_detail_view.dart';

/// Technician landing screen: the list of incidents to attend.
class TechnicianHomeView extends StatelessWidget {
  const TechnicianHomeView({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incidencias'),
        actions: [
          IconButton(
            onPressed: onSignOut,
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Casos por atender', style: textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final caseItem in mockTechnicianCases)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  isThreeLine: true,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          caseItem.problem,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      if (caseItem.urgent)
                        const StatusBadge(
                          label: 'Urgente',
                          color: Color(0xFFC62828),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${caseItem.farmer} · ${caseItem.field}\n'
                    '${caseStatusLabels[caseItem.status]}',
                    style: textTheme.bodyLarge,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 32),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          TechnicianCaseDetailView(caseItem: caseItem),
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
