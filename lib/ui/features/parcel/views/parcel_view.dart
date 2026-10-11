import 'package:flutter/material.dart';

import '../../../../domain/models/parcel.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/field_map.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../view_models/add_parcel_view_model.dart';
import '../view_models/parcel_map_projection.dart';
import '../view_models/parcel_view_model.dart';
import 'add_parcel_view.dart';

class ParcelView extends StatelessWidget {
  const ParcelView({
    super.key,
    required this.viewModel,
    required this.addParcelViewModelBuilder,
  });

  final ParcelViewModel viewModel;

  /// Creates the state of one "Agregar terreno" flow.
  final AddParcelViewModel Function() addParcelViewModelBuilder;

  Future<void> _addParcel(BuildContext context) async {
    final addViewModel = addParcelViewModelBuilder();
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AddParcelView(viewModel: addViewModel),
      ),
    );
    // The flow's state holds no subscriptions, so it is simply dropped; the
    // route may still be animating out and listening to it.
    if (saved == true && context.mounted) {
      showAppSnackBar(context, 'Terreno guardado en su teléfono');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi parcela')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (viewModel.loadFailed) {
              return const EmptyState(
                icon: Icons.error_outline,
                title: 'No pudimos cargar sus terrenos',
                message: 'Cierre esta pantalla y vuelva a abrirla.',
              );
            }
            return _Content(
              viewModel: viewModel,
              onAdd: () => _addParcel(context),
            );
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.viewModel, required this.onAdd});

  final ParcelViewModel viewModel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final parcels = viewModel.parcels;

    if (parcels.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 24),
          const EmptyState(
            icon: Icons.landscape_outlined,
            title: 'Aún no tiene terrenos',
            message: 'Agregue su primer terreno para empezar.',
          ),
          const SizedBox(height: 24),
          PrimaryActionButton(
            label: 'Agregar terreno',
            icon: Icons.add_location_alt_outlined,
            onPressed: onAdd,
          ),
        ],
      );
    }

    final map = projectParcels(parcels);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (map.fields.isNotEmpty) ...[
          FieldMap(fields: map.fields, pins: map.pins, onAddField: onAdd),
          const SizedBox(height: 24),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total de terrenos', style: textTheme.titleMedium),
                Text(
                  '${_hectares(viewModel.totalHectares)} ha',
                  style: textTheme.headlineMedium,
                ),
                Text(
                  parcels.length == 1
                      ? '1 terreno'
                      : '${parcels.length} terrenos',
                  style: textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Mis terrenos', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final parcel in parcels) ...[
          _ParcelCard(parcel: parcel),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        PrimaryActionButton(
          label: 'Agregar terreno',
          icon: Icons.add_location_alt_outlined,
          onPressed: onAdd,
        ),
      ],
    );
  }
}

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({required this.parcel});

  final Parcel parcel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badge = _badgeFor(parcel);
    final details = [
      if (parcel.cropName != null) 'Cultivo: ${parcel.cropName}',
      if (parcel.areaHectares != null) '${_hectares(parcel.areaHectares!)} ha',
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(parcel.name, style: textTheme.titleMedium),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(details, style: textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusBadge(label: badge.label, color: badge.color),
          ],
        ),
      ),
    );
  }

  static ({String label, Color color}) _badgeFor(Parcel parcel) {
    if (parcel.openIncidents > 0) {
      return (label: 'Revisar', color: const Color(0xFFFFA040));
    }
    if (parcel.pendingSync) {
      return (label: 'Por enviar', color: const Color(0xFFB0BEC5));
    }
    return (label: 'Bien', color: const Color(0xFF8BD450));
  }
}

String _hectares(double value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',');
}
