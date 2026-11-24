import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:legacy_scroll_minimap/legacy_scroll_minimap.dart';

void _demoLog(String message) {
  if (kDebugMode) {
    debugPrint('[EditorDemo] $message');
  }
}

void main() {
  runApp(const MinimapExampleApp());
}

class MinimapExampleApp extends StatelessWidget {
  const MinimapExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Legacy Scroll Minimap Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const EditorDemoPage(),
    );
  }
}

class EditorDemoPage extends StatefulWidget {
  const EditorDemoPage({super.key});

  @override
  State<EditorDemoPage> createState() => _EditorDemoPageState();
}

class _EditorDemoPageState extends State<EditorDemoPage> {
  static const double _lineHeight = 20.0;
  static const double _minimapWidth = 80.0;

  late final ScrollController _scrollController;
  late final List<String> _lines;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _lines = _generateSampleDocument();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _demoLog(
      'scrollController offset=${_scrollController.offset.toStringAsFixed(1)} '
      'line≈${(_scrollController.offset / _lineHeight).floor()}',
    );
    setState(() {});
  }

  List<String> _generateSampleDocument() {
    final buffer = StringBuffer();
    buffer.writeln('import "package:material_ui/material_ui.dart";');
    buffer.writeln();
    buffer.writeln('void main() {');
    buffer.writeln('  runApp(const MyApp());');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('class MyApp extends StatelessWidget {');
    buffer.writeln('  const MyApp({super.key});');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  Widget build(BuildContext context) {');
    buffer.writeln('    return MaterialApp(');
    buffer.writeln('      home: Scaffold(');
    buffer.writeln('        body: Center(child: Text("Hello")),');
    buffer.writeln('      ),');
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln('}');

    for (var block = 0; block < 8; block++) {
      buffer.writeln();
      buffer.writeln('// --- section $block ---');
      for (var line = 0; line < 30; line++) {
        buffer.writeln('final value_${block}_$line = $block * 100 + $line;');
      }
    }

    return buffer.toString().split('\n');
  }

  List<MinimapMarker> _buildMarkers() {
    final markers = <MinimapMarker>[];
    const horizontalBounds = 100.0;

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.trim().isEmpty) continue;

      final leadingWhitespace = line.length - line.trimLeft().length;
      final contentLength = line.trim().length;
      final startRatio =
          (leadingWhitespace / horizontalBounds).clamp(0.0, 0.95);
      final endRatio = ((leadingWhitespace + contentLength) / horizontalBounds)
          .clamp(startRatio + 0.01, 1.0);

      Color? color;
      if (line.startsWith('import')) {
        color = Colors.green.withValues(alpha: 0.6);
      } else if (line.startsWith('class') || line.startsWith('void')) {
        color = Colors.blue.withValues(alpha: 0.6);
      } else if (line.startsWith('//')) {
        color = Colors.grey.withValues(alpha: 0.4);
      } else if (line.contains('return')) {
        color = Colors.purple.withValues(alpha: 0.5);
      }

      markers.add(
        MinimapMarker(
          id: 'line_$i',
          startLine: i,
          endLine: i + 1,
          color: color,
          startRatio: startRatio,
          endRatio: endRatio,
        ),
      );
    }

    return markers;
  }

  void _seekToLine(int line) {
    if (!_scrollController.hasClients) return;
    final viewportLines =
        _scrollController.position.viewportDimension / _lineHeight;
    final target = (line - viewportLines / 2) * _lineHeight;
    final clamped = target.clamp(0.0, _scrollController.position.maxScrollExtent);
    _demoLog('onSeek line=$line jumpTo=${clamped.toStringAsFixed(1)}');
    _scrollController.jumpTo(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final totalLines = _lines.length;
    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final viewportHeight = _scrollController.hasClients
        ? _scrollController.position.viewportDimension
        : MediaQuery.sizeOf(context).height;
    final visibleStartLine = (scrollOffset / _lineHeight)
        .floor()
        .clamp(0, totalLines > 0 ? totalLines - 1 : 0);
    final visibleEndLine = ((scrollOffset + viewportHeight) / _lineHeight)
        .ceil()
        .clamp(0, totalLines);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Legacy Scroll Minimap Example'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'Lines $visibleStartLine–$visibleEndLine of $totalLines',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerSignal: (event) {
                if (event is PointerScrollEvent && _scrollController.hasClients) {
                  final position = _scrollController.position;
                  _demoLog(
                    'textArea pointerScroll kind=${event.kind} '
                    'scrollDelta=${event.scrollDelta} '
                    'offsetBefore=${position.pixels.toStringAsFixed(1)}',
                  );
                }
              },
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.builder(
                controller: _scrollController,
                itemExtent: _lineHeight,
                itemCount: totalLines,
                itemBuilder: (context, index) {
                  final lineNumber = (index + 1).toString().padLeft(4);
                  return Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          lineNumber,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lines[index],
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            ),
          ),
          Container(
            width: _minimapWidth,
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.3))),
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.2),
            ),
            child: ScrollMinimap(
              totalLineCount: totalLines,
              visibleStartLine: visibleStartLine,
              visibleEndLine: visibleEndLine,
              scrollController: _scrollController,
              markers: _buildMarkers(),
              onSeek: _seekToLine,
              onWindowChanged: (startLine, endLine, handle) {
                if (handle == MinimapHandle.programmatic) return;
                final target = startLine * _lineHeight;
                _demoLog(
                  'onWindowChanged handle=$handle startLine=$startLine '
                  'jumpTo=${target.toStringAsFixed(1)}',
                );
                _scrollController.jumpTo(target);
              },
            ),
          ),
        ],
      ),
    );
  }
}
