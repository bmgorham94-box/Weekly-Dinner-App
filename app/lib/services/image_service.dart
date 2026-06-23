import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Compresses check-in photos to compact JPEG bytes.
/// Max 480px long edge, JPEG quality 0.55 — per spec.
///
/// Bytes (not file paths) are returned so the same code path works on mobile
/// AND web: `XFile.readAsBytes()` is available on every platform, and the
/// `image` package is pure Dart, so nothing here touches dart:io.
class ImageService {
  /// Reads, downscales, and re-encodes a picked image to JPEG bytes.
  static Future<Uint8List> compress(XFile source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // Could not decode (rare) — keep the original bytes rather than fail.
      return bytes;
    }
    final resized = (decoded.width >= decoded.height)
        ? img.copyResize(decoded, width: 480)
        : img.copyResize(decoded, height: 480);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 55));
  }

  /// Base64 for sending to the coach vision API.
  static String toBase64(Uint8List bytes) => base64Encode(bytes);
}
