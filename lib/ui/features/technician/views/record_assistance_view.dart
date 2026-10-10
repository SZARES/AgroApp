import 'package:flutter/material.dart';

import '../../../core/widgets/primary_action_button.dart';

class RecordAssistanceView extends StatefulWidget {
  const RecordAssistanceView({super.key});

  @override
  State<RecordAssistanceView> createState() => _RecordAssistanceViewState();
}

class _RecordAssistanceViewState extends State<RecordAssistanceView> {
  static const _types = [
    'Visita técnica',
    'Diagnóstico',
    'Capacitación',
    'Seguimiento',
  ];

  String _type = _types.first;
  String _recommendation = '';

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
      appBar: AppBar(title: const Text('Registrar asistencia técnica')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo de asistencia',
              ),
              style: textTheme.titleMedium,
              items: [
                for (final type in _types)
                  DropdownMenuItem(value: type, child: Text(type)),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 16),
            TextField(
              minLines: 4,
              maxLines: 6,
              style: textTheme.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Recomendación',
                alignLabelWithHint: true,
              ),
              onChanged: (value) => setState(() => _recommendation = value),
            ),
            const SizedBox(height: 24),
            PrimaryActionButton(
              label: 'Guardar',
              icon: Icons.save_outlined,
              onPressed: _recommendation.trim().isEmpty ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
