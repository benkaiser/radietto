import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';

/// Audio handler wrapping just_audio + audio_service for background playback.
class RadiettoAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  /// Called when the player is in the last 20 seconds of the current track —
  /// the queue engine uses this to lazily resolve the next track.
  Future<void> Function()? onNearEnd;

  /// Called when the current track ends — the queue engine should advance.
  Future<void> Function()? onTrackComplete;

  /// Called when a skip is requested (next).
  Future<void> Function()? onSkipNextRequested;

  bool _nearEndFired = false;

  RadiettoAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Position-based lazy prefetch trigger.
    _player.positionStream.listen((pos) {
      final dur = _player.duration;
      if (dur != null && !_nearEndFired) {
        final remaining = dur - pos;
        if (remaining.inSeconds <= 20 && remaining.inSeconds > 0) {
          _nearEndFired = true;
          onNearEnd?.call();
        }
      }
    });

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        onTrackComplete?.call();
      }
    });
  }

  Future<void> playSong(Song song, {String? stationName}) async {
    if (song.streamUrl == null) {
      throw StateError('Song has no streamUrl yet');
    }
    _nearEndFired = false;
    final mediaItem = MediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: stationName,
      duration: song.duration,
      // Intentionally no artUri — YouTube signed thumbnail URLs were
      // tripping up flutter_cache_manager's SQLite cache (database locked).
      // The in-app UI uses station emojis, so the media notification just
      // gets the default placeholder. We can revisit later with a bundled
      // asset or per-station local image.
    );
    this.mediaItem.add(mediaItem);
    await _player.setUrl(song.streamUrl!);
    // YouTube's androidVr client sometimes returns MP4 audio whose
    // container duration is ~2× the real track length (extra silent
    // padding). Clip playback to the duration we got from YouTube
    // search metadata so just_audio reports the correct length and
    // fires processingState.completed at the right moment.
    if (song.duration != null && song.duration! > Duration.zero) {
      await _player.setClip(end: song.duration);
    }
    // IMPORTANT: do NOT `await _player.play()` — its future doesn't
    // complete until playback is paused/stopped/ends, which would block
    // the caller (and leave PlayerProvider.isPreparing=true forever).
    unawaited(_player.play());
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    await onSkipNextRequested?.call();
  }

  AudioPlayer get player => _player;

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.pause,
        MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
