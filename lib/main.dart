import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'providers/player_provider.dart';
import 'providers/taste_provider.dart';
import 'screens/radio_browser_screen.dart';
import 'screens/taste_onboarding_screen.dart';
import 'services/audio_handler.dart';
import 'services/llm_service.dart';
import 'services/station_engine.dart';
import 'services/station_storage.dart';
import 'services/youtube_service.dart';

late RadiettoAudioHandler _audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Use system-managed status bar — bars get their own carved-out space, not
  // overlaid on app content. Avoids edge-to-edge overlap issues on Android 15+.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: SystemUiOverlay.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF1A1115),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF1A1115),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  _audioHandler = await AudioService.init(
    builder: () => RadiettoAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'app.radietto.audio',
      androidNotificationChannelName: 'Radietto Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  final tasteProvider = TasteProvider();
  await tasteProvider.load();

  final llm = LlmService();
  final yt = YoutubeService();
  final storage = StationStorage();
  final engine = StationEngine(
    llm: llm,
    youtube: yt,
    storage: storage,
    tastesGetter: () => tasteProvider.tastes,
  );

  final player = PlayerProvider(
    audioHandler: _audioHandler,
    engine: engine,
  );

  runApp(RadiettoApp(
    tasteProvider: tasteProvider,
    engine: engine,
    player: player,
  ));
}

class RadiettoApp extends StatelessWidget {
  final TasteProvider tasteProvider;
  final StationEngine engine;
  final PlayerProvider player;

  const RadiettoApp({
    super.key,
    required this.tasteProvider,
    required this.engine,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: tasteProvider),
        ChangeNotifierProvider.value(value: engine),
        ChangeNotifierProvider.value(value: player),
      ],
      child: MaterialApp(
        title: 'Radietto',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE94B6A),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2A1A1F),
            foregroundColor: Colors.white,
            elevation: 4,
            scrolledUnderElevation: 4,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Color(0xFF1A1115),
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
              systemNavigationBarColor: Color(0xFF1A1115),
              systemNavigationBarIconBrightness: Brightness.light,
            ),
          ),
        ),
        home: tasteProvider.onboardingDone
            ? const RadioBrowserScreen()
            : const TasteOnboardingScreen(),
      ),
    );
  }
}
