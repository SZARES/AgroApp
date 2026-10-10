import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ui/core/theme/app_theme.dart';
import 'ui/features/home/view_models/home_view_model.dart';
import 'ui/features/home/views/home_view.dart';

class AgroApp extends StatelessWidget {
  const AgroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroApp',
      theme: AppTheme.light(),
      home: ChangeNotifierProvider(
        create: (context) => HomeViewModel(
          outboxRepository: context.read(),
          syncEngine: context.read(),
        ),
        builder: (context, _) =>
            HomeView(viewModel: context.read<HomeViewModel>()),
      ),
    );
  }
}
