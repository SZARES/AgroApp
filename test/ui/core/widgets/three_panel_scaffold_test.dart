import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/ui/core/widgets/three_panel_scaffold.dart';

void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: ThreePanelScaffold(
          title: Text('Titulo'),
          sidebar: ColoredBox(color: Colors.red, child: Text('SIDEBAR')),
          listPanel: ColoredBox(color: Colors.green, child: Text('LIST')),
          mainArea: ColoredBox(
            key: Key('main'),
            color: Colors.blue,
            child: SizedBox.expand(child: Text('MAIN')),
          ),
        ),
      ),
    );
  }

  testWidgets('wide layout shows the three panels side by side', (
    tester,
  ) async {
    await pump(tester, const Size(1300, 800));

    expect(find.text('SIDEBAR'), findsOneWidget);
    expect(find.text('LIST'), findsOneWidget);
    expect(find.text('MAIN'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(
      tester.getTopLeft(find.text('LIST')).dx,
      lessThan(tester.getTopLeft(find.text('MAIN')).dx),
    );
  });

  testWidgets('narrow layout gives the main area the full width', (
    tester,
  ) async {
    await pump(tester, const Size(420, 800));

    expect(find.text('MAIN'), findsOneWidget);
    expect(find.text('SIDEBAR'), findsNothing);
    expect(find.text('LIST'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('main'))).width, 420);
  });

  testWidgets('narrow layout moves sidebar and list into a drawer', (
    tester,
  ) async {
    await pump(tester, const Size(420, 800));

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('SIDEBAR'), findsOneWidget);
    expect(find.text('LIST'), findsOneWidget);
  });

  testWidgets('exactly 900 px is already wide', (tester) async {
    await pump(tester, const Size(900, 800));

    expect(find.byType(Drawer), findsNothing);
    expect(find.text('LIST'), findsOneWidget);
  });
}
