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

  PlayerProvider({required this.audioHandler, required this.engine}) {
    audioHandler.onNearEnd = _handleNearEnd;
    audioHandler.onTrackComplete = _handleTrackComplete;
    audioHandler.onSkipNextRequested = skipCurrent;
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
    _currentStation = station;
    final next = _pickNext(station);
    if (next == null) {
      _currentSong = null;
      notifyListeners();
      return;
    }
    await _playSongSnappy(station, next);
  }

  /// Show the song in the UI immediately, then resolve + load audio in the
  /// background. If the user skips again before audio loads, the in-flight
  /// load is abandoned via _playRequestId.
  Future<void> _playSongSnappy(RadioStation station, Song song) async {
    final requestId = ++_playRequestId;
    _currentStation = station;
    _currentSong = song;
    _isPreparing = true;
    notifyListeners();

    if (song.streamUrl == null) {
      final ok = await engine.ensureSongResolved(song);
      if (requestId != _playRequestId) return; // user skipped, abandon
      if (!ok) {
        song.played = true;
        // Try the next candidate.
        await _advanceToNext();
        return;
      }
    }

    if (requestId != _playRequestId) return;
    try {
      await audioHandler.playSong(song, stationName: station.name);
    } catch (e) {
      debugPrint('Audio load failed for "${song.title}": $e');
      if (requestId != _playRequestId) return;
      song.played = true;
      await _advanceToNext();
      return;
    }
    if (requestId != _playRequestId) return;
    _isPreparing = false;
    notifyListeners();
    _maybeReplenish();
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

  Future<void> _handleNearEnd() async {
    // Lazily resolve the next song's stream if it isn't ready.
    final station = _currentStation;
    if (station == null) return;
    for (final s in station.queue) {
      if (!s.played && s != _currentSong && s.streamUrl == null) {
        await engine.ensureSongResolved(s);
        break;
      }
    }
  }

  Future<void> _handleTrackComplete() async {
    await _advanceToNext();
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
}
