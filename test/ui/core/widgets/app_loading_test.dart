import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/ui/core/theme/app_theme.dart';
import 'package:hackathon/ui/core/widgets/app_loading.dart';

void main() {
  testWidgets('overlay shows the animated card while visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const AppLoadingOverlay(
          visible: true,
          message: 'Guardando…',
          child: Scaffold(body: Text('contenido')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('contenido'), findsOneWidget);
    expect(find.text('Guardando…'), findsOneWidget);
    expect(find.byType(AppLoadingIndicator), findsOneWidget);
  });

  testWidgets('showAppLoading and hideAppLoading open and close the dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showAppLoading(context, message: 'Enviando…'),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Enviando…'), findsOneWidget);

    final context = tester.element(find.text('Enviando…'));
    hideAppLoading(context);
    await tester.pumpAndSettle();

    expect(find.text('Enviando…'), findsNothing);
  });
}
