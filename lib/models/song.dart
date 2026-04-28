import 'song_rating.dart';

enum SongResolutionStatus { pending, resolving, resolved, failed }

class Song {
  final String id;
  final String title;
  final String artist;
  String? youtubeVideoId;
  String? streamUrl;
  Duration? duration;
  String? thumbnailUrl;
  SongResolutionStatus status;
  SongRating? rating;
  bool played;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.youtubeVideoId,
    this.streamUrl,
    this.duration,
    this.thumbnailUrl,
    this.status = SongResolutionStatus.pending,
    this.rating,
    this.played = false,
  });

  String get displayLabel => '$title — $artist';

  /// Persistent fields only — streamUrl is intentionally NOT serialized
  /// because YouTube signed URLs expire after a few hours.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'youtubeVideoId': youtubeVideoId,
        'durationMs': duration?.inMilliseconds,
        'thumbnailUrl': thumbnailUrl,
        'rating': rating?.name,
        'played': played,
      };

  factory Song.fromJson(Map<String, dynamic> json) {
    final ratingName = json['rating'] as String?;
    SongRating? rating;
    if (ratingName != null) {
      for (final r in SongRating.values) {
        if (r.name == ratingName) {
          rating = r;
          break;
        }
      }
    }
    final durMs = json['durationMs'] as int?;
    final videoId = json['youtubeVideoId'] as String?;
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      youtubeVideoId: videoId,
      duration: durMs != null ? Duration(milliseconds: durMs) : null,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      // If we have a videoId we know the song is resolvable; mark "resolved"
      // so UI knows it's playable (the streamUrl will be lazily fetched).
      status: videoId != null
          ? SongResolutionStatus.resolved
          : SongResolutionStatus.pending,
      rating: rating,
      played: json['played'] as bool? ?? false,
    );
  }
}
