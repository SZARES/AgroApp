/// Why a parcel could not be saved.
enum ParcelFailure implements Exception {
  invalidName,
  invalidArea,

  /// No zone could be derived for the farmer (no parcel or community synced).
  noZone,
  saveFailed,
}
