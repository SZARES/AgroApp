import 'package:flutter/material.dart';

import '../../../mock/mock_data.dart';
import 'assistance_detail_view.dart';

class AssistanceView extends StatelessWidget {
  const AssistanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis asistencias')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final assistance in mockAssistances)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  title: Text(assistance.topic, style: textTheme.titleMedium),
                  subtitle: Text(
                    '${assistance.provider} · ${assistance.date}',
                    style: textTheme.bodyMedium,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 32),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          AssistanceDetailView(assistance: assistance),
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
