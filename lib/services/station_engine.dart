import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/station_templates.dart';
import '../models/genre_preference.dart';
import '../models/radio_station.dart';
import '../models/song.dart';
import 'llm_service.dart';
import 'station_storage.dart';
import 'youtube_service.dart';

/// Orchestrates LLM song generation + YouTube resolution + queue management
/// for all stations.
class StationEngine extends ChangeNotifier {
  final LlmService _llm;
  final YoutubeService _youtube;
  final StationStorage _storage;
  final List<GenrePreference> Function() _tastesGetter;

  final List<RadioStation> _stations = [];
  final _uuid = const Uuid();

  // Coalesce rapid notifyListeners-driven saves.
  Timer? _saveDebounce;

  StationEngine({
    required LlmService llm,
    required YoutubeService youtube,
    required StationStorage storage,
    required List<GenrePreference> Function() tastesGetter,
  })  : _llm = llm,
        _youtube = youtube,
        _storage = storage,
        _tastesGetter = tastesGetter;

  List<RadioStation> get stations => List.unmodifiable(_stations);

  /// Restore stations from disk and (only if needed) warm up missing ones.
  Future<void> initializeDefaults() async {
    if (_stations.isNotEmpty) return;

    // Load any persisted stations first.
    final persisted = await _storage.load();
    final persistedById = {for (final s in persisted) s.id: s};

    // Ensure all template stations exist; preserve persisted custom stations.
    for (final tpl in kStationTemplates) {
      if (persistedById.containsKey(tpl.id)) {
        _stations.add(persistedById.remove(tpl.id)!);
      } else {
        _stations.add(RadioStation(
          id: tpl.id,
          name: tpl.name,
          tagline: tpl.tagline,
          emoji: tpl.emoji,
          moodPrompt: tpl.moodPrompt,
        ));
      }
    }
    // Any remaining persisted stations are user-created customs — keep them
    // pinned at the top of the list.
    final customs = persistedById.values.where((s) => s.isCustom).toList();
    for (final c in customs.reversed) {
      _stations.insert(0, c);
    }

    notifyListeners();

    // Only warm up stations that don't already have any unplayed songs in
    // their queue. videoIds and stream URLs are resolved just-in-time.
    for (final station in _stations) {
      final hasUnplayedSong = station.queue.any((s) => !s.played);
      if (!hasUnplayedSong) {
        // Don't await — let stations warm in parallel.
        _warmUpStation(station);
      } else {
        // Persisted queues already have songs — they're warm.
        station.isWarmedUp = true;
      }
    }
  }

  /// Add a custom prompt-based station.
  Future<RadioStation> addCustomStation(String userPrompt) async {
    final meta = await _llm.generateStationFromPrompt(userPrompt);
    final station = RadioStation(
      id: _uuid.v4(),
      name: meta.name,
      tagline: meta.tagline,
      emoji: meta.emoji.isEmpty ? '🎧' : meta.emoji,
      moodPrompt: meta.moodPrompt,
      isCustom: true,
    );
    _stations.insert(0, station);
    notifyListeners();
    _scheduleSave();
    _warmUpStation(station);
    return station;
  }

  Future<void> _warmUpStation(RadioStation station) async {
    if (station.isGenerating) return;
    station.isGenerating = true;
    notifyListeners();
    try {
      final songs = await _llm.generateSongs(
        moodPrompt: station.moodPrompt,
        tastes: _tastesGetter(),
        history: station.history,
        currentQueue: station.queue,
        count: 5,
      );
      station.queue.addAll(songs);
      // Station is "warm" as soon as the LLM has produced song candidates.
      // YouTube videoId search and stream URL resolution are deferred
      // until just-in-time (the player drives them).
      station.isWarmedUp = true;
      _scheduleSave();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to warm up station ${station.name}: $e');
    } finally {
      station.isGenerating = false;
      notifyListeners();
    }
  }

  /// Replenish the queue with N more songs (called when only 2 unplayed remain).
  Future<void> replenish(RadioStation station, {int count = 5}) async {
    if (station.isGenerating) return;
    station.isGenerating = true;
    notifyListeners();
    try {
      final songs = await _llm.generateSongs(
        moodPrompt: station.moodPrompt,
        tastes: _tastesGetter(),
        history: station.history,
        currentQueue: station.queue,
        count: count,
      );
      station.queue.addAll(songs);
      _scheduleSave();
      notifyListeners();
      // YouTube resolution is deferred — happens just-in-time when the
      // player needs the song.
    } catch (e) {
      debugPrint('Failed to replenish ${station.name}: $e');
    } finally {
      station.isGenerating = false;
      notifyListeners();
    }
  }

  /// Resolve a specific song fully (videoId + streamUrl). Used by the player
  /// when it needs to start playback right now.
  Future<bool> ensureSongResolved(Song song) async {
    if (song.streamUrl != null) return true;
    final ok = await _youtube.resolveSong(song);
    notifyListeners();
    return ok;
  }

  /// Resolve only the YouTube videoId for [song] (search + LLM pick) — does
  /// not fetch the stream URL. Cheap enough to do speculatively for the
  /// next track in the queue while the current one plays.
  Future<bool> ensureVideoIdResolved(Song song) async {
    if (song.youtubeVideoId != null) return true;
    final ok = await _youtube.resolveVideoId(song);
    notifyListeners();
    return ok;
  }

  /// Resolve only the stream URL for [song] (assumes videoId already set).
  /// Used for lazy prefetch ~20s before the current song ends.
  Future<bool> ensureStreamUrlResolved(Song song) async {
    if (song.streamUrl != null) return true;
    final ok = await _youtube.resolveStreamUrl(song);
    notifyListeners();
    return ok;
  }

  /// Mark a song as played and move it to history.
  void markPlayed(RadioStation station, Song song) {
    song.played = true;
    if (!station.history.contains(song)) {
      station.history.add(song);
    }
    _scheduleSave();
    notifyListeners();
  }

  /// Wipe ALL listening state — every station is removed (including custom
  /// ones) and persistence is cleared. Templates are then re-seeded and
  /// warmed up afresh. Used by the Settings "reset listening history" flow.
  Future<void> resetAll() async {
    _saveDebounce?.cancel();
    _stations.clear();
    await _storage.clear();
    notifyListeners();
    await initializeDefaults();
  }

  /// Drop every unplayed song from every station's queue and re-warm them
  /// in display order (top-down) so refilled queues appear naturally rather
  /// than at random times. Called when the user changes their tastes —
  /// existing pre-generated queues no longer reflect the new preferences.
  /// The currently playing track (held by the audio handler) keeps playing;
  /// once it ends the next track will come from the freshly-generated queue.
  Future<void> regenerateAllStations() async {
    for (final station in _stations) {
      station.queue.removeWhere((s) => !s.played);
      station.isWarmedUp = false;
    }
    _scheduleSave();
    notifyListeners();

    // Snapshot the order at call time — _stations is mutable.
    final ordered = List<RadioStation>.from(_stations);
    for (final station in ordered) {
      // Wait for any in-flight generation (with old tastes) to finish, then
      // drop those stale songs before warming up afresh.
      while (station.isGenerating) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      station.queue.removeWhere((s) => !s.played);
      station.isWarmedUp = false;
      notifyListeners();
      await _warmUpStation(station);
    }
  }

  void notifyChange() {
    _scheduleSave();
    notifyListeners();
  }

  /// Public hook for callers (e.g. PlayerProvider rating a history song)
  /// that have already mutated state on a Song and just need it persisted.
  void persistRatings() {
    _scheduleSave();
    notifyListeners();
  }

  /// Record the current playback position for [station] so we can resume
  /// mid-song if the user switches stations or relaunches the app.
  /// Intentionally does NOT call notifyListeners — this fires very often.
  void recordPlaybackPosition({
    required RadioStation station,
    required String songId,
    required int positionMs,
  }) {
    station.lastPlayedSongId = songId;
    station.lastPlayedPositionMs = positionMs;
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      _storage.save(_stations);
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    // Best-effort flush on dispose.
    _storage.save(_stations);
    super.dispose();
  }
}
