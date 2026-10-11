/// Why an administration action did not complete.
enum AdminFailure {
  /// No connection: admin changes need the internet.
  offline,

  /// The server refused the action (not an admin, or RLS).
  forbidden,

  /// A unique value (for example a code) already exists.
  duplicate,

  /// The server rejected the data; [AdminFailureException.message] explains.
  invalid,

  /// The affected record does not exist.
  notFound,

  unknown,
}

/// Carries an [AdminFailure] through the `Result` error channel.
class AdminFailureException implements Exception {
  const AdminFailureException(this.failure, [this.serverMessage, this.cause]);

  final AdminFailure failure;

  /// Message the server sent (already in Spanish for the Edge Functions).
  final String? serverMessage;
  final Object? cause;

  static const offlineMessage =
      'Necesita conexión a internet para guardar cambios de administración.';

  /// Friendly Spanish text for the UI.
  String get message => switch (failure) {
    AdminFailure.offline => offlineMessage,
    AdminFailure.forbidden => 'No tiene permiso para hacer este cambio.',
    AdminFailure.duplicate => 'Ya existe un registro con ese código.',
    AdminFailure.invalid =>
      serverMessage ?? 'Revise los datos e intente de nuevo.',
    AdminFailure.notFound => 'No se encontró el registro.',
    AdminFailure.unknown =>
      serverMessage ?? 'No se pudo completar la acción. Intente de nuevo.',
  };

  @override
  String toString() => 'AdminFailureException(${failure.name}, $serverMessage)';
}
