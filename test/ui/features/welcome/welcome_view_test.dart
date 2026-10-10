import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/ui/features/welcome/views/welcome_view.dart';

void main() {
  Future<void> pumpWelcome(
    WidgetTester tester, {
    required Size size,
    VoidCallback? onStart,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: WelcomeView(onStart: onStart ?? () {})),
    );
  }

  String backgroundOf(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image));
    return (image.image as AssetImage).assetName;
  }

  testWidgets('shows brand, tagline and the start action', (tester) async {
    await pumpWelcome(tester, size: const Size(400, 800));

    expect(find.text('AgroApp'), findsOneWidget);
    expect(find.text('Tu parcela, nuestro compromiso'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Comenzar'), findsOneWidget);
  });

  testWidgets('uses the mobile background on a portrait phone', (tester) async {
    await pumpWelcome(tester, size: const Size(400, 800));

    expect(backgroundOf(tester), WelcomeView.mobileBackground);
  });

  testWidgets('uses the web background on a wide screen', (tester) async {
    await pumpWelcome(tester, size: const Size(1366, 768));

    expect(backgroundOf(tester), WelcomeView.webBackground);
  });

  testWidgets('keeps the mobile background on a tall tablet', (tester) async {
    await pumpWelcome(tester, size: const Size(800, 1280));

    expect(backgroundOf(tester), WelcomeView.mobileBackground);
  });

  testWidgets('tapping "Comenzar" calls onStart', (tester) async {
    var started = 0;
    await pumpWelcome(
      tester,
      size: const Size(400, 800),
      onStart: () => started++,
    );

    await tester.tap(find.text('Comenzar'));

    expect(started, 1);
  });
}
