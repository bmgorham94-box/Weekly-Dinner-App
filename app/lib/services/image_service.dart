import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Compresses + stores check-in photos locally.
/// Max 480px long edge, JPEG quality 0.55 — per spec.
class ImageService {
  static Future<String> compressAndStore(File source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Fall back to copying the original if decode fails.
      return _store(bytes);
    }
    final resized = (decoded.width >= decoded.height)
        ? img.copyResize(decoded, width: 480)
        : img.copyResize(decoded, height: 480);
    final jpeg = img.encodeJpg(resized, quality: 55);
    return _store(jpeg);
  }

  static Future<String> _store(List<int> bytes) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'checkins'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final name = 'checkin_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Reads a stored photo back as base64 (for sending to the coach vision API).
  static Future<String> toBase64(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }
}
