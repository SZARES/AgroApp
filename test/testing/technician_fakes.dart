import 'dart:async';

import 'package:hackathon/data/repositories/technician_repository.dart';
import 'package:hackathon/domain/models/incident_status.dart';
import 'package:hackathon/domain/models/technician_case.dart';
import 'package:hackathon/domain/models/technician_farmer.dart';
import 'package:hackathon/utils/result.dart';

/// A stream that replays its latest value to every new listener; it emits
/// nothing until the first [add] (so views stay in their loading state).
class Feed<T> {
  Feed();

  T? _value;
  bool _hasValue = false;
  final _controller = StreamController<T>.broadcast();

  void add(T value) {
    _value = value;
    _hasValue = true;
    _controller.add(value);
  }

  void addError(Object error) => _controller.addError(error);

  Stream<T> watch() async* {
    if (_hasValue) yield _value as T;
    yield* _controller.stream;
  }

  Future<void> close() => _controller.close();
}

/// In-memory [TechnicianRepository] driven by the test.
class FakeTechnicianRepository implements TechnicianRepository {
  final cases = Feed<List<TechnicianCase>>();
  final map = Feed<TechnicianMapData>();
  final catalog = Feed<List<AssistanceCategoryOption>>();
  final farmers = Feed<List<TechnicianFarmer>>();
  final kpis = Feed<TechnicianKpis>();
  final farmerDetails = <String, Feed<TechnicianFarmerDetail?>>{};

  /// Arguments of every `registerFieldAssistance` call.
  final fieldAssistances =
      <({String farmerId, String? parcelId, AssistanceDraft draft})>[];
  Result<void> fieldAssistanceResult = const Result.ok(null);

  Feed<TechnicianFarmerDetail?> farmerFeed(String id) =>
      farmerDetails.putIfAbsent(id, Feed.new);

  @override
  Stream<List<TechnicianCase>> watchCases() => cases.watch();

  @override
  Stream<TechnicianMapData> watchMap() => map.watch();

  @override
  Stream<List<AssistanceCategoryOption>> watchAssistanceCatalog() =>
      catalog.watch();

  @override
  Stream<List<TechnicianFarmer>> watchFarmers() => farmers.watch();

  @override
  Stream<TechnicianFarmerDetail?> watchFarmer(String farmerId) =>
      farmerFeed(farmerId).watch();

  @override
  Stream<TechnicianKpis> watchKpis() => kpis.watch();

  @override
  Stream<TechnicianCaseDetail?> watchCase(String id) =>
      Stream<TechnicianCaseDetail?>.value(null);

  @override
  Future<Result<void>> registerFieldAssistance({
    required String farmerId,
    String? parcelId,
    required AssistanceDraft draft,
  }) async {
    fieldAssistances.add((
      farmerId: farmerId,
      parcelId: parcelId,
      draft: draft,
    ));
    return fieldAssistanceResult;
  }

  @override
  Future<String?> photoUrl(String storagePath) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

TechnicianCase fakeCase(
  String id, {
  String farmer = 'Rosa Quispe',
  String symptom = 'Hojas amarillas',
  CasePriority priority = CasePriority.medium,
  IncidentStatus status = IncidentStatus.reported,
}) => TechnicianCase(
  id: id,
  farmerId: 'f-$farmer',
  farmerName: farmer,
  parcelId: 'p-$id',
  parcelName: 'Campo $id',
  symptom: symptom,
  priority: priority,
  status: status,
  reportedAt: DateTime(2026, 10, 1),
  isPending: false,
);
