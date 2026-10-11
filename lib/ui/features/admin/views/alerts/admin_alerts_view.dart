import 'package:flutter/material.dart';

import '../../../../../data/repositories/admin_repository.dart';
import '../../../../core/widgets/aider_shell.dart';
import '../admin_widgets.dart';
import '../audit/audit_section.dart';

/// Alerts, system integrity, and full audit trail for the admin console.
class AdminAlertsView extends StatefulWidget {
  const AdminAlertsView({
    super.key,
    required this.repository,
    required this.panelsBuilder,
  });

  final AdminRepository repository;
  final AdminPanelsBuilder panelsBuilder;

  @override
  State<AdminAlertsView> createState() => _AdminAlertsViewState();
}

class _AdminAlertsViewState extends State<AdminAlertsView> {
  int _unvalidatedEquivalences = 0;

  @override
  void initState() {
    super.initState();
    _checkSystemIntegrity();
  }

  void _checkSystemIntegrity() {
    widget.repository.watchRows('unit_equivalences').listen((rows) {
      if (!mounted) return;
      final pending = rows.where((r) => r['validated'] != true).length;
      setState(() => _unvalidatedEquivalences = pending);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuditSection(
      key: const ValueKey('admin_alerts_audit_section'),
      repository: widget.repository,
      switcher: _buildAlertsHeader(),
      panelsBuilder: (listPanel, mainArea) {
        return widget.panelsBuilder(
          listPanel,
          AiderMainArea(
            child: Column(
              children: [
                if (_unvalidatedEquivalences > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber.shade900,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Atención: Hay $_unvalidatedEquivalences equivalencias de unidades pendientes de validación oficial.',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(child: mainArea),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlertsHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 16, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Trazabilidad en tiempo real',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
