import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                            : (player.audioHandler.player.duration ??
                                song.duration ??
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
                    const SizedBox(height: 16),
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
