import '../../../../data/repositories/assistance_repository.dart';
import '../../../../domain/models/assistance.dart';
import '../../../../utils/result.dart';
import '../../../core/widgets/stream_view_model.dart';

/// One assistance read from the device, with the "ya lo hice" confirmation.
class AssistanceDetailViewModel extends StreamViewModel<AssistanceDetail?> {
  AssistanceDetailViewModel({
    required AssistanceRepository repository,
    required String assistanceId,
  }) : _repository = repository,
       super(stream: repository.watchAssistance(assistanceId), initial: null);

  final AssistanceRepository _repository;
  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  Future<String?> documentUrl(String storagePath) =>
      _repository.documentUrl(storagePath);

  /// Marks a recommendation as applied (saved on the device).
  Future<void> confirm(String recommendationId) async {
    final result = await _repository.confirmRecommendation(recommendationId);
    _errorMessage = switch (result) {
      Ok() => null,
      Error() => 'No se pudo guardar. Intente otra vez',
    };
    notifyListeners();
  }
}
