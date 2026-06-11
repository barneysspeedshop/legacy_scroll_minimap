import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'models/minimap_marker.dart';
import 'models/minimap_theme.dart';

/// Indicates which part of the minimap caused a viewport change.
enum MinimapHandle {
  /// The viewport window was dragged.
  scrub,

  /// The change was not caused by a direct interaction (e.g., reset).
  programmatic,
}

enum _DragType { none, scrub, seek }

/// A scroll minimap that shows document markers and the current viewport.
class ScrollMinimap extends StatefulWidget {
  /// The total number of lines in the scrollable content.
  final int totalLineCount;

  /// The first visible line in the viewport (inclusive).
  final int visibleStartLine;

  /// The last visible line in the viewport (exclusive).
  final int visibleEndLine;

  /// Called when the visible line window changes.
  final void Function(int startLine, int endLine, MinimapHandle handle) onWindowChanged;

  /// Called when the user clicks or drags outside the viewport to seek.
  final void Function(int line)? onSeek;

  /// Markers drawn on the minimap track.
  final List<MinimapMarker> markers;

  /// The theme used to paint the minimap.
  final MinimapTheme? theme;

  /// The scroll axis represented by the minimap's primary dimension.
  final Axis orientation;

  /// Whether to show the reset zoom button when the minimap is zoomed.
  final bool showResetZoomButton;

  /// Whether the minimap should always show the full line range.
  final bool alwaysShowFullRange;

  /// Creates a new [ScrollMinimap].
  const ScrollMinimap({
    super.key,
    required this.totalLineCount,
    required this.visibleStartLine,
    required this.visibleEndLine,
    required this.onWindowChanged,
    this.onSeek,
    this.markers = const [],
    this.theme,
    this.orientation = Axis.vertical,
    this.showResetZoomButton = false,
    this.alwaysShowFullRange = true,
  });

  @override
  State<ScrollMinimap> createState() => _ScrollMinimapState();
}

class _ScrollMinimapState extends State<ScrollMinimap> {
  _DragType _dragType = _DragType.none;
  double _dragStartPos = 0.0;
  late double _dragStartVisibleStartValue;
  late double _dragStartVisibleEndValue;
  late double _dragStartDisplayStartValue;
  late double _dragStartDisplayEndValue;
  MouseCursor _cursor = SystemMouseCursors.basic;

  double get _totalStartValue => 0.0;
  double get _totalEndValue => widget.totalLineCount.toDouble();
  double get _visibleStartValue => widget.visibleStartLine.toDouble();
  double get _visibleEndValue => widget.visibleEndLine.toDouble();

  (double, double) _calculateDisplayRange(double visibleStart, double visibleEnd, double dimension) {
    if (widget.alwaysShowFullRange) {
      return (_totalStartValue, _totalEndValue);
    }

    final visibleRange = visibleEnd - visibleStart;
    final totalRange = _totalEndValue - _totalStartValue;

    if (visibleRange >= totalRange) {
      return (_totalStartValue, _totalEndValue);
    }

    final buffer = visibleRange * 0.25;

    double displayStart = visibleStart - buffer;
    double displayEnd = visibleEnd + buffer;

    if (displayStart < _totalStartValue) {
      displayStart = _totalStartValue;
    }
    if (displayEnd > _totalEndValue) {
      displayEnd = _totalEndValue;
    }

    if (displayEnd - displayStart < visibleRange) {
      if (displayStart == _totalStartValue) {
        displayEnd = displayStart + visibleRange;
      } else if (displayEnd == _totalEndValue) {
        displayStart = displayEnd - visibleRange;
      }
    }

    return (
      displayStart.clamp(_totalStartValue, _totalEndValue),
      displayEnd.clamp(_totalStartValue, _totalEndValue),
    );
  }

  _DragType _getDragTypeAtPosition(Offset localPosition, Size size) {
    final dimension = widget.orientation == Axis.horizontal ? size.width : size.height;
    final pos = widget.orientation == Axis.horizontal ? localPosition.dx : localPosition.dy;

    if (dimension == 0) return _DragType.none;

    final (displayStart, displayEnd) = _calculateDisplayRange(_visibleStartValue, _visibleEndValue, dimension);
    final displayRange = displayEnd - displayStart;
    if (displayRange <= 0) return _DragType.none;

    final double startPos = ((_visibleStartValue - displayStart) / displayRange) * dimension;
    final double endPos = ((_visibleEndValue - displayStart) / displayRange) * dimension;

    if (pos > startPos && pos < endPos) {
      return _DragType.scrub;
    }

    return _DragType.none;
  }

  void _onHover(PointerEvent event, Size size) {
    final dragType = _getDragTypeAtPosition(event.localPosition, size);
    final MouseCursor newCursor = dragType == _DragType.scrub ? SystemMouseCursors.move : SystemMouseCursors.basic;

    if (newCursor != _cursor) {
      setState(() => _cursor = newCursor);
    }
  }

  void _onExit(PointerEvent event) {
    if (_cursor != SystemMouseCursors.basic) {
      setState(() => _cursor = SystemMouseCursors.basic);
    }
  }

  void _onTapUp(TapUpDetails details, Size size) {
    _performSeek(details.localPosition, size);
  }

  void _performSeek(Offset localPosition, Size size) {
    final dimension = widget.orientation == Axis.horizontal ? size.width : size.height;
    final pos = widget.orientation == Axis.horizontal ? localPosition.dx : localPosition.dy;
    final (displayStart, displayEnd) = _calculateDisplayRange(_visibleStartValue, _visibleEndValue, dimension);
    final displayRange = displayEnd - displayStart;

    final seekValue = displayStart + (pos / dimension) * displayRange;
    widget.onSeek?.call(seekValue.toInt());
  }

  void _onPanStart(DragStartDetails details, Size size) {
    _dragType = _getDragTypeAtPosition(details.localPosition, size);

    if (_dragType != _DragType.none) {
      _dragStartPos = widget.orientation == Axis.horizontal ? details.localPosition.dx : details.localPosition.dy;
      _dragStartVisibleStartValue = _visibleStartValue;
      _dragStartVisibleEndValue = _visibleEndValue;

      final dimension = widget.orientation == Axis.horizontal ? size.width : size.height;
      final (displayStart, displayEnd) = _calculateDisplayRange(_visibleStartValue, _visibleEndValue, dimension);
      _dragStartDisplayStartValue = displayStart;
      _dragStartDisplayEndValue = displayEnd;
    } else {
      _dragType = _DragType.seek;
      _performSeek(details.localPosition, size);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_dragType == _DragType.none) return;

    if (_dragType == _DragType.seek) {
      _performSeek(details.localPosition, size);
      return;
    }

    final dimension = widget.orientation == Axis.horizontal ? size.width : size.height;
    final pos = widget.orientation == Axis.horizontal ? details.localPosition.dx : details.localPosition.dy;

    final dragDisplayRange = _dragStartDisplayEndValue - _dragStartDisplayStartValue;
    if (dragDisplayRange <= 0) return;

    final delta = pos - _dragStartPos;
    final dValue = delta / dimension * dragDisplayRange;

    _updateVisibleWindow(
      _dragStartVisibleStartValue + dValue,
      _dragStartVisibleEndValue + dValue,
      _dragType,
    );
  }

  void _onPointerSignal(PointerSignalEvent event, Size size) {
    if (event is PointerScrollEvent) {
      final dimension = widget.orientation == Axis.horizontal ? size.width : size.height;
      if (dimension == 0) return;

      final (displayStart, displayEnd) = _calculateDisplayRange(_visibleStartValue, _visibleEndValue, dimension);
      final displayRange = displayEnd - displayStart;
      if (displayRange <= 0) return;

      final delta = widget.orientation == Axis.horizontal ? event.scrollDelta.dx : event.scrollDelta.dy;
      final double dValue = (delta / dimension) * displayRange;

      _updateVisibleWindow(_visibleStartValue + dValue, _visibleEndValue + dValue, _DragType.scrub);
    }
  }

  void _updateVisibleWindow(double newVisibleStartValue, double newVisibleEndValue, _DragType currentDragType) {
    final totalStart = _totalStartValue;
    final totalEnd = _totalEndValue;
    const minWindowLines = 1.0;

    double startValue = newVisibleStartValue;
    double endValue = newVisibleEndValue;

    if (endValue - startValue < minWindowLines) {
      endValue = startValue + minWindowLines;
    }

    if (startValue < totalStart) {
      final correction = totalStart - startValue;
      startValue = totalStart;
      if (currentDragType == _DragType.scrub) {
        endValue += correction;
      }
    }

    if (endValue > totalEnd) {
      final correction = endValue - totalEnd;
      endValue = totalEnd;
      if (currentDragType == _DragType.scrub) {
        startValue -= correction;
      }
    }

    startValue = startValue.clamp(totalStart, totalEnd);
    endValue = endValue.clamp(totalStart, totalEnd);

    widget.onWindowChanged(
      startValue.toInt(),
      endValue.toInt(),
      _mapDragTypeToMinimapHandle(currentDragType),
    );
  }

  MinimapHandle _mapDragTypeToMinimapHandle(_DragType type) {
    switch (type) {
      case _DragType.scrub:
      case _DragType.seek:
        return MinimapHandle.scrub;
      case _DragType.none:
        return MinimapHandle.programmatic;
    }
  }

  void _onPanEnd(DragEndDetails details) => _dragType = _DragType.none;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? MinimapTheme.fromTheme(Theme.of(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final dimension = widget.orientation == Axis.horizontal ? constraints.maxWidth : constraints.maxHeight;
        final (displayStartValue, displayEndValue) = _calculateDisplayRange(
          _visibleStartValue,
          _visibleEndValue,
          dimension,
        );

        final totalRangeValue = _totalEndValue - _totalStartValue;
        final isZoomed = (displayEndValue - displayStartValue) < totalRangeValue;

        return Stack(
          alignment: widget.orientation == Axis.horizontal ? Alignment.centerRight : Alignment.bottomCenter,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: (event) => _onPointerSignal(event, constraints.biggest),
              child: MouseRegion(
                cursor: _cursor,
                onHover: (e) => _onHover(e, constraints.biggest),
                onExit: _onExit,
                child: GestureDetector(
                  onTapUp: (d) => _onTapUp(d, constraints.biggest),
                  onPanStart: (d) => _onPanStart(d, constraints.biggest),
                  onPanUpdate: (d) => _onPanUpdate(d, constraints.biggest),
                  onPanEnd: _onPanEnd,
                  child: CustomPaint(
                    painter: _MinimapPainter(
                      totalStartValue: _totalStartValue,
                      totalEndValue: _totalEndValue,
                      displayStartValue: displayStartValue,
                      displayEndValue: displayEndValue,
                      visibleStartValue: _visibleStartValue,
                      visibleEndValue: _visibleEndValue,
                      markers: widget.markers,
                      theme: theme,
                      orientation: widget.orientation,
                    ),
                    size: constraints.biggest,
                  ),
                ),
              ),
            ),
            if (isZoomed && widget.showResetZoomButton)
              IconButton(
                padding: const EdgeInsets.only(right: 8.0),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.zoom_out_map),
                iconSize: 20.0,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                tooltip: 'Reset Zoom',
                onPressed: () => widget.onWindowChanged(0, widget.totalLineCount, MinimapHandle.programmatic),
              ),
          ],
        );
      },
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final double totalStartValue;
  final double totalEndValue;
  final double displayStartValue;
  final double displayEndValue;
  final double visibleStartValue;
  final double visibleEndValue;
  final List<MinimapMarker> markers;
  final MinimapTheme theme;
  final Axis orientation;

  _MinimapPainter({
    required this.totalStartValue,
    required this.totalEndValue,
    required this.displayStartValue,
    required this.displayEndValue,
    required this.visibleStartValue,
    required this.visibleEndValue,
    required this.markers,
    required this.theme,
    required this.orientation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final displayRangeValue = displayEndValue - displayStartValue;
    if (displayRangeValue <= 0) return;

    final dimension = orientation == Axis.horizontal ? size.width : size.height;

    double valueToPos(double value) {
      if (value < displayStartValue) return 0.0;
      if (value > displayEndValue) return dimension;
      final valueOffset = value - displayStartValue;
      return (valueOffset / displayRangeValue) * dimension;
    }

    final markerPaint = Paint();

    for (final marker in markers) {
      final startPos = valueToPos(marker.startLine.toDouble());
      final endPos = valueToPos(marker.endLine.toDouble());
      markerPaint.color = marker.color ?? theme.markerColor;

      final startRatio = marker.startRatio ?? 0.25;
      final endRatio = marker.endRatio ?? 0.75;

      if (orientation == Axis.horizontal) {
        canvas.drawRect(Rect.fromLTRB(startPos, size.height * startRatio, endPos, size.height * endRatio), markerPaint);
      } else {
        final left = size.width * startRatio;
        final right = size.width * endRatio;
        canvas.drawRect(Rect.fromLTRB(left, startPos, right, endPos), markerPaint);
      }
    }

    final visibleStartPos = valueToPos(visibleStartValue);
    final visibleEndPos = valueToPos(visibleEndValue);

    final windowPaint = Paint()..color = theme.viewportColor;
    final borderPaint = Paint()
      ..color = theme.viewportBorderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final windowRect = orientation == Axis.horizontal
        ? Rect.fromLTRB(visibleStartPos, 0, visibleEndPos, size.height)
        : Rect.fromLTRB(0, visibleStartPos, size.width, visibleEndPos);

    canvas.drawRect(windowRect, windowPaint);
    canvas.drawRect(windowRect, borderPaint);

    const fadeWidth = 20.0;

    if (displayStartValue > totalStartValue) {
      final leftFadeRect = orientation == Axis.horizontal
          ? Rect.fromLTWH(0, 0, fadeWidth, size.height)
          : Rect.fromLTWH(0, 0, size.width, fadeWidth);
      final leftGradient = orientation == Axis.horizontal
          ? LinearGradient(colors: [theme.textColor.withValues(alpha: 0.16), theme.textColor.withValues(alpha: 0)])
          : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.textColor.withValues(alpha: 0.16), theme.textColor.withValues(alpha: 0)],
            );
      canvas.drawRect(leftFadeRect, Paint()..shader = leftGradient.createShader(leftFadeRect));
    }

    if (displayEndValue < totalEndValue) {
      final rightFadeRect = orientation == Axis.horizontal
          ? Rect.fromLTWH(size.width - fadeWidth, 0, fadeWidth, size.height)
          : Rect.fromLTWH(0, size.height - fadeWidth, size.width, fadeWidth);
      final rightGradient = orientation == Axis.horizontal
          ? LinearGradient(colors: [theme.textColor.withValues(alpha: 0), theme.textColor.withValues(alpha: 0.16)])
          : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [theme.textColor.withValues(alpha: 0), theme.textColor.withValues(alpha: 0.16)],
            );
      canvas.drawRect(rightFadeRect, Paint()..shader = rightGradient.createShader(rightFadeRect));
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) =>
      oldDelegate.totalStartValue != totalStartValue ||
      oldDelegate.totalEndValue != totalEndValue ||
      oldDelegate.displayStartValue != displayStartValue ||
      oldDelegate.displayEndValue != displayEndValue ||
      oldDelegate.visibleStartValue != visibleStartValue ||
      oldDelegate.visibleEndValue != visibleEndValue ||
      !listEquals(oldDelegate.markers, markers) ||
      oldDelegate.theme != theme ||
      oldDelegate.orientation != orientation;
}
