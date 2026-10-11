import 'package:flutter/material.dart';

import '../../../core/widgets/field_map.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../view_models/add_parcel_view_model.dart';

/// "Agregar terreno": one question per screen (name, area, location).
/// Pops with `true` once the land is saved.
class AddParcelView extends StatefulWidget {
  const AddParcelView({super.key, required this.viewModel});

  final AddParcelViewModel viewModel;

  @override
  State<AddParcelView> createState() => _AddParcelViewState();
}

class _AddParcelViewState extends State<AddParcelView> {
  late final TextEditingController _name = TextEditingController(
    text: widget.viewModel.name,
  );
  late final TextEditingController _area = TextEditingController(
    text: widget.viewModel.areaText,
  );
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onChanged);
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (widget.viewModel.saved == null || _popped) return;
    _popped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final first = viewModel.step == AddParcelStep.name;
        return PopScope(
          canPop: first,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) viewModel.back();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Agregar terreno'),
              leading: BackButton(
                onPressed: () =>
                    first ? Navigator.of(context).pop() : viewModel.back(),
              ),
            ),
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  ..._questionFor(context, viewModel),
                  const SizedBox(height: 16),
                  if (viewModel.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _messageFor(viewModel.error!),
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  PrimaryActionButton(
                    label: _actionLabel(viewModel),
                    icon:
                        viewModel.step == AddParcelStep.location ||
                            (viewModel.step == AddParcelStep.area &&
                                !viewModel.canAskLocation)
                        ? Icons.check
                        : Icons.arrow_forward,
                    onPressed: viewModel.isBusy ? null : viewModel.next,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _questionFor(BuildContext context, AddParcelViewModel vm) {
    final textTheme = Theme.of(context).textTheme;
    switch (vm.step) {
      case AddParcelStep.name:
        return [
          Text('¿Cómo se llama su terreno?', style: textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            style: textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Ejemplo: Campo del pozo',
            ),
            onChanged: vm.setName,
            onSubmitted: (_) => vm.next(),
          ),
        ];
      case AddParcelStep.area:
        return [
          Text('¿Cuántas hectáreas tiene?', style: textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _area,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Ejemplo: 1,5',
              suffixText: 'hectáreas',
            ),
            onChanged: vm.setArea,
            onSubmitted: (_) => vm.next(),
          ),
        ];
      case AddParcelStep.location:
        final hasPin = vm.location != null;
        return [
          Text('¿Dónde está su terreno?', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            hasPin
                ? 'Toque el mapa para mover el pin, o use su GPS.'
                : 'Toque el mapa para poner el pin, o use su GPS.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FieldMap(
            fields: [
              if (hasPin)
                MapFieldShape(
                  name: vm.name.trim().isEmpty ? 'Terreno' : vm.name.trim(),
                  center: vm.location!,
                ),
            ],
            showIncidentSummary: false,
            height: 280,
            onMapTap: vm.setLocation,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: vm.isBusy ? null : vm.useDeviceLocation,
            icon: const Icon(Icons.my_location, size: 28),
            label: Text(hasPin ? 'Usar mi GPS otra vez' : 'Usar mi ubicación'),
          ),
          if (hasPin) ...[
            const SizedBox(height: 12),
            _LocationReadyCard(viewModel: vm),
          ],
        ];
    }
  }

  static String _actionLabel(AddParcelViewModel vm) {
    return switch (vm.step) {
      AddParcelStep.name => 'Siguiente',
      AddParcelStep.area => vm.canAskLocation ? 'Siguiente' : 'Guardar terreno',
      AddParcelStep.location =>
        vm.location == null ? 'Guardar sin ubicación' : 'Guardar terreno',
    };
  }

  static String _messageFor(AddParcelError error) => switch (error) {
    AddParcelError.invalidName => 'Escriba el nombre del terreno',
    AddParcelError.invalidArea => 'Escriba las hectáreas con números',
    AddParcelError.noZone =>
      'Aún no tenemos su zona. Espere un momento con internet y vuelva a '
          'intentar',
    AddParcelError.saveFailed =>
      'No se pudo guardar el terreno. Intente de nuevo',
    AddParcelError.locationDenied =>
      'Permita el uso de la ubicación para continuar',
    AddParcelError.locationDisabled => 'Active la ubicación del teléfono',
    AddParcelError.locationUnavailable =>
      'No se pudo obtener la ubicación. Intente de nuevo',
  };
}

/// Compact “ubicación lista” card with address title + subtitle underneath.
class _LocationReadyCard extends StatelessWidget {
  const _LocationReadyCard({required this.viewModel});

  final AddParcelViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colors = theme.colorScheme;
    final label = viewModel.placeLabel;
    final lookingUp = viewModel.isLookingUpAddress;
    final point = viewModel.location;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF8BD450)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ubicación lista',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: viewModel.clearLocation,
                  child: const Text('Quitar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: lookingUp
                        ? Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Buscando dirección…',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label?.title ?? 'Punto en el mapa',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                label?.hasSubtitle == true
                                    ? label!.subtitle
                                    : point == null
                                    ? ''
                                    : '${point.latitude.toStringAsFixed(5)}, '
                                          '${point.longitude.toStringAsFixed(5)}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.3,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 34, right: 8),
              child: Text(
                'Toque el mapa para mover el pin',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
