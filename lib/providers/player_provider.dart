import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/radio_station.dart';
import '../models/song.dart';
import '../models/song_rating.dart';
import '../services/audio_handler.dart';
import '../services/station_engine.dart';

class PlayerProvider extends ChangeNotifier {
  final RadiettoAudioHandler audioHandler;
  final StationEngine engine;

  RadioStation? _currentStation;
  Song? _currentSong;

  /// Bumped on every user-visible song change so in-flight resolves/loads
  /// from a previous song are ignored if the user skipped past them.
  int _playRequestId = 0;

  /// True while a song's audio is still being prepared (URL resolved /
  /// AVPlayer loading). The Now Playing UI uses this to render a "loading
  /// duration" placeholder so skips feel snappy — the title/artist update
  /// instantly even though the stream isn't ready yet.
  bool _isPreparing = false;

  /// Position to seek to once the next song's audio has finished loading.
  /// Set by [playStation] when resuming a station mid-song.
  Duration? _pendingResumePosition;

  /// Whether we've already retried the current song after a playback
  /// error. Lets us refresh the YouTube stream URL once before giving
  /// up and skipping.
  bool _hasRetriedCurrent = false;

  /// Bookkeeping so we don't hammer the disk on every position tick;
  /// we only persist progress once per [_positionSaveInterval].
  static const Duration _positionSaveInterval = Duration(seconds: 5);
  DateTime _lastPositionSave = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<Duration>? _positionSub;

  PlayerProvider({required this.audioHandler, required this.engine}) {
    audioHandler.onNearEnd = _handleNearEnd;
    audioHandler.onTrackComplete = _handleTrackComplete;
    audioHandler.onSkipNextRequested = skipCurrent;
    audioHandler.onPlaybackError = _handlePlaybackError;
    _positionSub =
        audioHandler.player.positionStream.listen(_onPositionTick);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  void _onPositionTick(Duration pos) {
    final station = _currentStation;
    final song = _currentSong;
    if (station == null || song == null) return;
    if (_isPreparing) return;
    final now = DateTime.now();
    if (now.difference(_lastPositionSave) < _positionSaveInterval) return;
    _lastPositionSave = now;
    engine.recordPlaybackPosition(
      station: station,
      songId: song.id,
      positionMs: pos.inMilliseconds,
    );
  }

  RadioStation? get currentStation => _currentStation;
  Song? get currentSong => _currentSong;
  bool get isPreparing => _isPreparing;

  /// Pick the next unplayed song to play. Prefers ones with a ready
  /// streamUrl, then ones with a videoId we can refresh, then any unplayed
  /// song (which we'll resolve from scratch). Does NOT mutate state.
  Song? _pickNext(RadioStation station) {
    Song? withStream;
    Song? withVideoId;
    Song? anyUnplayed;
    for (final s in station.queue) {
      if (s.played) continue;
      anyUnplayed ??= s;
      if (s.youtubeVideoId != null) withVideoId ??= s;
      if (s.streamUrl != null) {
        withStream = s;
        break;
      }
    }
    return withStream ?? withVideoId ?? anyUnplayed;
  }

  Future<void> playStation(RadioStation station) async {
    debugPrint('▶ playStation("${station.name}") — '
        'queue=${station.queue.length} unplayed=${station.unplayedCount} '
        'isWarmed=${station.isWarmedUp} isGenerating=${station.isGenerating}');
    _currentStation = station;

    // If this station has a saved playback position from a previous
    // session/listen, try to resume the same song mid-stream — that's
    // how a real radio station behaves when you tune back to it.
    Song? resumeTarget;
    if (station.lastPlayedSongId != null) {
      for (final s in station.queue) {
        if (s.id == station.lastPlayedSongId && !s.played) {
          resumeTarget = s;
          break;
        }
      }
    }

    final next = resumeTarget ?? _pickNext(station);
    if (next == null) {
      _currentSong = null;
      notifyListeners();
      return;
    }

    if (resumeTarget != null && station.lastPlayedPositionMs != null) {
      _pendingResumePosition =
          Duration(milliseconds: station.lastPlayedPositionMs!);
    }
    await _playSongSnappy(station, next);
  }

  /// Show the song in the UI immediately, then resolve + load audio in the
  /// background. If the user skips again before audio loads, the in-flight
  /// load is abandoned via _playRequestId.
  Future<void> _playSongSnappy(RadioStation station, Song song) async {
    final requestId = ++_playRequestId;
    debugPrint('▶ _playSongSnappy(req=$requestId) "${song.title}" — '
        'videoId=${song.youtubeVideoId} streamUrl=${song.streamUrl != null ? 'set' : 'null'}');
    _currentStation = station;
    _currentSong = song;
    _isPreparing = true;
    _hasRetriedCurrent = false;
    notifyListeners();

    if (song.streamUrl == null) {
      debugPrint('  ↳ resolving stream for "${song.title}"…');
      final ok = await engine.ensureSongResolved(song);
      debugPrint('  ↳ ensureSongResolved("${song.title}") → $ok');
      if (requestId != _playRequestId) {
        debugPrint('  ↳ stale request, abandoning');
        return;
      }
      if (!ok) {
        debugPrint('  ↳ discarding "${song.title}" and advancing');
        await _discardAndAdvance(song);
        return;
      }
    }

    if (requestId != _playRequestId) return;
    try {
      await audioHandler.playSong(song, stationName: station.name, stationArtUri: _artUriFor(station));
    } catch (e) {
      debugPrint('Audio load failed for "${song.title}": $e');
      if (requestId != _playRequestId) return;
      await _discardAndAdvance(song);
      return;
    }
    if (requestId != _playRequestId) return;

    // If we were resuming a station mid-song, seek now that the audio
    // has loaded. Clamp to a few seconds before the end so we don't
    // immediately fire processingState.completed.
    final resumeTo = _pendingResumePosition;
    _pendingResumePosition = null;
    if (resumeTo != null && resumeTo > const Duration(seconds: 1)) {
      final dur = song.duration;
      final safe = (dur != null && resumeTo >= dur - const Duration(seconds: 5))
          ? Duration.zero
          : resumeTo;
      if (safe > Duration.zero) {
        await audioHandler.seek(safe);
      }
    }

    _isPreparing = false;
    notifyListeners();
    _maybeReplenish();
    // Speculative: while this song plays, resolve the videoId for the
    // next unplayed song so that when we hit near-end (or the user
    // skips) we only have the cheap streamUrl manifest fetch left.
    _prefetchNextVideoId();
  }

  /// Find the next unplayed song after [_currentSong] and resolve its
  /// videoId in the background (no stream URL fetch yet). If the LLM
  /// picker rejects every candidate (or YouTube has nothing), discard
  /// the song eagerly so we don't waste another search+LLM round-trip
  /// re-asking the same question when we reach it.
  void _prefetchNextVideoId() {
    final station = _currentStation;
    if (station == null) return;
    for (final s in station.queue) {
      if (!s.played && s != _currentSong) {
        if (s.youtubeVideoId == null) {
          unawaited(() async {
            final ok = await engine.ensureVideoIdResolved(s);
            if (!ok && _currentStation == station && s != _currentSong) {
              debugPrint('Prefetch: discarding unresolvable "${s.title}"');
              engine.discardSong(station, s);
              // Try the song after it.
              _prefetchNextVideoId();
            }
          }());
        }
        return;
      }
    }
  }

  Future<void> _advanceToNext() async {
    final station = _currentStation;
    if (station == null) return;

    if (_currentSong != null) {
      engine.markPlayed(station, _currentSong!);
    }

    Song? next = _pickNext(station);
    if (next == null) {
      // Nothing in queue at all — replenish synchronously then try again.
      await engine.replenish(station);
      next = _pickNext(station);
    }

    if (next == null) {
      _currentSong = null;
      _isPreparing = false;
      notifyListeners();
      return;
    }

    await _playSongSnappy(station, next);
  }

  /// Discard [failed] (remove from queue, do NOT add to history) and play
  /// the next pickable song. Used when we can't resolve a YouTube video
  /// for an LLM-generated track or the audio fails to load at all.
  Future<void> _discardAndAdvance(Song failed) async {
    final station = _currentStation;
    if (station == null) return;
    debugPrint('✂ _discardAndAdvance "${failed.title}" — '
        'queue size before=${station.queue.length}');
    engine.discardSong(station, failed);
    if (_currentSong == failed) _currentSong = null;

    Song? next = _pickNext(station);
    if (next == null) {
      debugPrint('  ↳ queue empty after discard, replenishing…');
      await engine.replenish(station);
      next = _pickNext(station);
      debugPrint('  ↳ post-replenish next=${next?.title ?? 'NULL'}');
    }
    if (next == null) {
      debugPrint('  ↳ still no song after replenish; giving up');
      _isPreparing = false;
      notifyListeners();
      return;
    }
    await _playSongSnappy(station, next);
  }

  Future<void> _handleNearEnd() async {
    // ~20s before the current track ends, resolve the stream URL for the
    // next unplayed song. The videoId should already be resolved from
    // _prefetchNextVideoId() that ran when the current song started.
    final station = _currentStation;
    if (station == null) return;
    for (final s in station.queue) {
      if (!s.played && s != _currentSong && s.streamUrl == null) {
        // ensureSongResolved handles both videoId + streamUrl if needed.
        await engine.ensureSongResolved(s);
        break;
      }
    }
  }

  Future<void> _handleTrackComplete() async {
    await _advanceToNext();
  }

  /// Called by [audioHandler] when the underlying player emits an error
  /// (network drop, expired URL, decoder failure, etc). We give the
  /// current song one shot at a fresh stream URL before skipping.
  Future<void> _handlePlaybackError(Object error) async {
    final station = _currentStation;
    final song = _currentSong;
    if (station == null || song == null) return;

    debugPrint('Playback error on "${song.title}": $error');

    if (_hasRetriedCurrent) {
      // Already retried once — give up on this track.
      debugPrint('Already retried; advancing to next song.');
      song.played = true;
      await _advanceToNext();
      return;
    }
    _hasRetriedCurrent = true;

    // Resume from where we were when it failed (don't restart the song
    // from the beginning).
    final resumeFrom = audioHandler.player.position;
    if (resumeFrom > const Duration(seconds: 2)) {
      _pendingResumePosition = resumeFrom;
    }

    // Drop the stale URL and re-fetch a fresh one from YouTube.
    song.streamUrl = null;
    final requestId = ++_playRequestId;
    _isPreparing = true;
    notifyListeners();

    final ok = await engine.ensureStreamUrlResolved(song);
    if (requestId != _playRequestId) return;
    if (!ok) {
      song.played = true;
      await _advanceToNext();
      return;
    }

    try {
      await audioHandler.playSong(song, stationName: station.name, stationArtUri: _artUriFor(station));
    } catch (e) {
      if (requestId != _playRequestId) return;
      song.played = true;
      await _advanceToNext();
      return;
    }
    if (requestId != _playRequestId) return;

    final resumeTo = _pendingResumePosition;
    _pendingResumePosition = null;
    if (resumeTo != null && resumeTo > const Duration(seconds: 1)) {
      await audioHandler.seek(resumeTo);
    }

    _isPreparing = false;
    notifyListeners();
  }

  Future<void> skipCurrent() async {
    final s = _currentSong;
    // Only mark as a "skip" if the user hasn't already given the song an
    // explicit rating (e.g. thumbs up) — a thumbs-up + skip should keep the
    // upvote so the LLM still treats this song as a positive signal.
    if (s != null && s.rating == null) s.rating = SongRating.skip;
    await _advanceToNext();
  }

  Future<void> thumbsUp() async {
    final s = _currentSong;
    if (s == null) return;
    s.rating = SongRating.thumbsUp;
    notifyListeners();
  }

  Future<void> thumbsDown() async {
    final s = _currentSong;
    if (s == null) return;
    s.rating = SongRating.thumbsDown;
    notifyListeners();
    // Auto-skip on thumbs down (Pandora-style).
    await _advanceToNext();
  }

  /// Toggle a rating on any song (typically from the history list — the
  /// caller doesn't have to be the currently-playing song). Tapping the
  /// same rating again clears it.
  void rateSong(Song song, SongRating rating) {
    if (song.rating == rating) {
      song.rating = null;
    } else {
      song.rating = rating;
    }
    engine.persistRatings();
    notifyListeners();
  }

  /// Replay a song from the history list. The song stays in history (we
  /// don't reorder anything) and once it finishes we resume the regular
  /// forward-only queue — true to the spirit of radio.
  Future<void> playFromHistory(Song song) async {
    final station = _currentStation;
    if (station == null) return;
    await _playSongSnappy(station, song);
  }

  Future<void> togglePlayPause() async {
    if (audioHandler.player.playing) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  }

  void _maybeReplenish() {
    final station = _currentStation;
    if (station == null) return;
    if (station.unplayedCount <= 2 && !station.isGenerating) {
      // Fire-and-forget; engine will notify listeners as it progresses.
      engine.replenish(station);
    }
  }

  /// Build a `file://` URI for the station's cover art if one is available
  /// on disk. Returned to the OS media controls so notifications/lock
  /// screens can show the station tile.
  Uri? _artUriFor(RadioStation station) {
    final p = station.imagePath;
    if (p == null || p.isEmpty) return null;
    if (!File(p).existsSync()) return null;
    return Uri.file(p);
  }
}
