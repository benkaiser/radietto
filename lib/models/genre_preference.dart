// Genre preference: a slider value from 0 (hate) to 10 (love), 5 = neutral.
class GenrePreference {
  final String genre;
  double value;

  GenrePreference({required this.genre, this.value = 5.0});

  Map<String, dynamic> toJson() => {'genre': genre, 'value': value};

  factory GenrePreference.fromJson(Map<String, dynamic> json) =>
      GenrePreference(
        genre: json['genre'] as String,
        value: (json['value'] as num).toDouble(),
      );
}

class Genres {
  static const List<String> all = [
    'Rock',
    'Pop',
    'Jazz',
    'Classical',
    'Metal',
    'Electronic',
    'Hip-Hop',
    'Country',
    'R&B',
    'Folk',
    'Reggae',
    'Blues',
  ];

  static List<GenrePreference> defaults() =>
      all.map((g) => GenrePreference(genre: g)).toList();
}
