import 'package:flutter/material.dart';

import '../../../mock/mock_data.dart';

class ActivityDetailView extends StatelessWidget {
  const ActivityDetailView({super.key, required this.activity});

  final MockActivity activity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de actividad')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(activity.title, style: textTheme.headlineMedium),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: 'Campo', value: activity.field),
                    _DetailRow(label: 'Fecha', value: activity.date),
                    _DetailRow(
                      label: 'Costo',
                      value: 'S/ ${activity.cost.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyLarge)),
          Text(value, style: textTheme.titleMedium),
        ],
      ),
    );
  }
}
