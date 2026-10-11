import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/ui/core/widgets/skeleton.dart';

void main() {
  Widget host(Widget child, {bool disableAnimations = false}) => MaterialApp(
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: app!,
    ),
    home: Scaffold(body: child),
  );

  testWidgets('announces "Cargando" once and hides its shapes', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const SkeletonList(count: 3)));

    expect(find.bySemanticsLabel('Cargando'), findsOneWidget);
    expect(find.byType(SkeletonCard), findsNWidgets(3));
    handle.dispose();
  });

  testWidgets('pulses by default', (tester) async {
    await tester.pumpWidget(host(const SkeletonList()));
    final before = tester.widget<Container>(
      find.descendant(
        of: find.byType(SkeletonBox).first,
        matching: find.byType(Container),
      ),
    );

    await tester.pump(const Duration(milliseconds: 450));
    final after = tester.widget<Container>(
      find.descendant(
        of: find.byType(SkeletonBox).first,
        matching: find.byType(Container),
      ),
    );

    expect(tester.hasRunningAnimations, isTrue);
    expect(
      (before.decoration as BoxDecoration).color,
      isNot((after.decoration as BoxDecoration).color),
    );
  });

  testWidgets('stays still when the platform asks for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const SkeletonList(), disableAnimations: true),
    );

    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('a lone box outside a Skeleton is static', (tester) async {
    await tester.pumpWidget(
      host(const SkeletonBox(width: 40, height: 40)),
    );

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('works inside a scrollable (unbounded height)', (tester) async {
    await tester.pumpWidget(
      host(
        ListView(children: const [SkeletonList(count: 2)]),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SkeletonCard), findsNWidgets(2));
  });
}
