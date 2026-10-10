import 'package:flutter/material.dart';

import '../../../mock/mock_data.dart';

class AssistanceDetailView extends StatefulWidget {
  const AssistanceDetailView({super.key, required this.assistance});

  final MockAssistance assistance;

  @override
  State<AssistanceDetailView> createState() => _AssistanceDetailViewState();
}

class _AssistanceDetailViewState extends State<AssistanceDetailView> {
  late final List<bool> _applied = [
    for (final recommendation in widget.assistance.recommendations)
      recommendation.applied,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final assistance = widget.assistance;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de asistencia')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(assistance.topic, style: textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              '${assistance.provider} · ${assistance.date}',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text('Recomendaciones', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            for (var i = 0; i < assistance.recommendations.length; i++)
              Card(
                child: CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    assistance.recommendations[i].text,
                    style: textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    _applied[i] ? 'Ya lo hice' : 'Pendiente',
                    style: textTheme.bodyMedium,
                  ),
                  value: _applied[i],
                  onChanged: (value) => setState(() => _applied[i] = value!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
