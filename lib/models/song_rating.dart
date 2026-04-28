enum SongRating { thumbsUp, thumbsDown, skip }

extension SongRatingExt on SongRating {
  String get label {
    switch (this) {
      case SongRating.thumbsUp:
        return 'loved';
      case SongRating.thumbsDown:
        return 'disliked';
      case SongRating.skip:
        return 'skipped';
    }
  }
}
