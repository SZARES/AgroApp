import 'package:flutter/material.dart';

import '../../../core/widgets/primary_action_button.dart';
import '../../../mock/mock_data.dart';

class CaseStatusView extends StatelessWidget {
  const CaseStatusView({super.key, required this.caseItem});

  final MockCase caseItem;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final steps = CaseStatus.values;
    final currentIndex = steps.indexOf(caseItem.status);
    final canConfirm = caseItem.status == CaseStatus.attended;

    return Scaffold(
      appBar: AppBar(title: Text('Caso ${caseItem.id}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(caseItem.problem, style: textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              '${caseItem.field} · ${caseItem.reportedAt}',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < steps.length; i++)
              _TimelineStep(
                label: caseStatusLabels[steps[i]]!,
                done: i <= currentIndex,
                isLast: i == steps.length - 1,
              ),
            const SizedBox(height: 24),
            if (canConfirm)
              PrimaryActionButton(
                label: 'Confirmar que ya se atendió',
                icon: Icons.check_circle_outline,
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Guardado en el celular')),
                ),
              )
            else
              Text(
                'Podrá confirmar cuando el técnico marque el caso como atendido.',
                style: textTheme.bodyLarge,
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.done,
    required this.isLast,
  });

  final String label;
  final bool done;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = done ? scheme.primary : scheme.outline;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 32,
              color: color,
            ),
            if (!isLast) Container(width: 3, height: 32, color: color),
          ],
        ),
        const SizedBox(width: 16),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: done ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
