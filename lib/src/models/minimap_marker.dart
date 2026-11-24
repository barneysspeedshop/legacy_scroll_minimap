import 'package:material_ui/material_ui.dart';

/// A colored span drawn on the minimap track.
@immutable
class MinimapMarker {
  /// A unique identifier for this marker.
  final String id;

  /// The first line covered by this marker (inclusive).
  final int startLine;

  /// The last line covered by this marker (exclusive).
  final int endLine;

  /// The color used to draw this marker.
  final Color? color;

  /// The start position along the cross-axis, from 0.0 to 1.0.
  final double? startRatio;

  /// The end position along the cross-axis, from 0.0 to 1.0.
  final double? endRatio;

  /// Creates a new [MinimapMarker].
  const MinimapMarker({
    required this.id,
    required this.startLine,
    required this.endLine,
    this.color,
    this.startRatio,
    this.endRatio,
  });

  /// Creates a copy of this marker with the given fields replaced.
  MinimapMarker copyWith({
    String? id,
    int? startLine,
    int? endLine,
    Color? color,
    double? startRatio,
    double? endRatio,
  }) => MinimapMarker(
    id: id ?? this.id,
    startLine: startLine ?? this.startLine,
    endLine: endLine ?? this.endLine,
    color: color ?? this.color,
    startRatio: startRatio ?? this.startRatio,
    endRatio: endRatio ?? this.endRatio,
  );
}
