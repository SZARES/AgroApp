import 'package:flutter/material.dart';

import '../../../core/widgets/primary_action_button.dart';
import '../../../mock/mock_data.dart';
import 'case_status_view.dart';

class IncidentPhotoView extends StatefulWidget {
  const IncidentPhotoView({super.key, required this.problem});

  final String problem;

  @override
  State<IncidentPhotoView> createState() => _IncidentPhotoViewState();
}

class _IncidentPhotoViewState extends State<IncidentPhotoView> {
  bool _hasPhoto = false;

  void _sendReport() {
    final newCase = MockCase(
      id: 'C-016',
      problem: widget.problem,
      field: 'Campo de la quebrada',
      reportedAt: 'Hoy',
      status: CaseStatus.reported,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CaseStatusView(caseItem: newCase),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Foto del problema')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _hasPhoto ? Icons.image : Icons.photo_camera_outlined,
                        size: 96,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _hasPhoto
                            ? 'Foto lista'
                            : 'Tome una foto de la planta con el problema',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => _hasPhoto = true),
                icon: const Icon(Icons.camera_alt, size: 28),
                label: Text(_hasPhoto ? 'Tomar otra foto' : 'Tomar foto'),
              ),
              const SizedBox(height: 16),
              PrimaryActionButton(
                label: 'Enviar reporte',
                icon: Icons.send,
                onPressed: _hasPhoto ? _sendReport : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
