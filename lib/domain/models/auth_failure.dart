/// Why a sign-in or session restore did not produce a user.
enum AuthFailure {
  /// Wrong email or password.
  invalidCredentials,

  /// The account exists but is not active (inactive or suspended).
  inactiveAccount,

  /// Signed in, but no profile row exists for this account.
  noProfile,

  /// No connection. A user who never signed in on this device cannot sign in
  /// offline.
  offline,

  /// The server ended the session (for example an expired refresh token)
  /// while the app was online. The person must sign in again.
  sessionExpired,

  unknown,
}

/// Carries an [AuthFailure] through the `Result` error channel.
class AuthFailureException implements Exception {
  const AuthFailureException(this.failure, [this.cause]);

  final AuthFailure failure;
  final Object? cause;

  @override
  String toString() => 'AuthFailureException(${failure.name}, $cause)';
}

/// A plain sign-out would discard records that were never uploaded.
class PendingDataBlocksSignOut implements Exception {
  const PendingDataBlocksSignOut(this.unsentCount);

  final int unsentCount;

  @override
  String toString() => 'PendingDataBlocksSignOut($unsentCount)';
}
