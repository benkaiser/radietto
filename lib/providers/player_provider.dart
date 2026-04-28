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

  PlayerProvider({required this.audioHandler, required this.engine}) {
    audioHandler.onNearEnd = _handleNearEnd;
    audioHandler.onTrackComplete = _handleTrackComplete;
    audioHandler.onSkipNextRequested = skipCurrent;
  }

  RadioStation? get currentStation => _currentStation;
  Song? get currentSong => _currentSong;

  Future<void> playStation(RadioStation station) async {
    _currentStation = station;
    // Find first unplayed song (may need stream URL refresh).
    Song? next = station.firstPlayable ?? station.firstResolvableUnplayed;
    if (next == null) return;
    if (next.streamUrl == null) {
      final ok = await engine.ensureSongResolved(next);
      if (!ok) {
        // Skip this one and try the next resolvable.
        next.played = true;
        next = station.firstResolvableUnplayed;
        if (next == null) return;
        if (next.streamUrl == null) {
          await engine.ensureSongResolved(next);
        }
      }
    }
    if (next.streamUrl == null) return;
    _currentSong = next;
    notifyListeners();
    await audioHandler.playSong(next, stationName: station.name);
    _maybeReplenish();
  }

  Future<void> _advanceToNext() async {
    final station = _currentStation;
    if (station == null) return;

    if (_currentSong != null) {
      engine.markPlayed(station, _currentSong!);
    }

    Song? next = station.firstPlayable;
    // If next isn't resolved yet but exists, try to resolve.
    if (next == null) {
      // Find first unplayed pending song and resolve it.
      for (final s in station.queue) {
        if (!s.played && s.streamUrl == null) {
          final ok = await engine.ensureSongResolved(s);
          if (ok) {
            next = s;
            break;
          } else {
            s.played = true; // mark failed as played to skip past
          }
        }
      }
    }

    if (next == null) {
      // Nothing playable yet — try to replenish.
      await engine.replenish(station);
      next = station.firstPlayable;
    }

    if (next == null) {
      _currentSong = null;
      notifyListeners();
      return;
    }

    _currentSong = next;
    notifyListeners();
    await audioHandler.playSong(next, stationName: station.name);
    _maybeReplenish();
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
    if (s != null) s.rating = SongRating.skip;
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
