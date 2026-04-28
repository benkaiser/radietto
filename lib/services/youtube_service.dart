import 'dart:async';
import 'dart:collection';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/song.dart';

/// Resolves songs to YouTube audio stream URLs, with global rate limiting
/// (max 1 youtube_explode_dart call every 2 seconds).
class YoutubeService {
  static const Duration _minInterval = Duration(seconds: 2);
  DateTime _lastCall = DateTime.fromMillisecondsSinceEpoch(0);
  final Queue<Completer<void>> _waiters = Queue();
  bool _processing = false;

  Future<void> _waitForSlot() async {
    final completer = Completer<void>();
    _waiters.add(completer);
    _processQueue();
    return completer.future;
  }

  void _processQueue() {
    if (_processing) return;
    _processing = true;
    Future(() async {
      while (_waiters.isNotEmpty) {
        final now = DateTime.now();
        final elapsed = now.difference(_lastCall);
        if (elapsed < _minInterval) {
          await Future.delayed(_minInterval - elapsed);
        }
        _lastCall = DateTime.now();
        final next = _waiters.removeFirst();
        next.complete();
        // Yield so the awaiting code can actually start its request before we
        // come back around for the next slot.
        await Future.delayed(const Duration(milliseconds: 1));
      }
      _processing = false;
    });
  }

  /// Resolve a single Song's YouTube videoId, streamUrl, and metadata.
  /// If [song.youtubeVideoId] is already known, only the manifest is fetched
  /// (1 rate-limited call). Otherwise we search first then fetch the manifest
  /// (2 rate-limited calls). Mutates the [song] in place.
  /// Returns true on success, false on failure.
  Future<bool> resolveSong(Song song) async {
    if (song.streamUrl != null) return true;
    song.status = SongResolutionStatus.resolving;

    final yt = YoutubeExplode();
    try {
      VideoId videoId;
      if (song.youtubeVideoId != null) {
        videoId = VideoId(song.youtubeVideoId!);
      } else {
        // Rate-limited: search.
        await _waitForSlot();
        final query = '${song.artist} ${song.title}';
        final results = await yt.search.search(query);
        if (results.isEmpty) {
          song.status = SongResolutionStatus.failed;
          return false;
        }
        final video = results.first;
        videoId = video.id;
        song.youtubeVideoId = videoId.value;
        song.thumbnailUrl = video.thumbnails.highResUrl;
        song.duration = video.duration;
      }

      // Rate-limited: stream manifest.
      await _waitForSlot();
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr],
      );
      final audio = manifest.audioOnly.withHighestBitrate();
      song.streamUrl = audio.url.toString();
      song.status = SongResolutionStatus.resolved;
      return true;
    } catch (e) {
      song.status = SongResolutionStatus.failed;
      return false;
    } finally {
      yt.close();
    }
  }
}
