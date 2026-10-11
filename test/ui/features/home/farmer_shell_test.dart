import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/ui/core/theme/app_theme.dart';
import 'package:hackathon/ui/features/home/views/farmer_shell.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: FarmerShell(
          home: const Scaffold(body: Text('Vista inicio')),
          activities: const Scaffold(body: Text('Vista actividades')),
          reports: const Scaffold(body: Text('Vista reportes')),
          assistances: const Scaffold(body: Text('Vista asistencias')),
          reportBuilder: (_) => const Scaffold(body: Text('Flujo reportar')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the four tab labels and the report FAB', (tester) async {
    await pumpShell(tester);

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Actividades'), findsOneWidget);
    expect(find.text('Reportes'), findsOneWidget);
    expect(find.text('Asistencias'), findsOneWidget);
    expect(find.text('Reportar'), findsOneWidget);
    expect(find.text('Vista inicio'), findsOneWidget);
  });

  testWidgets('switching tabs shows the matching body', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.text('Actividades'));
    await tester.pumpAndSettle();
    expect(find.text('Vista actividades'), findsOneWidget);

    await tester.tap(find.text('Reportes'));
    await tester.pumpAndSettle();
    expect(find.text('Vista reportes'), findsOneWidget);

    await tester.tap(find.text('Asistencias'));
    await tester.pumpAndSettle();
    expect(find.text('Vista asistencias'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Vista inicio'), findsOneWidget);
  });

  testWidgets('the report FAB pushes the report flow without leaving home', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Reportar'));
    await tester.pumpAndSettle();

    expect(find.text('Flujo reportar'), findsOneWidget);
    Navigator.of(tester.element(find.text('Flujo reportar'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Vista inicio'), findsOneWidget);
  });
}
