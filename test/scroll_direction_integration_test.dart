import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_scroll_minimap/legacy_scroll_minimap.dart';

void main() {
  testWidgets('minimap scroll matches ListView when linked to scroll controller', (tester) async {
    const lineHeight = 20.0;
    const totalLines = 200;
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemExtent: lineHeight,
                  itemCount: totalLines,
                  itemBuilder: (_, i) => Text('line $i'),
                ),
              ),
              SizedBox(
                width: 80,
                height: 400,
                child: ScrollMinimap(
                  totalLineCount: totalLines,
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

    final listCenter = tester.getCenter(find.byType(ListView));
    final listPointer = TestPointer(1, ui.PointerDeviceKind.trackpad);
    listPointer.hover(listCenter);
    await tester.sendEventToBinding(listPointer.scroll(const Offset(0, 80)));
    await tester.pump();
    final listViewOffset = scrollController.offset;

    scrollController.jumpTo(initialOffset);
    await tester.pump();

    final minimapCenter = tester.getCenter(find.byType(ScrollMinimap));
    final minimapPointer = TestPointer(2, ui.PointerDeviceKind.trackpad);
    minimapPointer.hover(minimapCenter);
    await tester.sendEventToBinding(minimapPointer.scroll(const Offset(0, 80)));
    await tester.pump();

    expect(listViewOffset, greaterThan(initialOffset));
    expect(scrollController.offset, listViewOffset);
  });
}
