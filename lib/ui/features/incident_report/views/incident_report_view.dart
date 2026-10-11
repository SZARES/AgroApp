import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../data/services/photo_service.dart';
import '../../../../domain/models/incident.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/option_tile.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../view_models/report_incident_view_model.dart';

/// "Reportar problema": one question per screen, saved on the device first.
class IncidentReportView extends StatelessWidget {
  const IncidentReportView({
    super.key,
    required this.viewModel,
    required this.caseBuilder,
  });

  final ReportIncidentViewModel viewModel;

  /// Builds the status screen of a saved report.
  final Widget Function(String incidentId) caseBuilder;

  Future<void> _submit(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (!await viewModel.submit()) return;
    final id = viewModel.savedId;
    if (id == null) return;
    if (context.mounted) {
      showAppSnackBar(context, 'Guardado');
    }
    await navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => caseBuilder(id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return PopScope(
          canPop:
              !viewModel.isSaving &&
              (viewModel.isAtFirstStep || viewModel.isLoading),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && !viewModel.isSaving) viewModel.back();
          },
          child: AppLoadingOverlay(
            visible: viewModel.isSaving,
            message: 'Guardando reporte…',
            child: Scaffold(
              appBar: AppBar(title: const Text('Reportar problema')),
              body: SafeArea(
                child: viewModel.isLoading
                    ? const Center(
                        child: AppLoadingCard(message: 'Cargando…'),
                      )
                    : _StepBody(
                        viewModel: viewModel,
                        onSubmit: () => _submit(context),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({required this.viewModel, required this.onSubmit});

  final ReportIncidentViewModel viewModel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    if (vm.parcels.isEmpty) {
      return const _Notice(
        icon: Icons.map_outlined,
        text: 'Primero agregue su parcela en "Mi parcela"',
      );
    }
    if (vm.symptoms.isEmpty) {
      return const _Notice(
        icon: Icons.sync,
        text: 'Estamos descargando la lista de señales. Intente en un momento',
      );
    }
    final isLast = vm.step == ReportStep.confirm;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        switch (vm.step) {
          ReportStep.parcel => _ParcelStep(viewModel: vm),
          ReportStep.symptoms => _SymptomsStep(viewModel: vm),
          ReportStep.description => _DescriptionStep(viewModel: vm),
          ReportStep.photos => _PhotosStep(viewModel: vm),
          ReportStep.confirm => _ConfirmStep(viewModel: vm),
        },
        if (vm.errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            vm.errorMessage!,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 24),
        PrimaryActionButton(
          label: isLast
              ? (vm.isSaving ? 'Guardando…' : 'Guardar reporte')
              : 'Siguiente',
          icon: isLast ? Icons.check : Icons.arrow_forward,
          onPressed: vm.canContinue ? (isLast ? onSubmit : vm.next) : null,
        ),
        if (!vm.isAtFirstStep) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: vm.isSaving ? null : vm.back,
            icon: const Icon(Icons.arrow_back, size: 28),
            label: const Text('Atrás'),
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

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

class _Question extends StatelessWidget {
  const _Question(this.text, {this.hint});

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

class _ParcelStep extends StatelessWidget {
  const _ParcelStep({required this.viewModel});

  final ReportIncidentViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Question('¿En qué parcela está el problema?'),
        for (final parcel in viewModel.parcels)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionTile(
              label: parcel.name,
              icon: Icons.landscape_outlined,
              selected: viewModel.parcelId == parcel.id,
              onTap: () => viewModel.selectParcel(parcel.id),
            ),
          ),
      ],
    );
  }
}

class _SymptomsStep extends StatelessWidget {
  const _SymptomsStep({required this.viewModel});

  final ReportIncidentViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final selected = viewModel.selectedSymptomIds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Question(
          '¿Qué le pasa a su cultivo?',
          hint: 'Puede elegir varias señales',
        ),
        for (final symptom in viewModel.symptoms)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionTile(
              label: symptom.name,
              icon: Icons.local_florist_outlined,
              selected: selected.contains(symptom.id),
              onTap: () => viewModel.toggleSymptom(symptom.id),
            ),
          ),
      ],
    );
  }
}

class _DescriptionStep extends StatelessWidget {
  const _DescriptionStep({required this.viewModel});

  final ReportIncidentViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Question(
          '¿Quiere contarnos algo más?',
          hint: 'Es opcional. Puede dejarlo en blanco',
        ),
        TextFormField(
          initialValue: viewModel.description,
          onChanged: viewModel.setDescription,
          minLines: 4,
          maxLines: 8,
          maxLength: 500,
          style: Theme.of(context).textTheme.titleMedium,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Por ejemplo: desde hace 3 días, en las hojas de abajo',
          ),
        ),
      ],
    );
  }
}

class _PhotosStep extends StatelessWidget {
  const _PhotosStep({required this.viewModel});

  final ReportIncidentViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Question(
          '¿Puede enviar fotos?',
          hint: 'Es opcional. Hasta ${IncidentDraft.maxPhotos} fotos',
        ),
        if (vm.photos.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final photo in vm.photos)
                _PhotoThumb(
                  photo: photo,
                  onRemove: () => vm.removePhoto(photo),
                ),
            ],
          ),
        if (vm.photos.isNotEmpty) const SizedBox(height: 16),
        if (vm.isPickingPhoto)
          const Center(child: CircularProgressIndicator())
        else if (vm.canAddPhoto) ...[
          PrimaryActionButton(
            label: 'Tomar foto',
            icon: Icons.photo_camera,
            onPressed: () => vm.addPhoto(PhotoSource.camera),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => vm.addPhoto(PhotoSource.gallery),
            icon: const Icon(Icons.photo_library_outlined, size: 28),
            label: const Text('Elegir de la galería'),
          ),
        ] else
          Text(
            'Ya tiene las 3 fotos',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.onRemove});

  final PickedPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(photo.localPath),
            width: 140,
            height: 140,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton.filled(
            onPressed: onRemove,
            tooltip: 'Quitar foto',
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.viewModel});

  final ReportIncidentViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final vm = viewModel;
    final description = vm.description.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Question('Revise su reporte'),
        _Row(label: 'Parcela', value: vm.selectedParcel?.name ?? '-'),
        _Row(
          label: 'Señales',
          value: vm.selectedSymptoms.map((s) => s.name).join(', '),
        ),
        _Row(
          label: 'Comentario',
          value: description.isEmpty ? 'Sin comentario' : description,
        ),
        _Row(
          label: 'Fotos',
          value: vm.photos.isEmpty ? 'Sin fotos' : '${vm.photos.length}',
        ),
        const SizedBox(height: 8),
        Text(
          'Se guarda en su teléfono y se envía cuando haya señal.',
          style: textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

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
