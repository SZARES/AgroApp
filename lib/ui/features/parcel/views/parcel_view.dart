import 'package:flutter/material.dart';

import '../../../../domain/models/parcel.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../view_models/add_parcel_view_model.dart';
import '../view_models/parcel_view_model.dart';
import 'add_parcel_view.dart';
import 'parcel_detail_view.dart';

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
    if (saved == true && context.mounted) {
      showAppSnackBar(context, 'Terreno guardado en su teléfono');
    }
  }

  void _openDetail(BuildContext context, Parcel parcel) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ParcelDetailView(parcel: parcel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis terrenos')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            if (viewModel.isLoading) {
              return const Center(
                child: AppLoadingCard(message: 'Cargando terrenos…'),
              );
            }
            if (viewModel.loadFailed) {
              return const EmptyState(
                icon: Icons.error_outline,
                title: 'No pudimos cargar sus terrenos',
                message: 'Cierre esta pantalla y vuelva a abrirla.',
              );
            }
            return _Content(
              parcels: viewModel.parcels,
              onAdd: () => _addParcel(context),
              onOpen: (parcel) => _openDetail(context, parcel),
            );
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.parcels,
    required this.onAdd,
    required this.onOpen,
  });

  final List<Parcel> parcels;
  final VoidCallback onAdd;
  final ValueChanged<Parcel> onOpen;

  @override
  Widget build(BuildContext context) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.92,
            ),
            itemCount: parcels.length,
            itemBuilder: (context, index) {
              final parcel = parcels[index];
              return _ParcelGridTile(
                parcel: parcel,
                onTap: () => onOpen(parcel),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: PrimaryActionButton(
            label: 'Agregar terreno',
            icon: Icons.add_location_alt_outlined,
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}

class _ParcelGridTile extends StatelessWidget {
  const _ParcelGridTile({required this.parcel, required this.onTap});

  final Parcel parcel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = parcelStatusBadge(context, parcel);
    final hint = parcel.cropName ??
        (parcel.areaHectares == null
            ? null
            : '${formatHectares(parcel.areaHectares!)} ha');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      parcel.hasLocation
                          ? Icons.map_outlined
                          : Icons.landscape_outlined,
                      size: 36,
                      color: scheme.primary,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: status.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.surfaceContainerHigh,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                parcel.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 4),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Status chip colors come from the app [ColorScheme], not fixed hex values.
({String label, Color color}) parcelStatusBadge(
  BuildContext context,
  Parcel parcel,
) {
  final scheme = Theme.of(context).colorScheme;
  if (parcel.openIncidents > 0) {
    return (label: 'Revisar', color: scheme.secondary);
  }
  if (parcel.pendingSync) {
    return (label: 'Por enviar', color: scheme.onSurfaceVariant);
  }
  return (label: 'Bien', color: scheme.primary);
}

/// "1,5" style hectares for farmers.
String formatHectares(double value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '').replaceAll('.', ',');
}
