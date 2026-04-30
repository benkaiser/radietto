import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'services/replicate_service.dart';
import 'services/station_art_service.dart';
import 'services/station_engine.dart';
import 'services/station_storage.dart';
import 'services/youtube_service.dart';

late RadiettoAudioHandler _audioHandler;

/// Intent fired by the global desktop spacebar shortcut.
class _TogglePlayPauseIntent extends Intent {
  const _TogglePlayPauseIntent();
}

/// Toggles play/pause, but is disabled while focus is inside an editable
/// text field so users can still type spaces. When [isEnabled] returns
/// false, the [Shortcuts] widget treats the key as unhandled and the
/// event propagates normally to the focused [TextField].
class _TogglePlayPauseAction extends Action<_TogglePlayPauseIntent> {
  _TogglePlayPauseAction(this.player);

  final PlayerProvider player;

  @override
  bool isEnabled(_TogglePlayPauseIntent intent, [BuildContext? context]) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx != null &&
        ctx.findAncestorWidgetOfExactType<EditableText>() != null) {
      return false;
    }
    return true;
  }

  @override
  Object? invoke(_TogglePlayPauseIntent intent) {
    player.togglePlayPause();
    return null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Use system-managed status bar — bars get their own carved-out space, not
  // overlaid on app content. Avoids edge-to-edge overlap issues on Android 15+.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: SystemUiOverlay.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF0E1622),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF0E1622),
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
  final yt = YoutubeService(llm: llm);
  final storage = StationStorage();
  final replicate = ReplicateService();
  final art = StationArtService(replicate: replicate);
  final engine = StationEngine(
    llm: llm,
    youtube: yt,
    storage: storage,
    art: art,
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
            seedColor: const Color(0xFF4C8DFF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF15202E),
            foregroundColor: Colors.white,
            elevation: 4,
            scrolledUnderElevation: 4,
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Color(0xFF0E1622),
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
              systemNavigationBarColor: Color(0xFF0E1622),
              systemNavigationBarIconBrightness: Brightness.light,
            ),
          ),
        ),
        // Global desktop shortcut: spacebar toggles play/pause, except
        // when focus is inside an editable text field. We use Shortcuts +
        // Actions (rather than CallbackShortcuts) so the action can
        // disable itself via isEnabled — when disabled, the shortcut is
        // not handled and the key event propagates to the TextField so
        // the user can type a space.
        builder: (context, child) {
          Widget content = Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.space):
                  _TogglePlayPauseIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                _TogglePlayPauseIntent: _TogglePlayPauseAction(player),
              },
              child: Focus(
                autofocus: true,
                skipTraversal: true,
                canRequestFocus: false,
                child: child!,
              ),
            ),
          );

          // On macOS we use NSWindow.fullSizeContentView so the Flutter
          // surface extends under the (transparent) titlebar. Reserve a
          // 28px strip at the top, painted in the AppBar color, so the
          // traffic-light controls have somewhere to sit without overlapping
          // AppBar leading icons / actions. The strip is non-interactive,
          // so isMovableByWindowBackground keeps it draggable.
          if (!kIsWeb && Platform.isMacOS) {
            content = Column(
              children: [
                Container(
                  height: 28,
                  color: const Color(0xFF15202E),
                ),
                Expanded(child: content),
              ],
            );
          }

          return content;
        },
        home: tasteProvider.onboardingDone
            ? const RadioBrowserScreen()
            : const TasteOnboardingScreen(),
      ),
    );
  }
}
