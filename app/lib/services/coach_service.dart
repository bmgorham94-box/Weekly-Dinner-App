import 'dart:convert';
import 'package:http/http.dart' as http;

import '../a2ui/a2ui_models.dart';

/// Streams A2UI surfaces from the Express coach agent over SSE.
class CoachService {
  CoachService(this.baseUrl);

  /// e.g. http://192.168.1.20:8787
  String baseUrl;

  final _client = http.Client();

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  /// Generic streamed POST → feeds [surface] as A2UI messages arrive.
  /// Returns when the stream ends. Degrades gracefully on any failure.
  Future<void> stream({
    required String path,
    required Map<String, dynamic> body,
    required A2Surface surface,
    String fallback = "Coach is offline. Start the server and pull to retry.",
  }) async {
    surface.reset();
    final decoder = SseDecoder();
    try {
      final request = http.Request('POST', _u(path))
        ..headers['content-type'] = 'application/json'
        ..headers['accept'] = 'text/event-stream'
        ..body = jsonEncode(body);

      final streamed = await _client.send(request).timeout(const Duration(seconds: 45));

      if (streamed.statusCode != 200) {
        surface.markFailed('HTTP ${streamed.statusCode}', fallback: fallback);
        return;
      }

      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        for (final msg in decoder.add(chunk)) {
          surface.applyMessage(msg);
        }
      }
      // Ensure stream flagged complete even if endStream was dropped.
      if (surface.streaming) {
        surface.applyMessage({'type': 'endStream'});
      }
      if (surface.isEmpty && !surface.failed) {
        surface.markFailed('Empty surface', fallback: fallback);
      }
    } catch (e) {
      surface.markFailed(e.toString(), fallback: fallback);
    }
  }

  Future<void> dailyCheckin({required Map<String, dynamic> context, required A2Surface surface}) {
    return stream(
      path: '/coach/daily-checkin',
      body: {'context': context},
      surface: surface,
      fallback: "Show up today. Hit protein first — everything else follows. Phase 1, one rep at a time.",
    );
  }

  Future<void> weeklyReview({
    required Map<String, dynamic> context,
    required List<Map<String, dynamic>> logs,
    required A2Surface surface,
  }) {
    return stream(
      path: '/coach/weekly-review',
      body: {'context': context, 'logs': logs},
      surface: surface,
      fallback: "Couldn't reach the coach. From your logs: keep protein high and stay consistent — that's the whole game in Phase 1.",
    );
  }

  Future<void> chat({
    required Map<String, dynamic> context,
    required List<Map<String, dynamic>> messages,
    required A2Surface surface,
  }) {
    return stream(
      path: '/coach/chat',
      body: {'context': context, 'messages': messages},
      surface: surface,
      fallback: "I'm offline right now — start the coach server and try again. Meanwhile: train cramp-safe, lead with the left, hit your protein.",
    );
  }

  Future<void> photoAnalysis({
    required Map<String, dynamic> context,
    required List<String> imagesBase64,
    required A2Surface surface,
  }) {
    return stream(
      path: '/coach/photo-analysis',
      body: {'context': context, 'images': imagesBase64},
      surface: surface,
      fallback: "Couldn't analyze the photos (coach offline). Eyeball it: shoulders and back are where Phase 1 progress shows first.",
    );
  }

  void dispose() => _client.close();
}
