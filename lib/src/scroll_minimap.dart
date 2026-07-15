import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'models/minimap_marker.dart';
import 'models/minimap_theme.dart';

void _minimapLog(String message) {
  if (kDebugMode) {
    debugPrint('[ScrollMinimap] $message');
  }
}

/// Indicates which part of the minimap caused a viewport change.
enum MinimapHandle {
  /// The viewport window was dragged.
  scrub,

  /// The change was not caused by a direct interaction (e.g., reset).
  programmatic,
}

enum _DragType { none, scrub, seek, trackpadScroll }

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

  /// The scroll controller for the main scrollable content.
  ///
  /// When provided, wheel and trackpad gestures over the minimap call
  /// [ScrollPosition.pointerScroll] with the same delta semantics as
  /// [Scrollable], keeping scroll direction consistent with the text area.
  /// Tap and drag continue to use [onWindowChanged] and [onSeek].
  final ScrollController? scrollController;

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
    this.scrollController,
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
    _minimapLog(
      'seek tap pos=$pos dimension=$dimension seekLine=${seekValue.toInt()} '
      'visible=${widget.visibleStartLine}..${widget.visibleEndLine}',
    );
    widget.onSeek?.call(seekValue.toInt());
  }

  void _onPanStart(DragStartDetails details, Size size) {
    _minimapLog('panStart kind=${details.kind} local=${details.localPosition}');

    // Linux/desktop trackpad two-finger scroll is delivered as pan gestures, not
    // PointerScrollEvent. Route it to scroll handling instead of seek/scrub.
    if (details.kind == PointerDeviceKind.trackpad) {
      _dragType = _DragType.trackpadScroll;
      _minimapLog('panStart -> trackpadScroll');
      return;
    }

    _dragType = _getDragTypeAtPosition(details.localPosition, size);

    if (_dragType != _DragType.none) {
      _dragStartPos = widget.orientation == Axis.horizontal ? details.localPosition.dx : details.localPosition.dy;
      _dragStartVisibleStartValue = _visibleStartValue;
      _dragStartVisibleEndValue = _visibleEndValue;

      final dimension = widget.orientation == Axis.horizontal ? size.width : size.height;
      final (displayStart, displayEnd) = _calculateDisplayRange(_visibleStartValue, _visibleEndValue, dimension);
      _dragStartDisplayStartValue = displayStart;
      _dragStartDisplayEndValue = displayEnd;
      _minimapLog(
        'panStart type=$_dragType local=${details.localPosition} dragStartPos=$_dragStartPos '
        'visible=${widget.visibleStartLine}..${widget.visibleEndLine}',
      );
    } else {
      _dragType = _DragType.seek;
      _minimapLog('panStart type=seek (outside viewport) local=${details.localPosition}');
      _performSeek(details.localPosition, size);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (_dragType == _DragType.none) return;

    if (_dragType == _DragType.trackpadScroll) {
      _applyTrackpadScrollDelta(details.delta, size);
      return;
    }

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

    _minimapLog(
      'panUpdate type=$_dragType pos=$pos dragStartPos=$_dragStartPos delta=$delta '
      'dValue=$dValue targetStart=${_dragStartVisibleStartValue + dValue}',
    );

    _updateVisibleWindow(
      _dragStartVisibleStartValue + dValue,
      _dragStartVisibleEndValue + dValue,
      _dragType,
    );
  }

  void _onPointerSignal(PointerSignalEvent event, Size size) {
    if (event is! PointerScrollEvent) return;

    _minimapLog(
      'pointerScroll kind=${event.kind} device=${event.device} '
      'scrollDelta=${event.scrollDelta} local=${event.localPosition} '
      'visible=${widget.visibleStartLine}..${widget.visibleEndLine}',
    );

    final controller = widget.scrollController;
    if (controller != null && controller.hasClients) {
      final position = controller.position;
      if (!position.physics.shouldAcceptUserOffset(position)) {
        _minimapLog('pointerScroll skipped: physics rejected user offset');
        return;
      }

      final raw = switch (position.axis) {
        Axis.horizontal => event.scrollDelta.dx,
        Axis.vertical => event.scrollDelta.dy,
      };
      final delta = _pointerScrollDelta(event, position);
      if (delta == 0.0) {
        _minimapLog('pointerScroll skipped: computed delta is 0 (raw=$raw)');
        return;
      }

      final pixelsBefore = position.pixels;
      final targetOffset = (pixelsBefore + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (targetOffset == pixelsBefore) {
        _minimapLog(
          'pointerScroll skipped: clamped no-op pixelsBefore=$pixelsBefore '
          'target=$targetOffset delta=$delta axis=${position.axis} '
          'axisDirection=${position.axisDirection}',
        );
        return;
      }

      _minimapLog(
        'pointerScroll via scrollController raw=$raw computedDelta=$delta '
        'pixelsBefore=$pixelsBefore pixelsAfter=$targetOffset '
        'axis=${position.axis} axisDirection=${position.axisDirection}',
      );
      position.pointerScroll(delta);
      event.respond(allowPlatformDefault: false);
      _minimapLog('pointerScroll done pixelsNow=${position.pixels}');
      return;
    }

    _minimapLog(
      'pointerScroll fallback (no scrollController clients) '
      'hasController=${controller != null} hasClients=${controller?.hasClients ?? false}',
    );

    final dimension = widget.orientation == Axis.horizontal ? size.width : size.height;
    if (dimension == 0) return;

    final (displayStart, displayEnd) = _calculateDisplayRange(_visibleStartValue, _visibleEndValue, dimension);
    final displayRange = displayEnd - displayStart;
    if (displayRange <= 0) return;

    final scrollDelta = widget.orientation == Axis.horizontal ? event.scrollDelta.dx : event.scrollDelta.dy;
    final double dValue = (scrollDelta / dimension) * displayRange;

    _minimapLog(
      'pointerScroll fallback scrollDelta=$scrollDelta dimension=$dimension '
      'displayRange=$displayRange dValue=$dValue targetStart=${_visibleStartValue + dValue}',
    );

    _updateVisibleWindow(_visibleStartValue + dValue, _visibleEndValue + dValue, _DragType.scrub);
  }

  void _applyTrackpadScrollDelta(Offset delta, Size size) {
    final controller = widget.scrollController;
    if (controller != null && controller.hasClients) {
      final position = controller.position;
      if (!position.physics.shouldAcceptUserOffset(position)) {
        _minimapLog('trackpadScroll skipped: physics rejected user offset');
        return;
      }

      final scrollDelta = -(switch (position.axis) {
        Axis.horizontal => delta.dx,
        Axis.vertical => delta.dy,
      });
      if (scrollDelta == 0.0) return;

      final pixelsBefore = position.pixels;
      _minimapLog(
        'trackpadScroll via scrollController delta=$scrollDelta '
        'pixelsBefore=$pixelsBefore',
      );
      position.pointerScroll(scrollDelta);
      _minimapLog('trackpadScroll offsetAfter=${position.pixels}');
      return;
    }

    final dimension = widget.orientation == Axis.horizontal ? size.width : size.height;
    if (dimension == 0) return;

    final (displayStart, displayEnd) = _calculateDisplayRange(_visibleStartValue, _visibleEndValue, dimension);
    final displayRange = displayEnd - displayStart;
    if (displayRange <= 0) return;

    final scrollDelta = -(widget.orientation == Axis.horizontal ? delta.dx : delta.dy);
    final double dValue = (scrollDelta / dimension) * displayRange;

    _minimapLog('trackpadScroll fallback delta=$scrollDelta dValue=$dValue');
    _updateVisibleWindow(_visibleStartValue + dValue, _visibleEndValue + dValue, _DragType.scrub);
  }

  /// Matches [Scrollable]'s pointer-scroll delta for a linked [ScrollPosition].
  double _pointerScrollDelta(PointerScrollEvent event, ScrollPosition position) {
    final double raw = switch (position.axis) {
      Axis.horizontal => event.scrollDelta.dx,
      Axis.vertical => event.scrollDelta.dy,
    };
    return axisDirectionIsReversed(position.axisDirection) ? -raw : raw;
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

    final handle = _mapDragTypeToMinimapHandle(currentDragType);
    _minimapLog(
      'onWindowChanged handle=$handle requested=$newVisibleStartValue..$newVisibleEndValue '
      'clamped=${startValue.toInt()}..${endValue.toInt()} '
      'previous=${widget.visibleStartLine}..${widget.visibleEndLine}',
    );

    widget.onWindowChanged(
      startValue.toInt(),
      endValue.toInt(),
      handle,
    );
  }

  MinimapHandle _mapDragTypeToMinimapHandle(_DragType type) {
    switch (type) {
      case _DragType.scrub:
      case _DragType.seek:
      case _DragType.trackpadScroll:
        return MinimapHandle.scrub;
      case _DragType.none:
        return MinimapHandle.programmatic;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragType != _DragType.none) {
      _minimapLog('panEnd type=$_dragType velocity=${details.velocity}');
    }
    _dragType = _DragType.none;
  }

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
