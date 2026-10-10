import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hackathon/screens/welcome_screen.dart';

void main() {
  testWidgets('Welcome screen shows branding and start button', (WidgetTester tester) async {
    var started = false;
    await tester.pumpWidget(
      MaterialApp(home: WelcomeScreen(onStart: () => started = true)),
    );

    expect(find.text('AgroApp'), findsOneWidget);
    expect(find.text('Tu parcela, nuestro compromiso'), findsOneWidget);

    await tester.tap(find.text('Comenzar'));
    expect(started, isTrue);
  });
}
