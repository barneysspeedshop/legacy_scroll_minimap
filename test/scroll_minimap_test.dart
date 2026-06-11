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
