import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/radio_station.dart';
import '../models/song.dart';
import '../models/song_rating.dart';
import '../providers/player_provider.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    final station = player.currentStation;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(station?.name ?? 'Now Playing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: song == null || station == null
          ? const Center(child: Text('Nothing playing'))
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              Text(station.emoji,
                                  style: const TextStyle(fontSize: 140)),
                              const SizedBox(height: 8),
                              Text(
                                station.tagline,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontStyle: FontStyle.italic),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              Text(
                                song.title,
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                song.artist,
                                style: theme.textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const Spacer(),
                    StreamBuilder<Duration>(
                      stream: player.audioHandler.player.positionStream,
                      builder: (context, snap) {
                        final preparing = player.isPreparing;
                        final pos = snap.data ?? Duration.zero;
                        final dur = preparing
                            ? Duration.zero
                            : (song.duration ??
                                player.audioHandler.player.duration ??
                                Duration.zero);
                        final maxV = dur.inSeconds.toDouble().clamp(1.0, double.infinity);
                        final cur = pos.inSeconds.toDouble().clamp(0.0, maxV);
                        return Column(
                          children: [
                            Slider(
                              value: cur,
                              min: 0,
                              max: maxV.toDouble(),
                              onChanged: preparing
                                  ? null
                                  : (v) => player.audioHandler
                                      .seek(Duration(seconds: v.toInt())),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(preparing ? '--:--' : _format(pos)),
                                  Text(preparing ? '--:--' : _format(dur)),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          iconSize: 36,
                          icon: Icon(
                            Icons.thumb_down,
                            color: song.rating == SongRating.thumbsDown
                                ? Colors.red
                                : null,
                          ),
                          onPressed: () => player.thumbsDown(),
                        ),
                        StreamBuilder<bool>(
                          stream: player.audioHandler.player.playingStream,
                          builder: (context, snap) {
                            final playing = snap.data ?? false;
                            return IconButton(
                              iconSize: 64,
                              icon: Icon(
                                playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                              ),
                              onPressed: () => player.togglePlayPause(),
                            );
                          },
                        ),
                        IconButton(
                          iconSize: 36,
                          icon: Icon(
                            Icons.thumb_up,
                            color: song.rating == SongRating.thumbsUp
                                ? Colors.green
                                : null,
                          ),
                          onPressed: () => player.thumbsUp(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => player.skipCurrent(),
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Skip'),
                    ),
                    const SizedBox(height: 24),
                    _HistorySection(
                      station: station,
                      currentSong: song,
                      onPlay: (s) => player.playFromHistory(s),
                      onRate: (s, r) => player.rateSong(s, r),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
                },
              ),
            ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final RadioStation station;
  final Song currentSong;
  final void Function(Song) onPlay;
  final void Function(Song, SongRating) onRate;

  const _HistorySection({
    required this.station,
    required this.currentSong,
    required this.onPlay,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Newest first; exclude the song currently playing (it's already
    // featured at the top of the screen).
    final history = station.history
        .where((s) => s.id != currentSong.id)
        .toList()
        .reversed
        .toList();
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Played earlier',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final s in history)
          _HistoryTile(
            song: s,
            onPlay: () => onPlay(s),
            onRate: (r) => onRate(s, r),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Song song;
  final VoidCallback onPlay;
  final void Function(SongRating) onRate;

  const _HistoryTile({
    required this.song,
    required this.onPlay,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.replay, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.artist,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Thumbs down',
              icon: Icon(
                Icons.thumb_down,
                size: 18,
                color: song.rating == SongRating.thumbsDown
                    ? Colors.red
                    : null,
              ),
              onPressed: () => onRate(SongRating.thumbsDown),
            ),
            IconButton(
              tooltip: 'Thumbs up',
              icon: Icon(
                Icons.thumb_up,
                size: 18,
                color: song.rating == SongRating.thumbsUp
                    ? Colors.green
                    : null,
              ),
              onPressed: () => onRate(SongRating.thumbsUp),
            ),
          ],
        ),
      ),
    );
  }
}
