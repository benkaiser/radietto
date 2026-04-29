import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/taste_provider.dart';
import '../services/station_engine.dart';
import 'radio_browser_screen.dart';

class TasteOnboardingScreen extends StatelessWidget {
  final bool isReturningEdit;
  const TasteOnboardingScreen({super.key, this.isReturningEdit = false});

  Future<void> _save(BuildContext context, {required bool useDefaults}) async {
    final taste = context.read<TasteProvider>();
    final engine = context.read<StationEngine>();
    if (useDefaults) {
      // Reset to defaults if skipping.
      for (final p in taste.tastes) {
        p.value = 5.0;
      }
    }
    await taste.save(markOnboardingDone: true);
    // Tastes drive the LLM song-generation prompt, so any pre-generated
    // unplayed queue is stale. Drop it and re-warm with the new tastes.
    // Only meaningful on the returning-edit path; on first-time onboarding
    // the engine hasn't generated anything yet but the call is a no-op.
    if (isReturningEdit) {
      // Fire-and-forget — warmup happens in the background.
      unawaited(engine.regenerateAllStations());
    }
    if (!context.mounted) return;
    if (isReturningEdit) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RadioBrowserScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final taste = context.watch<TasteProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(isReturningEdit ? 'Tune Your Tastes' : 'Tune Your Radio'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Slide each genre toward how much you love it. 5 is neutral.\nLeave them at 5 to get a balanced mix.',
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: taste.tastes.length,
              itemBuilder: (context, i) {
                final p = taste.tastes[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(
                            p.genre,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: p.value,
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: p.value.toStringAsFixed(0),
                            onChanged: (v) =>
                                context.read<TasteProvider>().updateGenre(
                                      p.genre,
                                      v,
                                    ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text(
                            p.value.toStringAsFixed(0),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _save(context, useDefaults: false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          isReturningEdit ? 'Save Tastes' : 'Start Listening',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  if (!isReturningEdit)
                    TextButton(
                      onPressed: () => _save(context, useDefaults: true),
                      child: const Text('Skip — Just Play Everything'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
