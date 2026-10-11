import 'package:flutter/material.dart';

import 'primary_action_button.dart';

/// Frame of the one-question-per-screen flows: title bar, the current
/// question, an error line and big "next" and "back" buttons.
class StepFlowScaffold extends StatelessWidget {
  const StepFlowScaffold({
    super.key,
    required this.title,
    required this.isLoading,
    required this.canLeave,
    required this.onBack,
    required this.body,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    this.showBack = true,
    this.errorMessage,
    this.notice,
  });

  final String title;
  final bool isLoading;

  /// True on the first question: the system back button leaves the flow.
  final bool canLeave;
  final VoidCallback onBack;
  final Widget body;
  final String primaryLabel;
  final IconData primaryIcon;

  /// Null disables the button.
  final VoidCallback? onPrimary;
  final bool showBack;
  final String? errorMessage;

  /// When set, replaces the flow (missing data to start it).
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canLeave || isLoading || notice != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : notice ??
                    ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        body,
                        if (errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        PrimaryActionButton(
                          label: primaryLabel,
                          icon: primaryIcon,
                          onPressed: onPrimary,
                        ),
                        if (showBack) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back, size: 28),
                            label: const Text('Atrás'),
                          ),
                        ],
                      ],
                    ),
        ),
      ),
    );
  }
}

/// Large question of a flow step, with an optional hint.
class FlowQuestion extends StatelessWidget {
  const FlowQuestion(this.text, {super.key, this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: textTheme.titleLarge),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }
}

/// Centered message shown instead of a flow that cannot start.
class FlowNotice extends StatelessWidget {
  const FlowNotice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Label above a value, for the final "review" step and detail screens.
class FlowRow extends StatelessWidget {
  const FlowRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodyMedium),
          Text(value, style: textTheme.titleMedium),
        ],
      ),
    );
  }
}

/// Small orange chip shown on records that are still waiting to upload.
class PendingChip extends StatelessWidget {
  const PendingChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Por enviar',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "5 de mayo de 2026"; "-" when unknown.
String formatLongDate(DateTime? date) => date == null
    ? '-'
    : '${date.day} de ${_months[date.month - 1]} de ${date.year}';

/// "S/ 12" or "S/ 12,50".
String formatSoles(double amount) {
  final fixed = amount.toStringAsFixed(2);
  final text = fixed.endsWith('.00')
      ? fixed.substring(0, fixed.length - 3)
      : fixed.replaceAll('.', ',');
  return 'S/ $text';
}

/// "08/10/2026"; "-" when unknown.
String formatShortDate(DateTime? date) {
  if (date == null) return '-';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
