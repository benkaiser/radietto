import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'replicate_service.dart';

/// Manages on-disk station cover-art files. Bundled tile assets are copied
/// out of the asset bundle on first reference so we can hand the OS media
/// controls a `file://` URI. Custom-station art is generated via Replicate
/// (flux-schnell) and saved alongside the bundled copies.
class StationArtService {
  final ReplicateService _replicate;
  Directory? _dir;

  StationArtService({required ReplicateService replicate})
      : _replicate = replicate;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/station_art');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  /// If [assetPath] hasn't been copied into the docs dir yet, copy it now.
  /// Returns the absolute file path. Returns null if the asset can't be
  /// loaded for any reason.
  Future<String?> ensureBundledCopy({
    required String stationId,
    required String assetPath,
  }) async {
    try {
      final dir = await _ensureDir();
      final ext = assetPath.contains('.')
          ? assetPath.substring(assetPath.lastIndexOf('.'))
          : '.jpg';
      final dest = File('${dir.path}/$stationId$ext');
      if (await dest.exists() && await dest.length() > 0) {
        return dest.path;
      }
      final data = await rootBundle.load(assetPath);
      await dest.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return dest.path;
    } catch (e) {
      debugPrint('StationArtService.ensureBundledCopy failed for $stationId: $e');
      return null;
    }
  }

  /// Generate cover art for a custom station via Replicate's flux-schnell
  /// model. Returns an absolute file path on success, or null if generation
  /// or the network call failed (caller should fall back to the emoji).
  ///
  /// Uses the same shared visual style as the bundled tiles so custom
  /// stations slot in naturally next to the defaults.
  Future<String?> generateForCustomStation({
    required String stationId,
    required String moodPrompt,
    required String name,
    required String tagline,
  }) async {
    final scene = '$name — $tagline. ${moodPrompt.trim()}';
    final prompt = '$scene. ${ReplicateService.kStationTileStyleSuffix}';
    try {
      final bytes = await _replicate.generateFluxSchnellImage(prompt: prompt);
      if (bytes == null) return null;
      final dir = await _ensureDir();
      final dest = File('${dir.path}/$stationId.webp');
      await dest.writeAsBytes(bytes, flush: true);
      return dest.path;
    } catch (e) {
      debugPrint('StationArtService.generateForCustomStation failed: $e');
      return null;
    }
  }

  /// Delete any on-disk cover-art file for [stationId]. Used when the
  /// user re-rolls the tile (so the next generation isn't masked by
  /// Flutter's path-keyed FileImage cache) or deletes the station
  /// outright. Silent on failure.
  Future<void> deleteArtFor(String stationId) async {
    try {
      final dir = await _ensureDir();
      for (final ext in const ['.webp', '.jpg', '.png']) {
        final f = File('${dir.path}/$stationId$ext');
        if (await f.exists()) {
          await f.delete();
        }
      }
    } catch (e) {
      debugPrint('StationArtService.deleteArtFor failed: $e');
    }
  }
}
