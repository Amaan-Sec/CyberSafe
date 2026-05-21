import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/i18n/locale_service.dart';
import 'core/rasp/rasp_service.dart';
import 'core/router/app_router.dart';
import 'core/services/share_intent_service.dart';
import 'core/services/tts_service.dart';
import 'core/theme/theme_mode_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final raspService = RaspService();
  // Start RASP as early as possible — before any UI work.
  await raspService.start();

  // Register this device with the prototype backend (non-blocking).
  // ignore: discarded_futures
  raspService.backend.registerDevice();

  final locale = LocaleService();
  await locale.load();

  final themeMode = ThemeModeService();
  await themeMode.load();

  final tts = TtsService();
  // ignore: discarded_futures
  tts.init();

  // Receive URLs shared from other apps (WhatsApp / SMS / browser).
  ShareIntentService.instance.onUrlShared = (url) {
    final encoded = Uri.encodeQueryComponent(url);
    AppRouter.router.push('${AppRoutes.urlScanner}?url=$encoded');
  };
  ShareIntentService.instance.start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<RaspService>.value(value: raspService),
        ChangeNotifierProvider<LocaleService>.value(value: locale),
        ChangeNotifierProvider<ThemeModeService>.value(value: themeMode),
        Provider<TtsService>.value(value: tts),
      ],
      child: const MahaCyberSafeApp(),
    ),
  );
}
