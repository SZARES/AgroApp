import 'package:flutter/material.dart';

import '../../../core/widgets/primary_action_button.dart';
import '../../../mock/mock_data.dart';
import 'change_case_status_view.dart';
import 'record_assistance_view.dart';
import 'schedule_followup_view.dart';

class TechnicianCaseDetailView extends StatelessWidget {
  const TechnicianCaseDetailView({super.key, required this.caseItem});

  final MockTechnicianCase caseItem;

  void _open(BuildContext context, Widget view) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => view));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Caso ${caseItem.id}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(caseItem.problem, style: textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              '${caseItem.farmer} · ${caseItem.field}',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estado actual', style: textTheme.bodyLarge),
                    Text(
                      caseStatusLabels[caseItem.status]!,
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text('Foto del agricultor', style: textTheme.bodyLarge),
                    Text('Disponible', style: textTheme.titleMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryActionButton(
              label: 'Registrar asistencia',
              icon: Icons.assignment_outlined,
              onPressed: () => _open(context, const RecordAssistanceView()),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _open(context, const ScheduleFollowUpView()),
              icon: const Icon(Icons.event_outlined, size: 28),
              label: const Text('Programar seguimiento'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _open(
                context,
                ChangeCaseStatusView(current: caseItem.status),
              ),
              icon: const Icon(Icons.swap_horiz, size: 28),
              label: const Text('Cambiar estado'),
            ),
          ],
        ),
      ),
    );
  }
}
