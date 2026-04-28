import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/radio_station.dart';

class StationStorage {
  static const _kKey = 'stations_v1';

  Future<List<RadioStation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> parsed = jsonDecode(raw);
      return parsed
          .map((e) => RadioStation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<RadioStation> stations) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(stations.map((s) => s.toJson()).toList());
    await prefs.setString(_kKey, raw);
  }
}
