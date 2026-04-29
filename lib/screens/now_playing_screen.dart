import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/radio_station.dart';
import '../models/song.dart';
import '../models/song_rating.dart';
import '../providers/player_provider.dart';

/// Width at and above which we switch to the two-column desktop layout
/// (player on the left, history list on the right).
const double _desktopBreakpoint = 900;

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;
    final station = player.currentStation;

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
                  final isDesktop =
                      constraints.maxWidth >= _desktopBreakpoint;
                  if (isDesktop) {
                    return _DesktopLayout(
                      player: player,
                      station: station,
                      song: song,
                    );
                  }
                  return _MobileLayout(
                    player: player,
                    station: station,
                    song: song,
                    viewportHeight: constraints.maxHeight,
                  );
                },
              ),
            ),
    );
  }
}

/// Phone/tablet portrait — vertical stack, history below the controls.
class _MobileLayout extends StatelessWidget {
  final PlayerProvider player;
  final RadioStation station;
  final Song song;
  final double viewportHeight;

  const _MobileLayout({
    required this.player,
    required this.station,
    required this.song,
    required this.viewportHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewportHeight),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _StationHeader(station: station, emojiSize: 140),
                const SizedBox(height: 32),
                _SongTitle(song: song),
                const Spacer(),
                _ScrubberAndControls(player: player, song: song),
                const SizedBox(height: 24),
                _HistorySection(
                  station: station,
                  currentSong: song,
                  player: player,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide windows — two columns: the player panel on the left, history
/// list as a sidebar on the right.
class _DesktopLayout extends StatelessWidget {
  final PlayerProvider player;
  final RadioStation station;
  final Song song;

  const _DesktopLayout({
    required this.player,
    required this.station,
    required this.song,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Player panel — centered vertically, capped width so the
          // controls don't span an absurdly wide screen.
          Expanded(
            flex: 3,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StationHeader(station: station, emojiSize: 120),
                    const SizedBox(height: 24),
                    _SongTitle(song: song),
                    const SizedBox(height: 32),
                    _ScrubberAndControls(player: player, song: song),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 32),
          // History sidebar.
          Expanded(
            flex: 2,
            child: _HistorySidebar(
              station: station,
              currentSong: song,
              player: player,
            ),
          ),
        ],
      ),
    );
  }
}

class _StationHeader extends StatelessWidget {
  final RadioStation station;
  final double emojiSize;
  const _StationHeader({required this.station, required this.emojiSize});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(station.emoji, style: TextStyle(fontSize: emojiSize)),
        const SizedBox(height: 8),
        Text(
          station.tagline,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontStyle: FontStyle.italic),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SongTitle extends StatelessWidget {
  final Song song;
  const _SongTitle({required this.song});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
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
      ],
    );
  }
}

class _ScrubberAndControls extends StatelessWidget {
  final PlayerProvider player;
  final Song song;
  const _ScrubberAndControls({required this.player, required this.song});

  static String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
      ],
    );
  }
}

/// Mobile: history rendered inline below the controls (flat list,
/// expanding the page).
class _HistorySection extends StatelessWidget {
  final RadioStation station;
  final Song currentSong;
  final PlayerProvider player;

  const _HistorySection({
    required this.station,
    required this.currentSong,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            onPlay: () => player.playFromHistory(s),
            onRate: (r) => player.rateSong(s, r),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Desktop: history is a fixed-height side panel that scrolls
/// independently of the player area.
class _HistorySidebar extends StatelessWidget {
  final RadioStation station;
  final Song currentSong;
  final PlayerProvider player;

  const _HistorySidebar({
    required this.station,
    required this.currentSong,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = station.history
        .where((s) => s.id != currentSong.id)
        .toList()
        .reversed
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Played earlier',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: history.isEmpty
              ? Center(
                  child: Text(
                    'Nothing played yet.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                )
              : Material(
                  type: MaterialType.transparency,
                  child: ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.06),
                    ),
                    itemBuilder: (_, i) {
                      final s = history[i];
                      return _HistoryTile(
                        song: s,
                        onPlay: () => player.playFromHistory(s),
                        onRate: (r) => player.rateSong(s, r),
                      );
                    },
                  ),
                ),
        ),
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
