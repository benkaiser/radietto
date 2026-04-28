import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/genre_preference.dart';
import '../models/song.dart';
import '../models/song_rating.dart';

/// A simple LLM-generated song reference (title + artist).
class GeneratedSong {
  final String title;
  final String artist;
  GeneratedSong({required this.title, required this.artist});
}

/// Generated station metadata.
class GeneratedStation {
  final String name;
  final String tagline;
  final String emoji;
  final String moodPrompt;
  GeneratedStation({
    required this.name,
    required this.tagline,
    required this.emoji,
    required this.moodPrompt,
  });
}

class LlmService {
  static const String _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'openai/gpt-oss-120b';

  final http.Client _client;
  final _uuid = const Uuid();

  LlmService({http.Client? client}) : _client = client ?? http.Client();

  String get _apiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        // Optional but recommended by OpenRouter
        'HTTP-Referer': 'https://radietto.app',
        'X-Title': 'Radietto',
      };

  /// Build the body with provider preference for Cerebras (fastest), with fallbacks allowed.
  Map<String, dynamic> _baseBody({
    required String systemPrompt,
    required String userPrompt,
  }) {
    return {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'response_format': {'type': 'json_object'},
      // Prefer Cerebras for fast throughput; fall back to other providers if unavailable.
      'provider': {
        'order': ['cerebras'],
        'allow_fallbacks': true,
        'sort': 'throughput',
      },
      'temperature': 0.9,
      'max_tokens': 1500,
    };
  }

  String _formatTastes(List<GenrePreference> tastes) {
    final nonNeutral = tastes.where((t) => t.value != 5.0).toList();
    if (nonNeutral.isEmpty) {
      return 'I have neutral taste across all major genres (no strong preferences).';
    }
    final lines = nonNeutral.map((t) {
      return '- ${t.genre}: ${t.value.toStringAsFixed(0)}';
    }).join('\n');
    return 'On a scale of 0 (hate) to 10 (love), with 5 being neutral, my tastes are:\n$lines\n\nFor any genre I did not list, treat me as neutral (5). Unless I have rated something 8 or higher, please keep things balanced — do not over-index on any single genre.';
  }

  String _formatFeedback(List<Song> history) {
    if (history.isEmpty) return '';
    final rated = history.where((s) => s.rating != null).toList();
    if (rated.isEmpty) return '';
    final recent = rated.length > 15 ? rated.sublist(rated.length - 15) : rated;
    final lines = recent.map((s) {
      return '- "${s.title}" by ${s.artist} → ${s.rating!.label}';
    }).join('\n');
    return '\nRecent feedback from this listening session — please learn from this:\n$lines\n';
  }

  String _formatAvoid(List<Song> queueAndHistory) {
    if (queueAndHistory.isEmpty) return '';
    final lines = queueAndHistory
        .take(40)
        .map((s) => '- "${s.title}" by ${s.artist}')
        .join('\n');
    return '\nDo NOT repeat any of these songs (they are already in the queue or have been played):\n$lines\n';
  }

  /// Generate [count] song picks for a station.
  Future<List<Song>> generateSongs({
    required String moodPrompt,
    required List<GenrePreference> tastes,
    required List<Song> history,
    required List<Song> currentQueue,
    int count = 5,
  }) async {
    final tastesText = _formatTastes(tastes);
    final feedbackText = _formatFeedback(history);
    final avoidText = _formatAvoid([...currentQueue, ...history]);

    final systemPrompt =
        'You are a music programmer for a radio app. You output ONLY valid JSON in the requested format. '
        'You curate balanced, high-quality song selections that match the requested vibe and respect the listener\'s tastes and feedback.';

    final userPrompt = '''
Pick exactly $count songs for this radio station vibe:
"$moodPrompt"

$tastesText
$feedbackText$avoidText

Respond with JSON in this exact shape:
{"songs": [{"title": "Song Title", "artist": "Artist Name"}, ...]}

Choose real, well-known songs that exist on YouTube. Do not invent songs.
''';

    final body = _baseBody(systemPrompt: systemPrompt, userPrompt: userPrompt);

    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'LLM song generation failed: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['choices'][0]['message']['content'] as String;
    final parsed = jsonDecode(content) as Map<String, dynamic>;
    final songs = (parsed['songs'] as List).cast<Map<String, dynamic>>();

    return songs.map((s) {
      return Song(
        id: _uuid.v4(),
        title: (s['title'] as String).trim(),
        artist: (s['artist'] as String).trim(),
      );
    }).toList();
  }

  /// Generate a custom station from a user prompt.
  Future<GeneratedStation> generateStationFromPrompt(String userPrompt) async {
    final systemPrompt =
        'You name and theme radio stations for a music app. Output ONLY valid JSON.';

    final body = _baseBody(
      systemPrompt: systemPrompt,
      userPrompt: '''
A user wants a custom radio station for: "$userPrompt"

Create a fun, evocative radio-station name (2-4 words), a short tagline (under 8 words), and pick a single emoji that fits.
Also write a one-sentence "moodPrompt" describing the vibe of music for this station — this will be used to brief a music programmer.

Respond with JSON:
{"name": "...", "tagline": "...", "emoji": "🎧", "moodPrompt": "..."}
''',
    );

    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'LLM station generation failed: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final content = decoded['choices'][0]['message']['content'] as String;
    final parsed = jsonDecode(content) as Map<String, dynamic>;

    return GeneratedStation(
      name: (parsed['name'] as String).trim(),
      tagline: (parsed['tagline'] as String).trim(),
      emoji: (parsed['emoji'] as String).trim(),
      moodPrompt: (parsed['moodPrompt'] as String).trim(),
    );
  }

  void dispose() {
    _client.close();
  }
}
