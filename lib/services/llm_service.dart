import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const String _model = 'openai/gpt-oss-120b:nitro';

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

  /// Pretty-print long strings for debug logs without overwhelming the console.
  void _debugLog(String label, String body) {
    if (!kDebugMode) return;
    const chunk = 800;
    debugPrint('── LLM $label ──');
    for (var i = 0; i < body.length; i += chunk) {
      debugPrint(body.substring(i, i + chunk > body.length ? body.length : i + chunk));
    }
    debugPrint('── /LLM $label ──');
  }

  /// POST to the chat completions endpoint with debug-mode logging of
  /// prompts and raw responses. Returns the assistant's content string.
  Future<String> _chat({
    required String tag,
    required Map<String, dynamic> body,
  }) async {
    if (kDebugMode) {
      final messages = body['messages'] as List;
      final sys = (messages.first as Map)['content'] as String;
      final usr = (messages.last as Map)['content'] as String;
      _debugLog('$tag → model=${body['model']} system', sys);
      _debugLog('$tag → user', usr);
    }

    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: _headers,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      _debugLog('$tag ← HTTP ${response.statusCode}', response.body);
      throw Exception(
        'LLM call "$tag" failed: ${response.statusCode} ${response.body}',
      );
    }

    // Always log the raw envelope in debug mode so we can see what the
    // provider actually returned (some reasoning models leave `content`
    // empty and put output under `reasoning` or `reasoning_content`).
    _debugLog('$tag ← raw', response.body);

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('LLM call "$tag" returned no choices: ${response.body}');
    }
    final choice = choices.first as Map;
    // Catch silent truncation early — without this, callers get cryptic
    // "Unterminated string" JSON parse errors instead of a clear cause.
    final finishReason = choice['finish_reason'];
    if (finishReason == 'length') {
      throw Exception(
        'LLM call "$tag" hit max_tokens (finish_reason=length). '
        'The reasoning trace likely consumed the budget — increase '
        'maxTokens or lower reasoning effort.',
      );
    }
    // OpenRouter sometimes returns 200 OK while the upstream provider
    // (Groq, etc.) failed — the failure shows up inside the choice.
    final upstreamError = choice['error'];
    if (upstreamError is Map) {
      throw Exception(
        'LLM call "$tag" upstream error '
        '(${upstreamError['code']}): ${upstreamError['message']}',
      );
    }
    final message = choice['message'] as Map?;
    if (message == null) {
      throw Exception('LLM call "$tag" returned no message: ${response.body}');
    }

    // Prefer `content`; some reasoning-model providers put structured output
    // in `reasoning` / `reasoning_content` when `content` is empty/null.
    String? content = message['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      content = (message['reasoning_content'] as String?) ??
          (message['reasoning'] as String?);
    }
    if (content == null || content.trim().isEmpty) {
      throw Exception(
        'LLM call "$tag" returned empty content. Raw: ${response.body}',
      );
    }
    _debugLog('$tag ← content', content);
    return content;
  }

  /// Build the body. `:nitro` model variants already route to the fastest
  /// throughput-optimized providers, so we just allow fallbacks by default.
  Map<String, dynamic> _baseBody({
    required String systemPrompt,
    required String userPrompt,
    String? model,
    double temperature = 0.9,
    int maxTokens = 1500,
    Map<String, dynamic>? providerOverride,
    Map<String, dynamic>? reasoning,
  }) {
    final body = <String, dynamic>{
      'model': model ?? _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'response_format': {'type': 'json_object'},
      'provider': providerOverride ??
          const {
            'sort': 'throughput',
            'allow_fallbacks': true,
          },
      'temperature': temperature,
      'max_tokens': maxTokens,
    };
    if (reasoning != null) body['reasoning'] = reasoning;
    return body;
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

    final body = _baseBody(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      // gpt-oss models burn a lot of tokens on internal reasoning even at
      // 'low'; without a generous cap, finish_reason=length truncates the
      // JSON content mid-string. 4000 leaves plenty of headroom.
      maxTokens: 4000,
      reasoning: const {'effort': 'low'},
    );
    final content = await _chat(tag: 'generateSongs', body: body);
    final dynamic parsed = jsonDecode(content);

    final List<dynamic>? rawSongs = _extractSongList(parsed);
    if (rawSongs == null) {
      throw Exception(
        'LLM response did not contain a recognizable song list. Raw content: $content',
      );
    }

    return rawSongs.whereType<Map>().map((m) {
      final s = m.cast<String, dynamic>();
      final title = (s['title'] ?? s['name'] ?? s['song'] ?? '').toString().trim();
      final artist = (s['artist'] ?? s['by'] ?? s['author'] ?? '').toString().trim();
      return Song(id: _uuid.v4(), title: title, artist: artist);
    }).where((s) => s.title.isNotEmpty && s.artist.isNotEmpty).toList();
  }

  /// Find a list of song-like maps in arbitrarily-shaped LLM output.
  List<dynamic>? _extractSongList(dynamic parsed) {
    if (parsed is List) return parsed;
    if (parsed is Map) {
      // Common keys we might see across providers/models.
      for (final key in const [
        'songs',
        'tracks',
        'playlist',
        'items',
        'results',
        'data',
      ]) {
        final v = parsed[key];
        if (v is List) return v;
      }
      // Fall back to first List-valued entry.
      for (final v in parsed.values) {
        if (v is List) return v;
        if (v is Map) {
          final inner = _extractSongList(v);
          if (inner != null) return inner;
        }
      }
    }
    return null;
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
      maxTokens: 2000,
      reasoning: const {'effort': 'low'},
    );

    final content = await _chat(tag: 'generateStation', body: body);
    final parsed = jsonDecode(content) as Map<String, dynamic>;

    return GeneratedStation(
      name: (parsed['name'] as String).trim(),
      tagline: (parsed['tagline'] as String).trim(),
      emoji: (parsed['emoji'] as String).trim(),
      moodPrompt: (parsed['moodPrompt'] as String).trim(),
    );
  }

  /// Candidate description for the YouTube video picker.
  /// Each candidate must have `videoId`, `title`, `channel`, and `durationSeconds`.
  Future<String?> pickBestYoutubeVideo({
    required String title,
    required String artist,
    required List<Map<String, dynamic>> candidates,
  }) async {
    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first['videoId'] as String?;

    final lines = <String>[];
    for (var i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      final dur = c['durationSeconds'];
      final durStr = dur is int
          ? '${(dur ~/ 60).toString().padLeft(2, '0')}:${(dur % 60).toString().padLeft(2, '0')}'
          : 'unknown';
      lines.add(
        '${i + 1}. id=${c['videoId']} | "${c['title']}" | channel: ${c['channel']} | duration: $durStr',
      );
    }

    const systemPrompt =
        'You pick the YouTube video that best matches a requested song for AUDIO-ONLY listening in a radio app. '
        'You output ONLY valid JSON in the requested format.';

    final userPrompt = '''
Requested song: "$title" by $artist

Pick the BEST YouTube video for audio playback from these candidates:
${lines.join('\n')}

Selection rules — apply STRICTLY in this order. Do NOT pick a lower-tier
option when a higher-tier one is present.

Tier 1 (BEST — pick from here if any candidate qualifies):
  - "<Artist> - Topic" auto-generated channel uploads.
  - Titles explicitly labelled "(Audio)", "(Official Audio)", "[Audio]",
    "(Visualizer)", or similar — these are audio-only with no intro/outro
    and no music-video sound design (gunshots, dialogue, sound effects).
  - Lyric videos / "(Lyrics)" / "(Official Lyric Video)" titles.

Tier 2 (acceptable fallback ONLY if no Tier 1 exists):
  - "Official Music Video" / "Official Video" uploads from the verified
    artist channel. Note: music videos often contain alternate edits,
    intro chatter, or sound effects that bleed into a radio mix — only
    pick these if Tier 1 is empty.

Tier 3 (last resort):
  - Any other upload that is unambiguously the requested studio recording.

Always REJECT (never pick from these, even if it means choosing a
lower-tier alternative):
  - Covers, remixes, parodies, mashups, reactions, tutorials.
  - Sped-up / slowed / nightcore / 8D / bass-boosted edits.
  - Live performances (unless the original recording is itself live).
  - Videos under ~2 minutes or over ~10 minutes (unless the song
    genuinely is that long) — these are clips, intros, or full albums.
  - YouTube Shorts and reaction/review/commentary channels.

Tie-breakers within a tier: prefer the candidate whose duration is
closest to the song's known length, then prefer the verified artist
channel over third-party uploads.

Respond with JSON exactly: {"videoId": "<the chosen id>", "reason": "<brief reason citing the tier>"}
If no candidate is acceptable, respond with: {"videoId": null, "reason": "<why>"}
''';

    final body = _baseBody(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      model: 'openai/gpt-oss-20b:nitro',
      temperature: 0.2,
      // Reasoning models need plenty of headroom — even at low effort the
      // model will spend tokens "thinking" before emitting JSON. A tight
      // cap caused Groq upstream to truncate before any `content` was
      // produced and fail JSON validation.
      maxTokens: 2000,
      reasoning: const {'effort': 'low'},
    );

    try {
      final content =
          await _chat(tag: 'pickBestYoutubeVideo("$title" by $artist)', body: body);
      final parsed = jsonDecode(content);
      if (parsed is Map && parsed['videoId'] is String) {
        final chosen = parsed['videoId'] as String;
        // Validate the LLM didn't hallucinate an id.
        final ok = candidates.any((c) => c['videoId'] == chosen);
        if (ok) return chosen;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('pickBestYoutubeVideo error: $e');
    }
    return candidates.first['videoId'] as String?;
  }

  void dispose() {
    _client.close();
  }
}
