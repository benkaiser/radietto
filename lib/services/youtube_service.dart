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

  /// Phase 1: search YouTube + LLM-pick the best video for this song.
  /// Sets [song.youtubeVideoId], [song.thumbnailUrl], [song.duration].
  /// Does NOT fetch the stream manifest (that's [resolveStreamUrl]).
  /// Returns true on success, false on failure. Mutates [song] in place.
  Future<bool> resolveVideoId(Song song) async {
    if (song.youtubeVideoId != null) return true;
    song.status = SongResolutionStatus.resolving;

    final yt = YoutubeExplode();
    try {
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
          if (pickedId == null) {
            // The LLM looked at every candidate and decided none of them
            // are actually the requested song (likely a hallucinated /
            // non-existent track from generateSongs). Hard-fail so the
            // caller can drop the song and move on.
            debugPrint(
              'LLM rejected all candidates for "${song.title}" — ${song.artist}',
            );
            song.status = SongResolutionStatus.failed;
            return false;
          }
          chosen = topResults.firstWhere(
            (v) => v.id.value == pickedId,
            orElse: () => topResults.first,
          );
        } catch (e) {
          debugPrint(
            'LLM video pick failed for "${song.title}" — ${song.artist}: $e',
          );
        }
      }

      song.youtubeVideoId = chosen.id.value;
      song.thumbnailUrl = chosen.thumbnails.highResUrl;
      song.duration = chosen.duration;
      // Mark as resolved (= playable) once we have a videoId — the
      // stream URL is fetched lazily on demand.
      song.status = SongResolutionStatus.resolved;
      return true;
    } catch (e) {
      debugPrint('resolveVideoId failed for "${song.title}": $e');
      song.status = SongResolutionStatus.failed;
      return false;
    } finally {
      yt.close();
    }
  }

  /// Phase 2: fetch the audio stream manifest for an already-resolved
  /// videoId. Sets [song.streamUrl]. Returns true on success.
  /// If [song.youtubeVideoId] is null, this calls [resolveVideoId] first.
  Future<bool> resolveStreamUrl(Song song) async {
    if (song.streamUrl != null) return true;
    if (song.youtubeVideoId == null) {
      final ok = await resolveVideoId(song);
      if (!ok) return false;
    }

    // YouTube periodically breaks individual ytClients (signature changes,
    // ratelimits, region blocks). Try a chain of clients before giving up.
    const clients = [
      YoutubeApiClient.androidVr,
      YoutubeApiClient.tv,
      YoutubeApiClient.mweb,
      YoutubeApiClient.androidMusic,
    ];
    final yt = YoutubeExplode();
    try {
      Object? lastError;
      for (final client in clients) {
        try {
          await _waitForSlot();
          final manifest = await yt.videos.streamsClient.getManifest(
            VideoId(song.youtubeVideoId!),
            ytClients: [client],
          );
          final audioStreams = manifest.audioOnly.toList();
          if (audioStreams.isEmpty) {
            lastError = StateError('no audio streams from $client');
            continue;
          }
          // macOS/iOS AVFoundation cannot play WebM/Opus — restrict to
          // MP4/AAC (m4a) when available, falling back to the highest
          // bitrate otherwise.
          final mp4Streams = audioStreams
              .where((s) => s.container.name.toLowerCase() == 'mp4')
              .toList();
          final candidates = mp4Streams.isNotEmpty ? mp4Streams : audioStreams;
          candidates.sort((a, b) => b.bitrate.compareTo(a.bitrate));
          song.streamUrl = candidates.first.url.toString();
          return true;
        } catch (e) {
          lastError = e;
          debugPrint(
            'ytClient $client failed for "${song.title}": $e — trying next client',
          );
        }
      }
      debugPrint(
        'resolveStreamUrl exhausted all clients for "${song.title}": $lastError',
      );
      return false;
    } finally {
      yt.close();
    }
  }

  /// Convenience: ensures both videoId and streamUrl are populated.
  /// Used by the player when it needs to play right now.
  Future<bool> resolveSong(Song song) async {
    if (song.streamUrl != null) return true;
    if (song.youtubeVideoId == null) {
      final ok = await resolveVideoId(song);
      if (!ok) return false;
    }
    return resolveStreamUrl(song);
  }
}
