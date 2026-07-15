import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_scroll_minimap/legacy_scroll_minimap.dart';

void main() {
  testWidgets('ScrollMinimap renders markers and reports seek', (tester) async {
    int? seekLine;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            height: 400,
            child: ScrollMinimap(
              totalLineCount: 100,
              visibleStartLine: 10,
              visibleEndLine: 30,
              markers: const [
                MinimapMarker(
                  id: 'm1',
                  startLine: 5,
                  endLine: 15,
                  color: Colors.red,
                ),
              ],
              onSeek: (line) => seekLine = line,
              onWindowChanged: (_, __, ___) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ScrollMinimap), findsOneWidget);

    await tester.tapAt(const Offset(40, 200));
    await tester.pump();

    expect(seekLine, isNotNull);
    expect(seekLine!, greaterThanOrEqualTo(0));
    expect(seekLine!, lessThanOrEqualTo(100));
  });

  testWidgets('ScrollMinimap scroll follows Flutter Scrollable direction', (tester) async {
    int? startLine;
    int? endLine;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            height: 400,
            child: ScrollMinimap(
              totalLineCount: 100,
              visibleStartLine: 10,
              visibleEndLine: 30,
              onWindowChanged: (start, end, handle) {
                startLine = start;
                endLine = end;
              },
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(ScrollMinimap));
    final pointer = TestPointer(1, ui.PointerDeviceKind.mouse);
    pointer.hover(center);

    startLine = null;
    endLine = null;
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
    await tester.pump();

    expect(startLine, greaterThan(10));
    expect(endLine, greaterThan(30));

    startLine = null;
    endLine = null;
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -40)));
    await tester.pump();

    expect(startLine, lessThan(10));
    expect(endLine, lessThan(30));
  });

  testWidgets('ScrollMinimap scroll uses scroll controller when provided', (tester) async {
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 100,
                  itemBuilder: (_, i) => Text('line $i'),
                ),
              ),
              SizedBox(
                width: 80,
                height: 400,
                child: ScrollMinimap(
                  totalLineCount: 100,
                  visibleStartLine: 0,
                  visibleEndLine: 20,
                  scrollController: scrollController,
                  onWindowChanged: (_, __, ___) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialOffset = scrollController.offset;
    final minimapCenter = tester.getCenter(find.byType(ScrollMinimap));
    final pointer = TestPointer(1, ui.PointerDeviceKind.trackpad);
    pointer.hover(minimapCenter);

    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 80)));
    await tester.pump();

    expect(scrollController.offset, greaterThan(initialOffset));
  });

  testWidgets('trackpad pan on minimap scrolls via scroll controller', (tester) async {
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: 100,
                  itemBuilder: (_, i) => Text('line $i'),
                ),
              ),
              SizedBox(
                width: 80,
                height: 400,
                child: ScrollMinimap(
                  totalLineCount: 100,
                  visibleStartLine: 0,
                  visibleEndLine: 20,
                  scrollController: scrollController,
                  onWindowChanged: (_, __, ___) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialOffset = scrollController.offset;
    final minimapCenter = tester.getCenter(find.byType(ScrollMinimap));
    final gesture = await tester.startGesture(
      minimapCenter,
      pointer: 1,
      kind: ui.PointerDeviceKind.trackpad,
    );
    await gesture.moveBy(const Offset(0, -40));
    await gesture.up();
    await tester.pump();

    expect(scrollController.offset, greaterThan(initialOffset));
  });

  test('MinimapTheme.fromTheme uses app theme colors', () {
    final theme = ThemeData(
      colorScheme: const ColorScheme.light(
        primary: Colors.red,
        primaryContainer: Colors.pink,
        onSurface: Colors.black,
      ),
    );

    final minimapTheme = MinimapTheme.fromTheme(theme);

    expect(minimapTheme.viewportBorderColor, Colors.red);
    expect(minimapTheme.textColor, Colors.black);
  });

  test('MinimapMarker copyWith preserves unspecified fields', () {
    const marker = MinimapMarker(
      id: 'a',
      startLine: 1,
      endLine: 2,
      color: Colors.blue,
      startRatio: 0.1,
      endRatio: 0.9,
    );

    final copy = marker.copyWith(endLine: 5);

    expect(copy.id, 'a');
    expect(copy.startLine, 1);
    expect(copy.endLine, 5);
    expect(copy.color, Colors.blue);
    expect(copy.startRatio, 0.1);
    expect(copy.endRatio, 0.9);
  });
}
