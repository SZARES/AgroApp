import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../data/services/photo_service.dart';
import '../../../../domain/models/assistance.dart';
import '../../../../domain/models/incident.dart';
import '../../../../domain/models/record_support.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/option_tile.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/step_flow.dart';
import '../view_models/external_visit_view_model.dart';
import '../../../core/widgets/skeleton.dart';

/// "Registrar visita externa": a visit from SENASA or another institution,
/// one question per screen, saved on the device first.
class ExternalVisitView extends StatelessWidget {
  const ExternalVisitView({super.key, required this.viewModel});

  final ExternalVisitViewModel viewModel;

  Future<void> _submit(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (!await viewModel.submit()) return;
    if (context.mounted) {
      showAppSnackBar(context, 'Guardado');
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final vm = viewModel;
        final blocked =
            !vm.isLoading && (vm.hasNoParcel || vm.hasNoCategories);
        final isLast = !vm.isLoading && !blocked && vm.isAtLastStep;
        return StepFlowScaffold(
          title: 'Registrar visita externa',
          isLoading: vm.isLoading,
          isBusy: vm.isSaving,
          busyMessage: 'Guardando visita…',
          canLeave: blocked || vm.isAtFirstStep,
          onBack: vm.back,
          showBack: !vm.isAtFirstStep,
          notice: !blocked
              ? null
              : vm.hasNoParcel
              ? const FlowNotice(
                  icon: Icons.map_outlined,
                  text: 'Primero agregue su parcela en "Mi parcela"',
                )
              : const FlowNotice(
                  icon: Icons.sync,
                  text:
                      'Estamos descargando la lista de temas. '
                      'Intente en un momento',
                ),
          body: vm.isLoading || blocked
              ? const SizedBox.shrink()
              : switch (vm.step) {
                  ExternalVisitStep.parcel => _ParcelStep(viewModel: vm),
                  ExternalVisitStep.provider => _ProviderStep(viewModel: vm),
                  ExternalVisitStep.institution => _InstitutionStep(
                    viewModel: vm,
                  ),
                  ExternalVisitStep.date => _DateStep(viewModel: vm),
                  ExternalVisitStep.category => _CategoryStep(viewModel: vm),
                  ExternalVisitStep.photos => _PhotosStep(viewModel: vm),
                  ExternalVisitStep.comment => _CommentStep(viewModel: vm),
                  ExternalVisitStep.confirm => _ConfirmStep(viewModel: vm),
                },
          errorMessage: vm.errorMessage,
          primaryLabel: isLast
              ? (vm.isSaving ? 'Guardando…' : 'Guardar visita')
              : 'Siguiente',
          primaryIcon: isLast ? Icons.check : Icons.arrow_forward,
          onPrimary: vm.canContinue
              ? (isLast ? () => _submit(context) : vm.next)
              : null,
        );
      },
    );
  }
}

class _ParcelStep extends StatelessWidget {
  const _ParcelStep({required this.viewModel});

  final ExternalVisitViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿En qué parcela fue la visita?'),
        for (final parcel in viewModel.catalog.parcels)
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

class _ProviderStep extends StatelessWidget {
  const _ProviderStep({required this.viewModel});

  final ExternalVisitViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿Quién lo visitó?'),
        OptionTile(
          label: 'SENASA',
          icon: Icons.verified_outlined,
          selected: viewModel.provider == AssistanceProvider.senasa,
          onTap: () => viewModel.selectProvider(AssistanceProvider.senasa),
        ),
        const SizedBox(height: 12),
        OptionTile(
          label: 'Otra institución',
          icon: Icons.apartment_outlined,
          selected: viewModel.provider == AssistanceProvider.other,
          onTap: () => viewModel.selectProvider(AssistanceProvider.other),
        ),
      ],
    );
  }
}

class _InstitutionStep extends StatelessWidget {
  const _InstitutionStep({required this.viewModel});

  final ExternalVisitViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿Cómo se llama la institución?'),
        TextFormField(
          initialValue: viewModel.institution,
          onChanged: viewModel.setInstitution,
          autofocus: true,
          maxLength: 80,
          style: Theme.of(context).textTheme.titleMedium,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Institución'),
        ),
      ],
    );
  }
}

class _DateStep extends StatelessWidget {
  const _DateStep({required this.viewModel});

  final ExternalVisitViewModel viewModel;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: viewModel.date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Fecha de la visita',
    );
    if (picked != null) viewModel.setDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final chosen = dateOnly(vm.date);
    final isToday = chosen == dateOnly(today);
    final isYesterday = chosen == dateOnly(yesterday);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿Cuándo fue la visita?'),
        OptionTile(
          label: 'Hoy',
          icon: Icons.today,
          selected: isToday,
          onTap: () => vm.setDate(today),
        ),
        const SizedBox(height: 12),
        OptionTile(
          label: 'Ayer',
          icon: Icons.history,
          selected: isYesterday,
          onTap: () => vm.setDate(yesterday),
        ),
        const SizedBox(height: 12),
        OptionTile(
          label: isToday || isYesterday
              ? 'Elegir otra fecha'
              : formatLongDate(vm.date),
          icon: Icons.calendar_month_outlined,
          selected: !isToday && !isYesterday,
          onTap: () => _pick(context),
        ),
      ],
    );
  }
}

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({required this.viewModel});

  final ExternalVisitViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿Sobre qué tema fue?'),
        for (final category in viewModel.catalog.categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionTile(
              label: category.name,
              icon: Icons.local_florist_outlined,
              selected: viewModel.categoryId == category.id,
              onTap: () => viewModel.selectCategory(category.id),
            ),
          ),
      ],
    );
  }
}

class _PhotosStep extends StatelessWidget {
  const _PhotosStep({required this.viewModel});

  final ExternalVisitViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion(
          '¿Tiene foto de la ficha o del documento?',
          hint: 'Es opcional. Hasta ${ExternalVisitDraft.maxPhotos} fotos',
        ),
        if (vm.photos.isNotEmpty)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final photo in vm.photos)
                _PhotoThumb(photo: photo, onRemove: () => vm.removePhoto(photo)),
            ],
          ),
        if (vm.photos.isNotEmpty) const SizedBox(height: 16),
        if (vm.isPickingPhoto)
          const Skeleton(child: SkeletonBox(height: 64))
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
            'Ya tiene las ${ExternalVisitDraft.maxPhotos} fotos',
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

class _CommentStep extends StatelessWidget {
  const _CommentStep({required this.viewModel});

  final ExternalVisitViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion(
          '¿Qué le recomendaron?',
          hint: 'Es opcional. Puede dejarlo en blanco',
        ),
        TextFormField(
          initialValue: viewModel.comment,
          onChanged: viewModel.setComment,
          minLines: 4,
          maxLines: 8,
          maxLength: 500,
          style: Theme.of(context).textTheme.titleMedium,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Por ejemplo: revisar las hojas cada semana',
          ),
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.viewModel});

  final ExternalVisitViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final comment = vm.comment.trim();
    final who = vm.provider == AssistanceProvider.other
        ? vm.institution.trim()
        : 'SENASA';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('Revise la visita'),
        FlowRow(label: 'Parcela', value: vm.selectedParcel?.name ?? '-'),
        FlowRow(label: 'Institución', value: who),
        FlowRow(label: 'Fecha', value: formatLongDate(vm.date)),
        FlowRow(label: 'Tema', value: vm.selectedCategory?.name ?? '-'),
        FlowRow(
          label: 'Fotos',
          value: vm.photos.isEmpty ? 'Sin fotos' : '${vm.photos.length}',
        ),
        FlowRow(
          label: 'Comentario',
          value: comment.isEmpty ? 'Sin comentario' : comment,
        ),
        const SizedBox(height: 8),
        Text(
          'Se guarda en su teléfono y se envía cuando haya señal.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
