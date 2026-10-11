import 'package:flutter/material.dart';

import '../../../../domain/models/admin/catalog_defs.dart';

/// Dropdown that switches between the admin sections.
class AdminSectionSwitcher extends StatelessWidget {
  const AdminSectionSwitcher({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });

  final String selectedId;
  final ValueChanged<String> onChanged;

  IconData _sectionIcon(String id) {
    return switch (id) {
      'users' => Icons.people_outline,
      'zones' => Icons.map_outlined,
      'crops' => Icons.eco_outlined,
      'activity_types' => Icons.task_alt_outlined,
      'units' => Icons.straighten_outlined,
      'products' => Icons.inventory_2_outlined,
      'symptoms' => Icons.pest_control_outlined,
      'pruning_types' => Icons.content_cut_outlined,
      'assistance' => Icons.support_agent_outlined,
      'expenses' => Icons.receipt_long_outlined,
      'buyers' => Icons.store_outlined,
      'prices' => Icons.monetization_on_outlined,
      'equivalences' => Icons.balance_outlined,
      'settings' => Icons.settings_outlined,
      'audit' => Icons.history_edu_outlined,
      _ => Icons.tune,
    };
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: const ValueKey('admin_section_switcher'),
      initialValue: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Sección',
        isDense: true,
        prefixIcon: Icon(Icons.tune),
      ),
      items: [
        for (final section in CatalogDefs.sections)
          DropdownMenuItem(
            value: section.id,
            child: Row(
              children: [
                Icon(_sectionIcon(section.id), size: 18),
                const SizedBox(width: 10),
                Text(section.title),
              ],
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null && value != selectedId) onChanged(value);
      },
    );
  }
}

