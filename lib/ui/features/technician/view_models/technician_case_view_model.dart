import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/technician_repository.dart';
import '../../../../domain/models/technician_case.dart';
import '../../../../utils/result.dart';

/// One case and the actions the technician can take on it.
class TechnicianCaseViewModel extends ChangeNotifier {
  TechnicianCaseViewModel({
    required TechnicianRepository repository,
    required this.caseId,
  }) : _repository = repository {
    _detailSubscription = repository.watchCase(caseId).listen(
      (detail) {
        _detail = detail;
        _isLoading = false;
        _loadFailed = false;
        notifyListeners();
      },
      onError: (Object _) {
        _isLoading = false;
        _loadFailed = true;
        notifyListeners();
      },
    );
    _catalogSubscription = repository.watchAssistanceCatalog().listen(
      (catalog) {
        _catalog = List.unmodifiable(catalog);
        notifyListeners();
      },
      onError: (Object _) {},
    );
  }

  final String caseId;
  final TechnicianRepository _repository;
  late final StreamSubscription<TechnicianCaseDetail?> _detailSubscription;
  late final StreamSubscription<List<AssistanceCategoryOption>>
  _catalogSubscription;

  TechnicianCaseDetail? _detail;
  List<AssistanceCategoryOption> _catalog = const [];
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isBusy = false;
  bool _disposed = false;

  TechnicianCaseDetail? get detail => _detail;
  List<AssistanceCategoryOption> get catalog => _catalog;
  bool get isLoading => _isLoading;
  bool get loadFailed => _loadFailed;

  /// True while an action is being saved on the device.
  bool get isBusy => _isBusy;

  Future<String?> photoUrl(String storagePath) =>
      _repository.photoUrl(storagePath);

  Future<Result<void>> takeCase() => _run(() => _repository.takeCase(caseId));

  Future<Result<void>> scheduleVisit({
    required DateTime date,
    String? comment,
  }) => _run(
    () => _repository.scheduleVisit(caseId, date: date, comment: comment),
  );

  Future<Result<void>> registerAssistance(AssistanceDraft draft) =>
      _run(() => _repository.registerAssistance(caseId, draft));

  Future<Result<void>> addRecommendation({
    required String text,
    DateTime? dueDate,
  }) => _run(
    () => _repository.addRecommendation(caseId, text: text, dueDate: dueDate),
  );

  Future<Result<void>> confirmRecommendation(String recommendationId) =>
      _run(() => _repository.confirmRecommendation(recommendationId));

  Future<Result<void>> markAttended({String? comment}) =>
      _run(() => _repository.markAttended(caseId, comment: comment));

  Future<Result<void>> closeCase({String? comment}) =>
      _run(() => _repository.closeCase(caseId, comment: comment));

  Future<Result<void>> _run(Future<Result<void>> Function() action) async {
    if (_isBusy) {
      return const Result.error(
        TechnicianException(TechnicianFailure.invalidTransition),
      );
    }
    _isBusy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _isBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_detailSubscription.cancel());
    unawaited(_catalogSubscription.cancel());
    super.dispose();
  }
}
