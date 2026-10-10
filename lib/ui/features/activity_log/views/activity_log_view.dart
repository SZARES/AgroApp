import 'package:flutter/material.dart';

import '../../../core/widgets/option_tile.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../mock/mock_data.dart';
import 'activity_detail_view.dart';

class ActivityLogView extends StatefulWidget {
  const ActivityLogView({super.key});

  @override
  State<ActivityLogView> createState() => _ActivityLogViewState();
}

class _ActivityLogViewState extends State<ActivityLogView> {
  static const _activities = [
    (label: 'Riego', icon: Icons.water_drop_outlined),
    (label: 'Abono', icon: Icons.grass),
    (label: 'Fumigación', icon: Icons.pest_control),
    (label: 'Poda', icon: Icons.content_cut),
    (label: 'Siembra', icon: Icons.eco_outlined),
    (label: 'Otra', icon: Icons.more_horiz),
  ];

  int? _selected;

  void _save() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Guardado en el celular')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar actividad')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('¿Qué hizo hoy?', style: textTheme.titleLarge),
            const SizedBox(height: 16),
            for (var i = 0; i < _activities.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OptionTile(
                  label: _activities[i].label,
                  icon: _activities[i].icon,
                  selected: _selected == i,
                  onTap: () => setState(() => _selected = i),
                ),
              ),
            const SizedBox(height: 8),
            PrimaryActionButton(
              label: 'Guardar',
              icon: Icons.save_outlined,
              onPressed: _selected == null ? null : _save,
            ),
            const SizedBox(height: 32),
            Text('Últimas actividades', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final activity in mockActivities)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  title: Text(activity.title, style: textTheme.titleMedium),
                  subtitle: Text(
                    '${activity.field} · ${activity.date}',
                    style: textTheme.bodyMedium,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 32),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ActivityDetailView(activity: activity),
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
