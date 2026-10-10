import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ui/core/theme/app_theme.dart';
import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/home/views/home_view.dart';
import 'ui/features/welcome/views/welcome_view.dart';

class AgroApp extends StatelessWidget {
  const AgroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroApp',
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => WelcomeView(
          onStart: () => Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (_) => const _Home())),
        ),
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HomeViewModel(
        outboxRepository: context.read(),
        syncEngine: context.read(),
      ),
      builder: (context, _) =>
          HomeView(viewModel: context.read<HomeViewModel>()),
    );
  }
}
