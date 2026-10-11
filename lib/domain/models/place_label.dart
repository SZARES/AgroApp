import 'package:flutter/foundation.dart';

/// Human-readable place for a map pin: short title + supporting line.
@immutable
class PlaceLabel {
  const PlaceLabel({required this.title, this.subtitle = ''});

  /// Main line (street or locality).
  final String title;

  /// Secondary line (district, city, country).
  final String subtitle;

  bool get hasSubtitle => subtitle.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is PlaceLabel &&
      other.title == title &&
      other.subtitle == subtitle;

  @override
  int get hashCode => Object.hash(title, subtitle);
}
