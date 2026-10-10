import 'package:flutter/material.dart';

import '../../../core/widgets/option_tile.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../mock/mock_data.dart';

class ChangeCaseStatusView extends StatefulWidget {
  const ChangeCaseStatusView({super.key, required this.current});

  final CaseStatus current;

  @override
  State<ChangeCaseStatusView> createState() => _ChangeCaseStatusViewState();
}

class _ChangeCaseStatusViewState extends State<ChangeCaseStatusView> {
  late CaseStatus _selected = widget.current;

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
      appBar: AppBar(title: const Text('Cambiar estado')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Nuevo estado del caso', style: textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final status in CaseStatus.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OptionTile(
                  label: caseStatusLabels[status]!,
                  icon: _iconFor(status),
                  selected: _selected == status,
                  onTap: () => setState(() => _selected = status),
                ),
              ),
            const SizedBox(height: 8),
            PrimaryActionButton(
              label: 'Guardar',
              icon: Icons.save_outlined,
              onPressed: _selected == widget.current ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(CaseStatus status) {
  return switch (status) {
    CaseStatus.reported => Icons.notification_important_outlined,
    CaseStatus.underReview => Icons.search,
    CaseStatus.visitScheduled => Icons.event_available_outlined,
    CaseStatus.attended => Icons.handshake_outlined,
    CaseStatus.closed => Icons.task_alt,
  };
}
