import 'package:flutter/material.dart';

class AssistanceView extends StatelessWidget {
  const AssistanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis asistencias')),
      body: const Center(child: Text('Próximamente')),
    );
  }
}
