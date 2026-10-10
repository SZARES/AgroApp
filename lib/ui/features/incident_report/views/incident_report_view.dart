import 'package:flutter/material.dart';

import '../../../core/widgets/option_tile.dart';
import '../../../core/widgets/primary_action_button.dart';
import 'incident_photo_view.dart';

class IncidentReportView extends StatefulWidget {
  const IncidentReportView({super.key});

  @override
  State<IncidentReportView> createState() => _IncidentReportViewState();
}

class _IncidentReportViewState extends State<IncidentReportView> {
  static const _problems = [
    (label: 'Plaga en las hojas', icon: Icons.bug_report_outlined),
    (label: 'Enfermedad', icon: Icons.local_florist_outlined),
    (label: 'Falta de agua', icon: Icons.water_drop_outlined),
    (label: 'Otro problema', icon: Icons.help_outline),
  ];

  int? _selected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(title: const Text('Reportar problema')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('¿Qué le pasa a su cultivo?', style: textTheme.titleLarge),
            const SizedBox(height: 16),
            for (var i = 0; i < _problems.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OptionTile(
                  label: _problems[i].label,
                  icon: _problems[i].icon,
                  selected: _selected == i,
                  onTap: () => setState(() => _selected = i),
                ),
              ),
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: 'Siguiente',
              icon: Icons.arrow_forward,
              onPressed: selected == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => IncidentPhotoView(
                          problem: _problems[selected].label,
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
