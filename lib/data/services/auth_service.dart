/// Raw authentication and profile access.
///
/// Implementations throw `AuthFailureException` for failures the repository
/// can classify (invalid credentials, offline); anything else is unknown.
abstract interface class AuthService {
  /// Signs in and returns the user id.
  Future<String> signInWithPassword({
    required String email,
    required String password,
  });

  /// Id of the user whose session is persisted on this device, read without
  /// touching the network; null when nobody is signed in.
  String? restoredUserId();

  /// Ends the session on this device (works offline).
  Future<void> signOut();

  /// The `profiles` row of [userId], or null when it does not exist.
  Future<Map<String, dynamic>?> fetchProfile(String userId);

  /// `farmers.id` of the farmer linked to [userId], or null.
  Future<String?> fetchFarmerId(String userId);

  /// Zones assigned to [userId] (`user_zones`).
  Future<List<String>> fetchZoneIds(String userId);
}
