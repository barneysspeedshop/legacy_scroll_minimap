# Legacy Scroll Minimap

A Flutter widget that provides a scroll minimap for navigating long content such as code editors, logs, and documents.

## About

`legacy_scroll_minimap` is a high-performance visual navigation widget built for intensive text workspaces. 

Designed for and used natively inside **[Rope Notes](https://ropenotes.dev)**—the private, local-first agentic workspace.

## Installation

```bash
flutter pub add legacy_scroll_minimap
```

## Features

- Vertical or horizontal orientation
- Draggable viewport window
- Click or drag to seek
- Scroll-wheel panning
- Custom markers with cross-axis positioning
- Theme support via [MinimapTheme]

## Example

```bash
cd example
flutter run
```

The example shows a monospace line list with a minimap sidebar — click, drag, or scroll the minimap to navigate.

## Usage

```dart
import 'package:legacy_scroll_minimap/legacy_scroll_minimap.dart';

ScrollMinimap(
  totalLineCount: document.lineCount,
  visibleStartLine: firstVisibleLine,
  visibleEndLine: lastVisibleLine,
  markers: [
    MinimapMarker(
      id: 'highlight',
      startLine: 10,
      endLine: 20,
      color: Colors.orange,
      startRatio: 0.1,
      endRatio: 0.9,
    ),
  ],
  onSeek: (line) => scrollController.jumpTo(line * lineHeight),
  onWindowChanged: (startLine, endLine, handle) {
    if (handle == MinimapHandle.programmatic) return;
    scrollController.jumpTo(startLine * lineHeight);
  },
)
```

## Material UI compatibility

This release requires Dart 3.13 and Flutter 3.47 or newer. Import `package:material_ui/material_ui.dart` in consuming widgets and use its Material types (including `ThemeData`). Legacy Flutter Material classes are distinct types. Widget behavior and existing options are retained.
