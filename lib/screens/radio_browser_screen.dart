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
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: stations.length,
              itemBuilder: (context, i) {
                final s = stations[i];
                return _StationCard(
                  station: s,
                  onTap: () => _onTapStation(s),
                );
              },
            ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final RadioStation station;
  final VoidCallback onTap;
  const _StationCard({required this.station, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = station.isWarmedUp && station.firstUnplayed != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(station.emoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                station.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  station.tagline,
                  style: theme.textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
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
    );
  }
}
