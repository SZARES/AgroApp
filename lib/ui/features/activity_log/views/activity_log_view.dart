import 'package:flutter/material.dart';

class ActivityLogView extends StatelessWidget {
  const ActivityLogView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar lo que hice')),
      body: const Center(child: Text('Próximamente')),
    );
  }
}
