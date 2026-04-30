import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/radio_station.dart';
import '../providers/player_provider.dart';
import '../services/station_engine.dart';
import '../widgets/mini_player.dart';
import 'taste_onboarding_screen.dart';
import 'settings_screen.dart';

class RadioBrowserScreen extends StatefulWidget {
  const RadioBrowserScreen({super.key});

  @override
  State<RadioBrowserScreen> createState() => _RadioBrowserScreenState();
}

class _RadioBrowserScreenState extends State<RadioBrowserScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) {
        _initialized = true;
        context.read<StationEngine>().initializeDefaults();
      }
    });
  }

  Future<void> _onTapStation(RadioStation station) async {
    if (!station.isWarmedUp || station.firstUnplayed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          content: Text('Station is still warming up…'),
        ),
      );
      return;
    }
    // Just start audio. The mini-player at the bottom appears; user can
    // tap that to open the full NowPlayingScreen.
    await context.read<PlayerProvider>().playStation(station);
  }

  Future<void> _showStationMenu(
      RadioStation station, Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    // Custom stations support both regenerate-art and delete; stock
    // stations get nothing (no menu) — their art is bundled and we
    // don't want users deleting the defaults.
    if (!station.isCustom) return;
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'regenerate-art',
          child: Row(children: [
            Icon(Icons.refresh, size: 18),
            SizedBox(width: 12),
            Text('Regenerate cover art'),
          ]),
        ),
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outline, size: 18, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete station', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
    if (!mounted || selection == null) return;
    switch (selection) {
      case 'regenerate-art':
        await _regenerateArt(station);
        break;
      case 'delete':
        await _confirmAndDelete(station);
        break;
    }
  }

  Future<void> _regenerateArt(RadioStation station) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('Regenerating cover art…'),
      ),
    );
    try {
      await context.read<StationEngine>().regenerateArtFor(station);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to regenerate art: $e')),
      );
    }
  }

  Future<void> _confirmAndDelete(RadioStation station) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${station.name}?'),
        content: const Text(
          'This permanently removes the station, its queue and its '
          'listening history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Stop playback first if this station is currently on air.
    await context.read<PlayerProvider>().stopIfPlaying(station);
    if (!mounted) return;
    await context.read<StationEngine>().deleteStation(station);
  }

  Future<void> _showCustomStationSheet() async {
    final controller = TextEditingController();
    final prompt = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Spawn a custom station',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Describe a vibe or scenario — e.g. "cooking dinner and feeling fancy".',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'A sunny bike ride with family…',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Create Station'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (prompt == null || prompt.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crafting your station…')),
    );
    try {
      await context.read<StationEngine>().addCustomStation(prompt);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create station: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<StationEngine>();
    final stations = engine.stations;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radietto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Tune tastes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const TasteOnboardingScreen(isReturningEdit: true),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCustomStationSheet,
        icon: const Icon(Icons.add),
        label: const Text('Custom'),
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: stations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              // Desktop-friendly: cap card width so the grid grows columns
              // on wider windows instead of stretching two giant cards
              // across the screen. On phones this still gives one or two
              // columns naturally.
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemCount: stations.length,
              itemBuilder: (context, i) {
                final s = stations[i];
                return _StationCard(
                  station: s,
                  onTap: () => _onTapStation(s),
                  onContextMenu: (globalPos) => _showStationMenu(s, globalPos),
                );
              },
            ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final RadioStation station;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onContextMenu;
  const _StationCard({
    required this.station,
    required this.onTap,
    this.onContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = station.isWarmedUp && station.firstUnplayed != null;
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _StationCardArt(station: station),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    station.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        station.tagline,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (!ready) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        const Text('Warming up…',
                            style: TextStyle(fontSize: 12)),
                      ] else ...[
                        Icon(Icons.play_circle,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        const Text('Ready', style: TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
    if (onContextMenu == null) return card;
    // GestureDetector handles both right-click on desktop
    // (onSecondaryTapDown) and long-press on mobile (onLongPressStart),
    // dispatching the global tap position to the host screen so it can
    // anchor a popup menu there.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (d) => onContextMenu!(d.globalPosition),
      onLongPressStart: (d) => onContextMenu!(d.globalPosition),
      child: card,
    );
  }
}

/// Renders the station's bundled / generated cover-art file when present,
/// otherwise falls back to a centered emoji on a tinted background. The
/// emoji is also shown while a custom-station tile is still being
/// generated by Replicate.
class _StationCardArt extends StatelessWidget {
  final RadioStation station;
  const _StationCardArt({required this.station});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = station.imagePath;
    if (p != null && p.isNotEmpty) {
      final file = File(p);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => _emojiFallback(theme),
        );
      }
    }
    return _emojiFallback(theme);
  }

  Widget _emojiFallback(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(station.emoji, style: const TextStyle(fontSize: 64)),
    );
  }
}
