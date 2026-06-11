import 'package:flutter/material.dart';

/// Visual styling for [ScrollMinimap].
@immutable
class MinimapTheme {
  /// The default color for markers when none is provided.
  final Color markerColor;

  /// The color used for fade gradients and other accents.
  final Color textColor;

  /// The fill color of the visible viewport window.
  final Color viewportColor;

  /// The border color of the visible viewport window.
  final Color viewportBorderColor;

  /// Creates a new [MinimapTheme].
  const MinimapTheme({
    required this.markerColor,
    required this.textColor,
    required this.viewportColor,
    required this.viewportBorderColor,
  });

  /// Creates a copy of this theme with the given fields replaced.
  MinimapTheme copyWith({
    Color? markerColor,
    Color? textColor,
    Color? viewportColor,
    Color? viewportBorderColor,
  }) =>
      MinimapTheme(
        markerColor: markerColor ?? this.markerColor,
        textColor: textColor ?? this.textColor,
        viewportColor: viewportColor ?? this.viewportColor,
        viewportBorderColor: viewportBorderColor ?? this.viewportBorderColor,
      );

  /// Creates a default theme based on the application's [ThemeData].
  factory MinimapTheme.fromTheme(ThemeData theme) => MinimapTheme(
        markerColor: theme.colorScheme.primary.withValues(alpha: 0.5),
        textColor: theme.colorScheme.onSurface,
        viewportColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        viewportBorderColor: theme.colorScheme.primary,
      );
}
