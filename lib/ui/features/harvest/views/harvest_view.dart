import 'package:flutter/material.dart';

import '../../../core/widgets/option_tile.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../../../mock/mock_data.dart';

class HarvestView extends StatefulWidget {
  const HarvestView({super.key});

  @override
  State<HarvestView> createState() => _HarvestViewState();
}

class _HarvestViewState extends State<HarvestView> {
  static const _units = ['saco', 'caja', 'kg', 'atado'];
  static const _destinations = [
    (label: 'Autoconsumo', icon: Icons.home_outlined),
    (label: 'Venta', icon: Icons.sell_outlined),
    (label: 'Acopiador', icon: Icons.local_shipping_outlined),
  ];

  late String _field = mockFields.first.name;
  String _unit = _units.first;
  int? _destination;

  void _save() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Guardado en el celular')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar cosecha')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _field,
              decoration: const InputDecoration(labelText: 'Campo'),
              style: textTheme.titleMedium,
              items: [
                for (final field in mockFields)
                  DropdownMenuItem(value: field.name, child: Text(field.name)),
              ],
              onChanged: (value) => setState(() => _field = value!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  flex: 2,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 22),
                    decoration: InputDecoration(labelText: 'Cantidad'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unit,
                    decoration: const InputDecoration(labelText: 'Unidad'),
                    items: [
                      for (final unit in _units)
                        DropdownMenuItem(value: unit, child: Text(unit)),
                    ],
                    onChanged: (value) => setState(() => _unit = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('¿Dónde fue a parar?', style: textTheme.titleLarge),
            const SizedBox(height: 12),
            for (var i = 0; i < _destinations.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OptionTile(
                  label: _destinations[i].label,
                  icon: _destinations[i].icon,
                  selected: _destination == i,
                  onTap: () => setState(() => _destination = i),
                ),
              ),
            const SizedBox(height: 8),
            PrimaryActionButton(
              label: 'Guardar',
              icon: Icons.save_outlined,
              onPressed: _destination == null ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
