import 'package:flutter/material.dart';

import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import '../../activity_log/views/activity_log_view.dart';
import '../../assistance/views/assistance_view.dart';
import '../../harvest/views/harvest_view.dart';
import '../../incident_report/views/incident_report_view.dart';
import '../view_models/home_view_model.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  void _open(BuildContext context, Widget view) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => view));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('AgroApp')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Hola', style: textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('¿Qué desea hacer hoy?', style: textTheme.titleMedium),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) => SyncStatusIndicator(
                summary: viewModel.summary,
                isSyncing: viewModel.isSyncing,
                onSyncNow: viewModel.syncNow,
              ),
            ),
            const SizedBox(height: 24),
            PrimaryActionButton(
              label: 'Registrar lo que hice',
              icon: Icons.edit_note,
              onPressed: () => _open(context, const ActivityLogView()),
            ),
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: 'Reportar un problema',
              icon: Icons.report_problem_outlined,
              onPressed: () => _open(context, const IncidentReportView()),
            ),
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: 'Registrar cosecha',
              icon: Icons.agriculture,
              onPressed: () => _open(context, const HarvestView()),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _open(context, const AssistanceView()),
              icon: const Icon(Icons.groups_outlined, size: 28),
              label: const Text('Mis asistencias'),
            ),
          ],
        ),
      ),
    );
  }
}
