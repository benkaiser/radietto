import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Thin wrapper over Replicate's HTTP API. Currently exposes one method —
/// generating a single text-to-image output via flux-schnell — used to mint
/// cover art for user-created custom stations.
class ReplicateService {
  /// Visual-style suffix appended to every station-tile prompt so all
  /// stations (bundled + custom) share a consistent aesthetic.
  static const String kStationTileStyleSuffix =
      'minimalist square poster illustration, flat retro-modern graphic '
      'design, bold simple geometric shapes, warm muted color palette with '
      'one bright accent, soft gradients, generous negative space, subtle '
      'film grain, vinyl-era radio station aesthetic, centered composition, '
      'no text, no letters, no logos';

  static const _fluxSchnellEndpoint =
      'https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions';

  String get _apiKey => dotenv.env['REPLICATE_API_KEY'] ?? '';

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Generates one 1024×1024 webp image using flux-schnell. Returns the
  /// raw bytes on success, or null on any failure (HTTP, timeout, model
  /// error, missing API key). Callers should treat null as "no art".
  Future<Uint8List?> generateFluxSchnellImage({required String prompt}) async {
    if (!isConfigured) {
      debugPrint('ReplicateService: REPLICATE_API_KEY not set — skipping');
      return null;
    }
    try {
      final body = jsonEncode({
        'input': {
          'prompt': prompt,
          'aspect_ratio': '1:1',
          'num_outputs': 1,
          'output_format': 'webp',
          'output_quality': 90,
          'go_fast': true,
          'megapixels': '1',
          'num_inference_steps': 4,
        },
      });
      // `Prefer: wait` makes Replicate hold the request open until the
      // prediction finishes (capped at ~60s). flux-schnell typically
      // completes in well under that, so we don't have to poll.
      final resp = await http
          .post(
            Uri.parse(_fluxSchnellEndpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'Prefer': 'wait',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 90));
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        debugPrint(
            'ReplicateService: prediction HTTP ${resp.statusCode}: ${resp.body}');
        return null;
      }
      final pred = jsonDecode(resp.body) as Map<String, dynamic>;
      final status = pred['status'] as String?;
      if (status != 'succeeded') {
        // If still running (rare for schnell) we'd need to poll — for now
        // we just bail; the caller falls back to the emoji.
        debugPrint(
            'ReplicateService: prediction status=$status error=${pred['error']}');
        return null;
      }
      final output = pred['output'];
      final url = output is List && output.isNotEmpty
          ? output.first as String
          : output is String
              ? output
              : null;
      if (url == null) {
        debugPrint('ReplicateService: prediction succeeded with no output URL');
        return null;
      }
      final imgResp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      if (imgResp.statusCode != 200) {
        debugPrint(
            'ReplicateService: image download HTTP ${imgResp.statusCode}');
        return null;
      }
      return imgResp.bodyBytes;
    } catch (e) {
      debugPrint('ReplicateService.generateFluxSchnellImage failed: $e');
      return null;
    }
  }
}
