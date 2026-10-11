import 'package:flutter/material.dart';

import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/option_tile.dart';
import '../../../core/widgets/step_flow.dart';
import '../view_models/record_activity_view_model.dart';

/// "Registrar actividad": one question per screen, saved on the device first.
class RecordActivityView extends StatelessWidget {
  const RecordActivityView({super.key, required this.viewModel});

  final RecordActivityViewModel viewModel;

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
        final isLast = !vm.isLoading && vm.isAtLastStep;
        return StepFlowScaffold(
          title: 'Registrar actividad',
          isLoading: vm.isLoading,
          isBusy: vm.isSaving,
          busyMessage: 'Guardando actividad…',
          canLeave: vm.isAtFirstStep,
          onBack: vm.back,
          showBack: !vm.isAtFirstStep,
          notice: vm.isLoading
              ? null
              : vm.hasNoParcel
              ? const FlowNotice(
                  icon: Icons.map_outlined,
                  text: 'Primero agregue su parcela en "Mi parcela"',
                )
              : vm.needsCrop
              ? const FlowNotice(
                  icon: Icons.agriculture_outlined,
                  text:
                      'Su parcela aún no tiene un cultivo. '
                      'Espere a que se sincronice o pida a su técnico '
                      'que registre el cultivo',
                )
              : vm.hasNoCatalog
              ? const FlowNotice(
                  icon: Icons.sync,
                  text:
                      'Estamos descargando la lista de actividades. '
                      'Intente en un momento',
                )
              : null,
          body: vm.isLoading || vm.isBlocked
              ? const SizedBox.shrink()
              : switch (vm.step) {
                  ActivityStep.parcel => _ParcelStep(viewModel: vm),
                  ActivityStep.type => _TypeStep(viewModel: vm),
                  ActivityStep.product => _ProductStep(viewModel: vm),
                  ActivityStep.pruning => _PruningStep(viewModel: vm),
                  ActivityStep.quantity => _QuantityStep(viewModel: vm),
                  ActivityStep.expenseAmount => _AmountStep(viewModel: vm),
                  ActivityStep.expenseCategory => _CategoryStep(viewModel: vm),
                  ActivityStep.confirm => _ConfirmStep(viewModel: vm),
                },
          errorMessage: vm.errorMessage,
          primaryLabel: isLast
              ? (vm.isSaving ? 'Guardando…' : 'Guardar')
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

  final RecordActivityViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿En qué parcela trabajó?'),
        for (final parcel in viewModel.parcels)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionTile(
              label: '${parcel.name} · ${parcel.cropName}',
              icon: Icons.landscape_outlined,
              selected: viewModel.parcelId == parcel.id,
              onTap: () => viewModel.selectParcel(parcel.id),
            ),
          ),
      ],
    );
  }
}

class _TypeStep extends StatelessWidget {
  const _TypeStep({required this.viewModel});

  final RecordActivityViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿Qué hizo hoy?'),
        for (final type in viewModel.catalog.types)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionTile(
              label: type.name,
              icon: _iconFor(type.code),
              selected: viewModel.typeId == type.id,
              onTap: () => viewModel.selectType(type.id),
            ),
          ),
      ],
    );
  }

  /// Icons are presentation only; unknown codes get a generic one.
  static IconData _iconFor(String code) => switch (code) {
    'irrigation' => Icons.water_drop_outlined,
    'fertilization' => Icons.grass,
    'phytosanitary' => Icons.pest_control,
    'pruning' => Icons.content_cut,
    'weeding' => Icons.cleaning_services_outlined,
    'sowing' => Icons.eco_outlined,
    _ => Icons.more_horiz,
  };
}

class _ProductStep extends StatelessWidget {
  const _ProductStep({required this.viewModel});

  final RecordActivityViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿Qué usó?'),
        for (final product in viewModel.catalog.products)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionTile(
              label: product.name,
              icon: Icons.inventory_2_outlined,
              selected: viewModel.productId == product.id,
              onTap: () => viewModel.selectProduct(product.id),
            ),
          ),
      ],
    );
  }
}

class _PruningStep extends StatelessWidget {
  const _PruningStep({required this.viewModel});

  final RecordActivityViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿Qué tipo de poda hizo?'),
        for (final pruning in viewModel.catalog.pruningTypes)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionTile(
              label: pruning.name,
              icon: Icons.content_cut,
              selected: viewModel.pruningTypeId == pruning.id,
              onTap: () => viewModel.selectPruningType(pruning.id),
            ),
          ),
      ],
    );
  }
}

class _QuantityStep extends StatelessWidget {
  const _QuantityStep({required this.viewModel});

  final RecordActivityViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final selected = vm.selectedUnit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion(
          '¿Cuánto usó?',
          hint: 'Es opcional. Puede dejarlo en blanco',
        ),
        TextFormField(
          initialValue: vm.quantityText,
          onChanged: vm.setQuantity,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: Theme.of(context).textTheme.headlineMedium,
          decoration: const InputDecoration(labelText: 'Cantidad'),
        ),
        const SizedBox(height: 16),
        Text('Unidad', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final unit in vm.allowedUnits)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionTile(
              label: unit.name,
              icon: Icons.straighten,
              selected: selected?.id == unit.id,
              onTap: () => vm.selectUnit(unit.id),
            ),
          ),
      ],
    );
  }
}

class _AmountStep extends StatelessWidget {
  const _AmountStep({required this.viewModel});

  final RecordActivityViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion(
          '¿Gastó dinero?',
          hint: 'Escriba cuántos soles. Si no gastó, déjelo en blanco',
        ),
        TextFormField(
          initialValue: viewModel.amountText,
          onChanged: viewModel.setAmount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: Theme.of(context).textTheme.headlineMedium,
          decoration: const InputDecoration(
            labelText: 'Monto',
            prefixText: 'S/ ',
          ),
        ),
      ],
    );
  }
}

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({required this.viewModel});

  final RecordActivityViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿En qué lo gastó?'),
        for (final category in viewModel.catalog.expenseCategories)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionTile(
              label: category.name,
              icon: Icons.payments_outlined,
              selected: viewModel.expenseCategoryId == category.id,
              onTap: () => viewModel.selectExpenseCategory(category.id),
            ),
          ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.viewModel});

  final RecordActivityViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final unit = vm.selectedUnit;
    final hasQuantity = unit != null && (vm.quantity ?? 0) > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('Revise su actividad'),
        FlowRow(label: 'Parcela', value: vm.selectedParcel?.name ?? '-'),
        FlowRow(label: 'Actividad', value: vm.selectedType?.name ?? '-'),
        if (vm.selectedProduct != null && vm.selectedType!.requiresProduct)
          FlowRow(label: 'Producto', value: vm.selectedProduct!.name),
        if (vm.selectedPruningType != null &&
            vm.selectedType!.requiresPruningType)
          FlowRow(label: 'Tipo de poda', value: vm.selectedPruningType!.name),
        if (hasQuantity)
          FlowRow(
            label: 'Cantidad',
            value: '${vm.quantityText.trim()} ${unit.label}',
          ),
        FlowRow(
          label: 'Gasto',
          value: vm.spentMoney
              ? '${formatSoles(vm.expenseAmount!)} · '
                    '${vm.selectedExpenseCategory?.name ?? ''}'
              : 'Sin gasto',
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
