import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show FileImage, imageCache;
import 'package:uuid/uuid.dart';

import '../data/station_templates.dart';
import '../models/genre_preference.dart';
import '../models/radio_station.dart';
import '../models/song.dart';
import 'llm_service.dart';
import 'station_art_service.dart';
import 'station_storage.dart';
import 'youtube_service.dart';

/// Orchestrates LLM song generation + YouTube resolution + queue management
/// for all stations.
class StationEngine extends ChangeNotifier {
  final LlmService _llm;
  final YoutubeService _youtube;
  final StationStorage _storage;
  final StationArtService _art;
  final List<GenrePreference> Function() _tastesGetter;

  final List<RadioStation> _stations = [];
  final _uuid = const Uuid();

  // Coalesce rapid notifyListeners-driven saves.
  Timer? _saveDebounce;

  StationEngine({
    required LlmService llm,
    required YoutubeService youtube,
    required StationStorage storage,
    required StationArtService art,
    required List<GenrePreference> Function() tastesGetter,
  })  : _llm = llm,
        _youtube = youtube,
        _storage = storage,
        _art = art,
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

    // Resolve cover art for every template station that has a bundled tile
    // but no on-disk copy yet. This is async + safe to run in parallel
    // with warm-up; we notify when each one completes so the UI can
    // refresh its tile.
    unawaited(_hydrateBundledArt());

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

  Future<void> _hydrateBundledArt() async {
    for (final tpl in kStationTemplates) {
      final asset = tpl.imageAsset;
      if (asset == null) continue;
      final station = _stations.firstWhereOrNull((s) => s.id == tpl.id);
      if (station == null) continue;
      if (station.imagePath != null && File(station.imagePath!).existsSync()) {
        continue;
      }
      final path =
          await _art.ensureBundledCopy(stationId: tpl.id, assetPath: asset);
      if (path != null) {
        station.imagePath = path;
        _scheduleSave();
        notifyListeners();
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
    // Generate cover art in the background — don't block warm-up on it.
    // If Replicate is down/slow/disabled the tile just falls back to the
    // emoji.
    unawaited(_generateCustomArt(station));
    return station;
  }

  Future<void> _generateCustomArt(RadioStation station) async {
    final path = await _art.generateForCustomStation(
      stationId: station.id,
      moodPrompt: station.moodPrompt,
      name: station.name,
      tagline: station.tagline,
    );
    if (path != null) {
      station.imagePath = path;
      _scheduleSave();
      notifyListeners();
    }
  }

  /// Re-roll the cover art for a custom station. Stock stations are
  /// rejected — their art ships bundled and shouldn't change.
  Future<void> regenerateArtFor(RadioStation station) async {
    if (!station.isCustom) {
      throw StateError('Cannot regenerate art for stock station ${station.id}');
    }
    // Drop the old art so the UI shows the emoji placeholder while the
    // new tile is being generated, and so Image.file's path-keyed cache
    // doesn't keep serving the previous image after we overwrite it.
    final oldPath = station.imagePath;
    await _art.deleteArtFor(station.id);
    if (oldPath != null && oldPath.isNotEmpty) {
      // FileImage caches by path string, so even after we overwrite the
      // file at the same path the old bytes would still be served from
      // memory until the cache is evicted.
      imageCache.evict(FileImage(File(oldPath)));
    }
    station.imagePath = null;
    _scheduleSave();
    notifyListeners();
    await _generateCustomArt(station);
  }

  /// Permanently remove a station from the list, delete its persisted
  /// state (queue, history, cover art) and stop persisting it. Returns
  /// true if a station was actually removed.
  Future<bool> deleteStation(RadioStation station) async {
    final removed = _stations.remove(station);
    if (!removed) return false;
    if (station.isCustom) {
      // Stock stations have art bundled in the asset bundle — leave the
      // copy in app support dir alone (it'll just be re-used if the
      // station ever comes back). Custom-station art is purely on disk
      // and should be cleaned up.
      await _art.deleteArtFor(station.id);
    }
    _scheduleSave();
    notifyListeners();
    return true;
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

  /// Drop a song from the queue without ever adding it to history.
  /// Used when we couldn't resolve a playable YouTube video for it
  /// (the LLM hallucinated, or the song just isn't on YouTube) — we
  /// don't want phantom tracks polluting the listener's history.
  void discardSong(RadioStation station, Song song) {
    station.queue.remove(song);
    if (station.lastPlayedSongId == song.id) {
      station.lastPlayedSongId = null;
      station.lastPlayedPositionMs = null;
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
