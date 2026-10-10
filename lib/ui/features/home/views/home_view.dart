import 'package:flutter/material.dart';

import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/sync_status_indicator.dart';
import '../../../mock/mock_data.dart';
import '../../activity_log/views/activity_log_view.dart';
import '../../assistance/views/assistance_view.dart';
import '../../harvest/views/harvest_view.dart';
import '../../incident_report/views/incident_report_view.dart';
import '../../parcel/views/parcel_view.dart';
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Hola, $mockFarmerName', style: textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('¿Qué desea hacer hoy?', style: textTheme.titleMedium),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: const Icon(Icons.map_outlined, size: 36),
                title: Text('Mi parcela', style: textTheme.titleMedium),
                subtitle: Text(
                  '${mockTotalHectares.toStringAsFixed(1)} ha · '
                  '${mockFields.length} campos',
                  style: textTheme.bodyLarge,
                ),
                trailing: const Icon(Icons.chevron_right, size: 32),
                onTap: () => _open(context, const ParcelView()),
              ),
            ),
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
              label: 'Registrar actividad',
              icon: Icons.edit_note,
              onPressed: () => _open(context, const ActivityLogView()),
            ),
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: 'Reportar problema',
              icon: Icons.report_problem_outlined,
              onPressed: () => _open(context, const IncidentReportView()),
            ),
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: 'Registrar cosecha',
              icon: Icons.agriculture,
              onPressed: () => _open(context, const HarvestView()),
            ),
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: 'Mis asistencias',
              icon: Icons.groups_outlined,
              onPressed: () => _open(context, const AssistanceView()),
            ),
          ],
        ),
      ),
    );
  }
}
