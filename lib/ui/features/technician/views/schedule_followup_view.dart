import 'package:flutter/material.dart';

import '../../../core/widgets/primary_action_button.dart';

class ScheduleFollowUpView extends StatefulWidget {
  const ScheduleFollowUpView({super.key});

  @override
  State<ScheduleFollowUpView> createState() => _ScheduleFollowUpViewState();
}

class _ScheduleFollowUpViewState extends State<ScheduleFollowUpView> {
  DateTime? _date;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  void _save() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Guardado en el celular')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final date = _date;
    final dateLabel = date == null
        ? 'Sin fecha'
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/'
              '${date.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Programar seguimiento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Próxima visita', style: textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: const Icon(Icons.event, size: 36),
                title: Text('Fecha', style: textTheme.bodyLarge),
                subtitle: Text(dateLabel, style: textTheme.titleMedium),
                onTap: _pickDate,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month, size: 28),
              label: const Text('Elegir fecha'),
            ),
            const SizedBox(height: 24),
            PrimaryActionButton(
              label: 'Guardar seguimiento',
              icon: Icons.save_outlined,
              onPressed: date == null ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
