import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hackathon/domain/models/geo_point.dart';
import 'package:hackathon/domain/models/parcel.dart';
import 'package:hackathon/ui/core/theme/app_theme.dart';
import 'package:hackathon/ui/core/widgets/field_map.dart';
import 'package:hackathon/ui/features/parcel/view_models/add_parcel_view_model.dart';
import 'package:hackathon/ui/features/parcel/view_models/parcel_view_model.dart';
import 'package:hackathon/ui/features/parcel/views/parcel_view.dart';

import '../../../testing/home_fakes.dart';

void main() {
  Future<FakeParcelRepository> pumpParcels(
    WidgetTester tester,
    List<Parcel> parcels, {
    bool withLocation = false,
  }) async {
    final repository = FakeParcelRepository(parcels);
    final viewModel = ParcelViewModel(repository: repository);
    addTearDown(viewModel.dispose);
    tester.view.physicalSize = const Size(600, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ParcelView(
          viewModel: viewModel,
          addParcelViewModelBuilder: () => AddParcelViewModel(
            repository: repository,
            locationRepository: withLocation ? FakeLocationRepository() : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('shows an empty state with a way to add land', (tester) async {
    await pumpParcels(tester, const []);

    expect(find.text('Aún no tiene terrenos'), findsOneWidget);
    expect(find.text('Agregar terreno'), findsOneWidget);
    expect(find.byType(FieldMap), findsNothing);
  });

  testWidgets('lists parcels from the repository and draws them on the map', (
    tester,
  ) async {
    await pumpParcels(tester, const [
      Parcel(
        id: 'a',
        name: 'Campo del pozo',
        areaHectares: 1.5,
        cropName: 'Limón',
        center: GeoPoint(latitude: -5.1, longitude: -80.6),
      ),
      Parcel(
        id: 'b',
        name: 'Campo nuevo',
        areaHectares: 0.5,
        pendingSync: true,
      ),
    ]);

    expect(find.byType(FieldMap), findsOneWidget);
    // Once on the map label and once in the list.
    expect(find.text('Campo del pozo'), findsNWidgets(2));
    expect(find.text('Cultivo: Limón · 1,5 ha'), findsOneWidget);
    expect(find.text('2 ha'), findsOneWidget);
    expect(find.text('Por enviar'), findsOneWidget);
    expect(find.text('Bien'), findsOneWidget);
  });

  testWidgets('add flow asks one question per screen and saves locally', (
    tester,
  ) async {
    final repository = await pumpParcels(tester, const []);

    await tester.tap(find.text('Agregar terreno'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo se llama su terreno?'), findsOneWidget);
    expect(find.text('¿Cuántas hectáreas tiene?'), findsNothing);

    await tester.tap(find.text('Siguiente'));
    await tester.pump();
    expect(find.text('Escriba el nombre del terreno'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Campo del cerro');
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cuántas hectáreas tiene?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '2,5');
    await tester.tap(find.text('Guardar terreno'));
    await tester.pumpAndSettle();

    expect(repository.added.single.name, 'Campo del cerro');
    expect(repository.added.single.area, 2.5);
    expect(find.text('Terreno guardado en su teléfono'), findsOneWidget);
    expect(find.text('¿Cuántas hectáreas tiene?'), findsNothing);
  });

  testWidgets('add flow offers device location when available', (tester) async {
    final repository = await pumpParcels(tester, const [], withLocation: true);

    await tester.tap(find.text('Agregar terreno'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Campo');
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('¿Dónde está su terreno?'), findsOneWidget);
    expect(find.text('Guardar sin ubicación'), findsOneWidget);

    await tester.tap(find.text('Usar mi ubicación'));
    await tester.pumpAndSettle();
    expect(find.text('Ubicación guardada'), findsOneWidget);

    await tester.tap(find.text('Guardar terreno'));
    await tester.pumpAndSettle();

    expect(
      repository.added.single.location,
      const GeoPoint(latitude: -5.19, longitude: -80.63),
    );
  });
}
