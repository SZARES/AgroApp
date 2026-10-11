import 'package:flutter/material.dart';

import '../../../../domain/models/technician_case.dart';

/// "05/10/2026".
String formatDay(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

/// Asks for a comment. Returns null when cancelled; the text may be empty
/// when [required] is false.
Future<String?> showCommentDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String label = 'Comentario',
  bool required = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _CommentDialog(
      title: title,
      confirmLabel: confirmLabel,
      label: label,
      required: required,
    ),
  );
}

typedef VisitPlan = ({DateTime date, String comment});

Future<VisitPlan?> showScheduleVisitDialog(BuildContext context) {
  return showDialog<VisitPlan>(
    context: context,
    builder: (_) => const _ScheduleVisitDialog(),
  );
}

Future<AssistanceDraft?> showAssistanceDialog(
  BuildContext context, {
  required List<AssistanceCategoryOption> catalog,
}) {
  return showDialog<AssistanceDraft>(
    context: context,
    builder: (_) => _AssistanceDialog(catalog: catalog),
  );
}

typedef RecommendationPlan = ({String text, DateTime? dueDate});

Future<RecommendationPlan?> showRecommendationDialog(BuildContext context) {
  return showDialog<RecommendationPlan>(
    context: context,
    builder: (_) => const _RecommendationDialog(),
  );
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.title,
    required this.children,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final List<Widget> children;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: onConfirm, child: Text(confirmLabel)),
      ],
    );
  }
}

class _CommentDialog extends StatefulWidget {
  const _CommentDialog({
    required this.title,
    required this.confirmLabel,
    required this.label,
    required this.required,
  });

  final String title;
  final String confirmLabel;
  final String label;
  final bool required;

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    return _DialogShell(
      title: widget.title,
      confirmLabel: widget.confirmLabel,
      onConfirm: widget.required && text.isEmpty
          ? null
          : () => Navigator.of(context).pop(text),
      children: [
        TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 5,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: widget.label,
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year, now.month, now.day),
          lastDate: now.add(const Duration(days: 365)),
        );
        if (picked != null) onPick(picked);
      },
      icon: const Icon(Icons.calendar_month),
      label: Text(value == null ? label : '$label: ${formatDay(value!)}'),
    );
  }
}

class _ScheduleVisitDialog extends StatefulWidget {
  const _ScheduleVisitDialog();

  @override
  State<_ScheduleVisitDialog> createState() => _ScheduleVisitDialogState();
}

class _ScheduleVisitDialogState extends State<_ScheduleVisitDialog> {
  final _comment = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return _DialogShell(
      title: 'Programar visita',
      confirmLabel: 'Guardar visita',
      onConfirm: date == null
          ? null
          : () => Navigator.of(
              context,
            ).pop((date: date, comment: _comment.text.trim())),
      children: [
        _DateField(
          label: 'Fecha de la visita',
          value: date,
          onPick: (picked) => setState(() => _date = picked),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _comment,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Comentario (opcional)',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

class _RecommendationDialog extends StatefulWidget {
  const _RecommendationDialog();

  @override
  State<_RecommendationDialog> createState() => _RecommendationDialogState();
}

class _RecommendationDialogState extends State<_RecommendationDialog> {
  final _text = TextEditingController();
  DateTime? _dueDate;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text.text.trim();
    return _DialogShell(
      title: 'Dejar recomendación',
      confirmLabel: 'Guardar',
      onConfirm: text.isEmpty
          ? null
          : () => Navigator.of(context).pop((text: text, dueDate: _dueDate)),
      children: [
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: 6,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Recomendación para el agricultor',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        _DateField(
          label: 'Fecha para aplicarla (opcional)',
          value: _dueDate,
          onPick: (picked) => setState(() => _dueDate = picked),
        ),
      ],
    );
  }
}

class _AssistanceDialog extends StatefulWidget {
  const _AssistanceDialog({required this.catalog});

  final List<AssistanceCategoryOption> catalog;

  @override
  State<_AssistanceDialog> createState() => _AssistanceDialogState();
}

class _AssistanceDialogState extends State<_AssistanceDialog> {
  final _observation = TextEditingController();
  final _recommendation = TextEditingController();
  AssistanceCategoryOption? _category;
  String? _subtypeId;
  DateTime? _nextReview;

  @override
  void dispose() {
    _observation.dispose();
    _recommendation.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      AssistanceDraft(
        categoryId: _category!.id,
        subtypeId: _subtypeId,
        observation: _observation.text.trim(),
        recommendation: _recommendation.text.trim(),
        nextReview: _nextReview,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final canSave = category != null && _observation.text.trim().isNotEmpty;
    return _DialogShell(
      title: 'Registrar asistencia',
      confirmLabel: 'Guardar asistencia',
      onConfirm: canSave ? _save : null,
      children: [
        if (widget.catalog.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Los tipos de asistencia aún no se descargaron. '
              'Conéctese una vez para cargarlos.',
            ),
          ),
        DropdownButtonFormField<String>(
          initialValue: category?.id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo de asistencia'),
          items: [
            for (final c in widget.catalog)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (id) => setState(() {
            _category = widget.catalog.firstWhere((c) => c.id == id);
            _subtypeId = null;
          }),
        ),
        if (category != null && category.subtypes.isNotEmpty) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _subtypeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Subtipo'),
            items: [
              for (final s in category.subtypes)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (id) => setState(() => _subtypeId = id),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _observation,
          minLines: 3,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Observación',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _recommendation,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Recomendación (opcional)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        _DateField(
          label: 'Próxima revisión (opcional)',
          value: _nextReview,
          onPick: (picked) => setState(() => _nextReview = picked),
        ),
      ],
    );
  }
}
