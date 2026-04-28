import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/genre_preference.dart';

class TasteProvider extends ChangeNotifier {
  static const _kKey = 'taste_preferences_v1';
  static const _kOnboardingDoneKey = 'onboarding_done_v1';

  List<GenrePreference> _tastes = Genres.defaults();
  bool _onboardingDone = false;
  bool _loaded = false;

  List<GenrePreference> get tastes => _tastes;
  bool get onboardingDone => _onboardingDone;
  bool get loaded => _loaded;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    _onboardingDone = prefs.getBool(_kOnboardingDoneKey) ?? false;
    if (raw != null) {
      try {
        final List<dynamic> parsed = jsonDecode(raw);
        final loaded =
            parsed.map((e) => GenrePreference.fromJson(e)).toList();
        // Ensure we always have all current genres represented.
        for (final g in Genres.all) {
          if (!loaded.any((p) => p.genre == g)) {
            loaded.add(GenrePreference(genre: g));
          }
        }
        _tastes = loaded;
      } catch (_) {
        _tastes = Genres.defaults();
      }
    }
    _loaded = true;
    notifyListeners();
  }

  void updateGenre(String genre, double value) {
    final pref = _tastes.firstWhere((p) => p.genre == genre);
    pref.value = value;
    notifyListeners();
  }

  Future<void> save({bool markOnboardingDone = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_tastes.map((t) => t.toJson()).toList());
    await prefs.setString(_kKey, raw);
    if (markOnboardingDone) {
      _onboardingDone = true;
      await prefs.setBool(_kOnboardingDoneKey, true);
    }
    notifyListeners();
  }
}
