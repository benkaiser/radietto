/// Pre-defined station templates that ship with the app.
class StationTemplate {
  final String id;
  final String name;
  final String tagline;
  final String emoji;
  final String moodPrompt;
  /// Bundled cover-art asset. Copied to the app docs dir on first launch
  /// so it can be served as a `file://` artUri to the OS media controls.
  final String? imageAsset;

  const StationTemplate({
    required this.id,
    required this.name,
    required this.tagline,
    required this.emoji,
    required this.moodPrompt,
    this.imageAsset,
  });
}

const List<StationTemplate> kStationTemplates = [
  StationTemplate(
    id: 'iron-tempo',
    name: 'Iron Tempo',
    tagline: 'Fuel for your grind',
    emoji: '🏋️',
    moodPrompt:
        'High-energy workout tracks with driving beats — songs that push you through one more rep.',
    imageAsset: 'assets/station_tiles/iron-tempo.jpg',
  ),
  StationTemplate(
    id: 'golden-hour',
    name: 'Golden Hour Radio',
    tagline: 'Breezy tunes for sunny days',
    emoji: '☀️',
    moodPrompt:
        'Sunny, warm, feel-good songs perfect for an afternoon outside — laid-back but uplifting.',
    imageAsset: 'assets/station_tiles/golden-hour.jpg',
  ),
  StationTemplate(
    id: 'midnight-drift',
    name: 'Midnight Drift',
    tagline: 'Late-night sonic journeys',
    emoji: '🌙',
    moodPrompt:
        'Moody, atmospheric late-night tracks — songs to drive empty highways to at 2am.',
    imageAsset: 'assets/station_tiles/midnight-drift.jpg',
  ),
  StationTemplate(
    id: 'main-stage',
    name: 'Main Stage',
    tagline: 'Peak energy bangers',
    emoji: '🎉',
    moodPrompt:
        'Party anthems and crowd-pleasers — high energy songs that fill a dance floor.',
    imageAsset: 'assets/station_tiles/main-stage.jpg',
  ),
  StationTemplate(
    id: 'the-study',
    name: 'The Study',
    tagline: 'Focus-friendly frequencies',
    emoji: '📚',
    moodPrompt:
        'Calm, mostly instrumental or low-vocal songs that help with focus and deep work.',
    imageAsset: 'assets/station_tiles/the-study.jpg',
  ),
  StationTemplate(
    id: 'heartbreak-hotel',
    name: 'Heartbreak Hotel FM',
    tagline: 'Songs that understand',
    emoji: '💔',
    moodPrompt:
        'Emotional, melancholic songs about love, loss, and longing.',
    imageAsset: 'assets/station_tiles/heartbreak-hotel.jpg',
  ),
  StationTemplate(
    id: 'highway-one',
    name: 'Highway One',
    tagline: 'Open road anthems',
    emoji: '🚗',
    moodPrompt:
        'Driving songs — singalong anthems and rhythmic tracks for long road trips.',
    imageAsset: 'assets/station_tiles/highway-one.jpg',
  ),
  StationTemplate(
    id: 'sunday-morning',
    name: 'Sunday Morning',
    tagline: 'Easy listening for lazy days',
    emoji: '🍳',
    moodPrompt:
        'Gentle acoustic, soft indie, and easy listening songs for slow weekend mornings.',
    imageAsset: 'assets/station_tiles/sunday-morning.jpg',
  ),
  StationTemplate(
    id: 'tidal-waves',
    name: 'Tidal Waves',
    tagline: 'Ambient electronic explorations',
    emoji: '🌊',
    moodPrompt:
        'Ambient, downtempo, and atmospheric electronic music — chillwave and dream-pop welcome.',
    imageAsset: 'assets/station_tiles/tidal-waves.jpg',
  ),
  StationTemplate(
    id: 'the-underground',
    name: 'The Underground',
    tagline: 'Deep cuts and hidden gems',
    emoji: '🔥',
    moodPrompt:
        'Lesser-known tracks and B-sides from across genres — songs the algorithm usually misses.',
    imageAsset: 'assets/station_tiles/the-underground.jpg',
  ),
];
