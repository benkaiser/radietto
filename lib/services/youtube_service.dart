import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/song.dart';
import 'llm_service.dart';

/// Resolves songs to YouTube audio stream URLs, with global rate limiting
/// (max 1 youtube_explode_dart call every 2 seconds).
class YoutubeService {
  static const Duration _minInterval = Duration(seconds: 2);
  static const int _candidateCount = 8;

  final LlmService? _llm;

  YoutubeService({LlmService? llm}) : _llm = llm;

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

        final topResults = results.take(_candidateCount).toList();
        Video chosen = topResults.first;

        if (_llm != null && topResults.length > 1) {
          final candidates = topResults
              .map((v) => {
                    'videoId': v.id.value,
                    'title': v.title,
                    'channel': v.author,
                    'durationSeconds': v.duration?.inSeconds,
                  })
              .toList();
          try {
            final pickedId = await _llm.pickBestYoutubeVideo(
              title: song.title,
              artist: song.artist,
              candidates: candidates,
            );
            if (pickedId != null) {
              chosen = topResults.firstWhere(
                (v) => v.id.value == pickedId,
                orElse: () => topResults.first,
              );
            }
          } catch (e) {
            debugPrint(
              'LLM video pick failed for "${song.title}" — ${song.artist}: $e',
            );
          }
        }

        videoId = chosen.id;
        song.youtubeVideoId = videoId.value;
        song.thumbnailUrl = chosen.thumbnails.highResUrl;
        song.duration = chosen.duration;
      }

      // Rate-limited: stream manifest.
      await _waitForSlot();
      final manifest = await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [YoutubeApiClient.androidVr],
      );
      final audioStreams = manifest.audioOnly.toList();
      // macOS/iOS AVFoundation cannot play WebM/Opus — restrict to MP4/AAC
      // (m4a) when available, falling back to the highest bitrate otherwise.
      final mp4Streams = audioStreams
          .where((s) => s.container.name.toLowerCase() == 'mp4')
          .toList();
      final candidates = mp4Streams.isNotEmpty ? mp4Streams : audioStreams;
      candidates.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      final audio = candidates.first;
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
