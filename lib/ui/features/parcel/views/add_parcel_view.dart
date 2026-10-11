import 'package:flutter/material.dart';

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
        final location = vm.location;
        return [
          Text('¿Dónde está su terreno?', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Párese dentro del terreno y toque el botón.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (location != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF8BD450)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ubicación guardada',
                        style: textTheme.bodyLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: vm.clearLocation,
                      child: const Text('Quitar'),
                    ),
                  ],
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: vm.isBusy ? null : vm.useDeviceLocation,
              icon: const Icon(Icons.my_location, size: 28),
              label: const Text('Usar mi ubicación'),
            ),
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
      'Todavía no sabemos su zona. Conéctese a internet una vez e intente '
          'de nuevo',
    AddParcelError.saveFailed =>
      'No se pudo guardar el terreno. Intente de nuevo',
    AddParcelError.locationDenied =>
      'Permita el uso de la ubicación para continuar',
    AddParcelError.locationDisabled => 'Active la ubicación del teléfono',
    AddParcelError.locationUnavailable =>
      'No se pudo obtener la ubicación. Intente de nuevo',
  };
}
