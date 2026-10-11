import 'package:flutter/material.dart';

import '../../../../../data/repositories/admin_repository.dart';
import '../../../../../domain/models/admin/catalog_def.dart';
import '../../../../../domain/models/admin/catalog_defs.dart';
import '../../../../core/widgets/aider_shell.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../view_models/catalog_view_model.dart';
import '../admin_widgets.dart';
import 'catalog_editor.dart';

/// One catalog section (or a pair, like zones + communities): cards on the
/// left, the generic editor on the right.
class CatalogSection extends StatefulWidget {
  const CatalogSection({
    super.key,
    required this.repository,
    required this.section,
    required this.switcher,
    required this.panelsBuilder,
  });

  final AdminRepository repository;
  final AdminSection section;
  final Widget switcher;
  final AdminPanelsBuilder panelsBuilder;

  @override
  State<CatalogSection> createState() => _CatalogSectionState();
}

class _CatalogSectionState extends State<CatalogSection> {
  int _index = 0;
  late AdminCatalogViewModel _viewModel = _create();

  AdminCatalogViewModel _create() => AdminCatalogViewModel(
    repository: widget.repository,
    def: widget.section.catalogs[_index],
  );

  CatalogDef get _def => widget.section.catalogs[_index];

  void _switchCatalog(int index) {
    if (index == _index) return;
    final old = _viewModel;
    setState(() {
      _index = index;
      _viewModel = _create();
    });
    old.dispose();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => widget.panelsBuilder(
        _listPanel(),
        AiderMainArea(
          cta: AiderCtaButton(
            label: 'Agregar ${_def.singular}',
            icon: Icons.add,
            onPressed: _viewModel.startCreate,
          ),
          child: _main(),
        ),
      ),
    );
  }

  Widget _listPanel() {
    final vm = _viewModel;
    final scheme = Theme.of(context).colorScheme;
    final catalogs = widget.section.catalogs;
    return AiderListPanel(
      key: ValueKey('catalog_list_${_def.id}'),
      title: _def.title,
      emptyMessage:
          'Todavía no hay ${_def.title.toLowerCase()}. '
          'Use "Agregar ${_def.singular}".',
      header: Column(
        children: [
          widget.switcher,
          if (catalogs.length > 1) ...[
            const SizedBox(height: 8),
            SegmentedButton<int>(
              key: const ValueKey('catalog_switcher'),
              showSelectedIcon: false,
              segments: [
                for (var i = 0; i < catalogs.length; i++)
                  ButtonSegment(value: i, label: Text(catalogs[i].title)),
              ],
              selected: {_index},
              onSelectionChanged: (value) => _switchCatalog(value.first),
            ),
          ],
        ],
      ),
      items: [
        for (final row in vm.rows)
          AiderListItem(
            id: '${row[_def.idColumn]}',
            title: vm.title(row),
            subtitle: vm.subtitle(row).isEmpty ? null : vm.subtitle(row),
            footer: vm.isActive(row)
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AdminChip('Inactivo', color: scheme.errorContainer),
                  ),
          ),
      ],
      selectedId: vm.creating ? null : vm.selectedId,
      onSelect: vm.select,
      body: vm.loading
          ? const AdminLoading()
          : vm.hasLoadError
          ? AdminLoadError(onRetry: vm.retry)
          : null,
    );
  }

  Widget _main() {
    final vm = _viewModel;
    if (vm.creating) {
      return CatalogEditor(
        key: ValueKey('new_${_def.id}'),
        viewModel: vm,
        row: null,
      );
    }
    final row = vm.selected;
    if (row != null) {
      return CatalogEditor(
        key: ValueKey('edit_${_def.id}_${vm.selectedId}'),
        viewModel: vm,
        row: row,
      );
    }
    return EmptyState(
      icon: Icons.list_alt,
      title: _def.title,
      message: 'Elija un elemento de la lista o agregue uno nuevo.',
    );
  }
}
