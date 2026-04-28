import 'song.dart';

class RadioStation {
  final String id;
  String name;
  String tagline;
  String emoji;
  /// The vibe/mood prompt used to generate songs (LLM context).
  String moodPrompt;
  /// True if this station was generated from a custom user prompt.
  final bool isCustom;
  final List<Song> queue;
  /// Songs already played in this station session (with ratings)
  final List<Song> history;
  bool isWarmedUp;
  bool isGenerating;

  RadioStation({
    required this.id,
    required this.name,
    required this.tagline,
    required this.emoji,
    required this.moodPrompt,
    this.isCustom = false,
    List<Song>? queue,
    List<Song>? history,
    this.isWarmedUp = false,
    this.isGenerating = false,
  })  : queue = queue ?? [],
        history = history ?? [];

  /// First unplayed song with a resolved stream URL, ready to play right now.
  Song? get firstPlayable {
    for (final s in queue) {
      if (!s.played && s.streamUrl != null) return s;
    }
    return null;
  }

  /// First unplayed song that *can* be played (has either streamUrl or
  /// at least a videoId we can refresh).
  Song? get firstResolvableUnplayed {
    for (final s in queue) {
      if (!s.played && (s.streamUrl != null || s.youtubeVideoId != null)) {
        return s;
      }
    }
    return null;
  }

  int get unplayedCount => queue.where((s) => !s.played).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tagline': tagline,
        'emoji': emoji,
        'moodPrompt': moodPrompt,
        'isCustom': isCustom,
        'queue': queue.map((s) => s.toJson()).toList(),
        'history': history.map((s) => s.toJson()).toList(),
      };

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    final queue = (json['queue'] as List? ?? [])
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
    final history = (json['history'] as List? ?? [])
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
    final station = RadioStation(
      id: json['id'] as String,
      name: json['name'] as String,
      tagline: json['tagline'] as String,
      emoji: json['emoji'] as String,
      moodPrompt: json['moodPrompt'] as String,
      isCustom: json['isCustom'] as bool? ?? false,
      queue: queue,
      history: history,
    );
    // Station is warm if any unplayed song has a videoId.
    station.isWarmedUp =
        queue.any((s) => !s.played && s.youtubeVideoId != null);
    return station;
  }
}
