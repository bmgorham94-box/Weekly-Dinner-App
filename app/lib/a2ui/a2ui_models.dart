import 'dart:convert';
import 'package:flutter/foundation.dart';

/// A single component node in an A2UI surface (trusted catalog only).
@immutable
class A2Component {
  final String id;
  final String type;
  final Map<String, dynamic> props;

  const A2Component({required this.id, required this.type, required this.props});

  factory A2Component.fromJson(Map<String, dynamic> j) => A2Component(
        id: j['id'] as String,
        type: j['type'] as String,
        props: (j['props'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  List<String> get children {
    final c = props['children'];
    if (c is List) return c.map((e) => e.toString()).toList();
    return const [];
  }
}

/// A live A2UI surface: a component tree assembled progressively from a stream.
class A2Surface extends ChangeNotifier {
  String? surfaceId;
  String? rootId;
  final Map<String, A2Component> components = {};
  bool streaming = false;
  bool failed = false;
  String? errorMessage;

  /// Fallback plain-text rendered if a stream dies before any component lands.
  String? fallbackText;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  bool get isEmpty => components.isEmpty;

  A2Component? get root => rootId == null ? null : components[rootId!];

  void reset() {
    surfaceId = null;
    rootId = null;
    components.clear();
    streaming = false;
    failed = false;
    errorMessage = null;
    fallbackText = null;
    notifyListeners();
  }

  /// Apply one decoded A2UI message. Returns any emitted apply-event (unused here).
  void applyMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'beginStream':
        streaming = true;
        failed = false;
        errorMessage = null;
        notifyListeners();
        break;
      case 'createSurface':
        surfaceId = msg['surfaceId'] as String?;
        rootId = msg['root'] as String?;
        notifyListeners();
        break;
      case 'updateComponents':
        final list = (msg['components'] as List?) ?? const [];
        for (final raw in list) {
          if (raw is Map) {
            final comp = A2Component.fromJson(raw.cast<String, dynamic>());
            components[comp.id] = comp;
          }
        }
        notifyListeners();
        break;
      case 'endStream':
        streaming = false;
        notifyListeners();
        break;
      case 'error':
        failed = true;
        streaming = false;
        errorMessage = msg['message']?.toString();
        notifyListeners();
        break;
      default:
        // Unknown message types are ignored gracefully.
        break;
    }
  }

  void markFailed(String message, {String? fallback}) {
    failed = true;
    streaming = false;
    errorMessage = message;
    fallbackText = fallback;
    notifyListeners();
  }
}

/// Parses a raw SSE chunk buffer into complete JSON messages.
/// SSE lines look like `data: {json}`; messages are separated by blank lines.
class SseDecoder {
  final StringBuffer _buffer = StringBuffer();

  /// Feed a raw chunk; returns any complete decoded JSON messages.
  List<Map<String, dynamic>> add(String chunk) {
    _buffer.write(chunk);
    final content = _buffer.toString();
    final messages = <Map<String, dynamic>>[];

    // Split on double-newline (event boundary).
    final parts = content.split(RegExp(r'\n\n|\r\n\r\n'));
    // The last part may be incomplete; keep it buffered.
    for (var i = 0; i < parts.length - 1; i++) {
      final dataLines = parts[i]
          .split(RegExp(r'\r?\n'))
          .where((l) => l.startsWith('data:'))
          .map((l) => l.substring(5).trim())
          .where((l) => l.isNotEmpty)
          .join('\n');
      if (dataLines.isEmpty) continue;
      try {
        final decoded = jsonDecode(dataLines);
        if (decoded is Map<String, dynamic>) messages.add(decoded);
      } catch (_) {
        // Ignore malformed event; resilience over strictness.
      }
    }
    _buffer
      ..clear()
      ..write(parts.last);
    return messages;
  }
}
