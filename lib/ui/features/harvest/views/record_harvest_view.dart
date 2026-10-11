import 'package:flutter/material.dart';

import '../../../../domain/models/harvest.dart';
import '../../../../domain/models/record_support.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/option_tile.dart';
import '../../../core/widgets/step_flow.dart';
import '../view_models/record_harvest_view_model.dart';

/// "Registrar cosecha": one question per screen, saved on the device first.
class RecordHarvestView extends StatelessWidget {
  const RecordHarvestView({super.key, required this.viewModel});

  final RecordHarvestViewModel viewModel;

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
        final blocked = !vm.isLoading && vm.isBlocked;
        final isLast = !vm.isLoading && !blocked && vm.isAtLastStep;
        return StepFlowScaffold(
          title: 'Registrar cosecha',
          isLoading: vm.isLoading,
          isBusy: vm.isSaving,
          busyMessage: 'Guardando cosecha…',
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
              : vm.needsCrop
              ? const FlowNotice(
                  icon: Icons.agriculture_outlined,
                  text:
                      'Su parcela aún no tiene un cultivo. '
                      'Espere a que se sincronice o pida a su técnico '
                      'que registre el cultivo',
                )
              : const FlowNotice(
                  icon: Icons.sync,
                  text:
                      'Estamos descargando las unidades. Intente en un momento',
                ),
          body: vm.isLoading || blocked
              ? const SizedBox.shrink()
              : switch (vm.step) {
                  HarvestStep.parcel => _ParcelStep(viewModel: vm),
                  HarvestStep.quantity => _QuantityStep(viewModel: vm),
                  HarvestStep.destination => _DestinationStep(viewModel: vm),
                  HarvestStep.split => _SplitStep(viewModel: vm),
                  HarvestStep.sale => _SaleStep(viewModel: vm),
                  HarvestStep.residue => _ResidueStep(viewModel: vm),
                  HarvestStep.confirm => _ConfirmStep(viewModel: vm),
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

  final RecordHarvestViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿De qué parcela cosechó?'),
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

class _QuantityStep extends StatelessWidget {
  const _QuantityStep({required this.viewModel});

  final RecordHarvestViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final selected = vm.selectedUnit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlowQuestion(
          '¿Cuánto cosechó de ${vm.selectedParcel?.cropName ?? 'su cultivo'}?',
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
        for (final unit in vm.units)
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

class _DestinationStep extends StatelessWidget {
  const _DestinationStep({required this.viewModel});

  final RecordHarvestViewModel viewModel;

  static const _options = [
    (
      HarvestDestination.family,
      'Para la casa',
      Icons.home_outlined,
    ),
    (
      HarvestDestination.surplus,
      'Para vender',
      Icons.sell_outlined,
    ),
    (
      HarvestDestination.split,
      'Una parte para la casa y otra para vender',
      Icons.call_split,
    ),
    (HarvestDestination.other, 'Otro destino', Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿Para qué fue la cosecha?'),
        for (final option in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionTile(
              label: option.$2,
              icon: option.$3,
              selected: viewModel.destination == option.$1,
              onTap: () => viewModel.selectDestination(option.$1),
            ),
          ),
      ],
    );
  }
}

class _SplitStep extends StatelessWidget {
  const _SplitStep({required this.viewModel});

  final RecordHarvestViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final unit = vm.selectedUnit?.label ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlowQuestion(
          '¿Cuánto se quedó en casa?',
          hint:
              'De ${vm.quantityText.trim()} $unit cosechados. '
              'El resto queda para vender',
        ),
        TextFormField(
          initialValue: vm.householdText,
          onChanged: vm.setHousehold,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: Theme.of(context).textTheme.headlineMedium,
          decoration: InputDecoration(
            labelText: 'Para la casa',
            suffixText: unit,
          ),
        ),
        if (vm.householdText.trim().isNotEmpty && !vm.canContinue)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Debe ser menos que lo cosechado',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _SaleStep extends StatelessWidget {
  const _SaleStep({required this.viewModel});

  final RecordHarvestViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final unit = vm.selectedUnit?.label ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('¿Ya vendió lo que sobró?'),
        OptionTile(
          label: 'Sí, ya lo vendí',
          icon: Icons.sell_outlined,
          selected: vm.sold == true,
          onTap: () => vm.selectSold(true),
        ),
        const SizedBox(height: 12),
        OptionTile(
          label: 'Todavía no',
          icon: Icons.hourglass_empty,
          selected: vm.sold == false,
          onTap: () => vm.selectSold(false),
        ),
        if (vm.sold == true) ...[
          const SizedBox(height: 24),
          DropdownButtonFormField<String?>(
            initialValue: vm.buyerId,
            decoration: const InputDecoration(labelText: 'Comprador'),
            style: Theme.of(context).textTheme.titleMedium,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('No sé / otro'),
              ),
              for (final buyer in vm.catalog.buyers)
                DropdownMenuItem<String?>(
                  value: buyer.id,
                  child: Text(buyer.name),
                ),
            ],
            onChanged: vm.selectBuyer,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: vm.priceText,
            onChanged: vm.setPrice,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.titleMedium,
            decoration: InputDecoration(
              labelText: 'Precio por $unit (opcional)',
              prefixText: 'S/ ',
            ),
          ),
        ],
      ],
    );
  }
}

class _ResidueStep extends StatelessWidget {
  const _ResidueStep({required this.viewModel});

  final RecordHarvestViewModel viewModel;

  static const _options = [
    (ResidueUse.compost, 'Lo hizo compost', Icons.recycling),
    (ResidueUse.otherUse, 'Lo usó para otra cosa', Icons.alt_route),
    (ResidueUse.notUsed, 'No lo usó', Icons.block),
  ];

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final residueUnit = vm.selectedResidueUnit;
    final asksQuantity =
        vm.residueUse != null && vm.residueUse != ResidueUse.notUsed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion(
          '¿Qué hizo con el rastrojo?',
          hint: 'Es opcional. Toque otra vez para quitar la respuesta',
        ),
        for (final option in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OptionTile(
              label: option.$2,
              icon: option.$3,
              selected: vm.residueUse == option.$1,
              onTap: () => vm.toggleResidue(option.$1),
            ),
          ),
        if (asksQuantity) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: vm.residueQuantityText,
                  onChanged: vm.setResidueQuantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad (opcional)',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: residueUnit?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Unidad'),
                  items: [
                    for (final unit in vm.units)
                      DropdownMenuItem(value: unit.id, child: Text(unit.label)),
                  ],
                  onChanged: (id) {
                    if (id != null) vm.selectResidueUnit(id);
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.viewModel});

  final RecordHarvestViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final unit = vm.selectedUnit?.label ?? '';
    final surplus = vm.surplusQuantity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlowQuestion('Revise su cosecha'),
        FlowRow(
          label: 'Parcela',
          value: '${vm.selectedParcel?.name ?? '-'} · '
              '${vm.selectedParcel?.cropName ?? ''}',
        ),
        FlowRow(
          label: 'Cosecha total',
          value: '${vm.quantityText.trim()} $unit',
        ),
        FlowRow(label: 'Destino', value: _destinationLabel(vm)),
        if (vm.destination == HarvestDestination.split && surplus != null)
          FlowRow(
            label: 'Para vender',
            value: '${formatNumber(surplus)} $unit',
          ),
        if (vm.hasSurplus)
          FlowRow(
            label: 'Venta',
            value: vm.sold == true
                ? [
                    vm.selectedBuyer?.name ?? 'Comprador sin indicar',
                    if (vm.pricePerUnit != null)
                      '${formatSoles(vm.pricePerUnit!)} por $unit',
                  ].join(' · ')
                : 'Todavía no vendido',
          ),
        FlowRow(label: 'Rastrojo', value: _residueLabel(vm)),
        const SizedBox(height: 8),
        Text(
          'Se guarda en su teléfono y se envía cuando haya señal.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  static String _destinationLabel(RecordHarvestViewModel vm) =>
      switch (vm.destination) {
        HarvestDestination.family => 'Para la casa',
        HarvestDestination.surplus => 'Para vender',
        HarvestDestination.split =>
          'Casa ${vm.householdText.trim()} ${vm.selectedUnit?.label ?? ''} y '
              'el resto para vender',
        HarvestDestination.other => 'Otro destino',
        null => '-',
      };

  static String _residueLabel(RecordHarvestViewModel vm) =>
      switch (vm.residueUse) {
        ResidueUse.compost => 'Compost',
        ResidueUse.otherUse => 'Otro uso',
        ResidueUse.notUsed => 'No se usó',
        null => 'Sin respuesta',
      };
}
