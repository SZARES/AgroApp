/// Lifecycle of a reported problem (`incident_status` enum on the backend).
enum IncidentStatus {
  reported('reported'),
  underReview('under_review'),
  visitScheduled('visit_scheduled'),
  attended('attended'),
  closed('closed');

  const IncidentStatus(this.wire);

  /// Value stored in `incidents.status`.
  final String wire;

  bool get isOpen => this != closed;

  static IncidentStatus? tryParse(Object? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}
