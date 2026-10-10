import 'package:flutter/material.dart';

class HarvestView extends StatelessWidget {
  const HarvestView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar cosecha')),
      body: const Center(child: Text('Próximamente')),
    );
  }
}
