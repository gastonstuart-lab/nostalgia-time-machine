import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'nav.dart';
import 'state.dart';
import 'services/youtube_service.dart';
import 'config/youtube_config.dart';

const bool _enableAppCheck =
    bool.fromEnvironment('ENABLE_APP_CHECK', defaultValue: false);
const String _webRecaptchaSiteKey =
    String.fromEnvironment('RECAPTCHA_V3_SITE_KEY', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (_enableAppCheck && _webRecaptchaSiteKey.isNotEmpty) {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider(_webRecaptchaSiteKey),
    );
  }

  // Initialize YouTube API
  YouTubeService.setApiKey(YouTubeConfig.apiKey);

  runApp(const NostalgiaApp());
}

class NostalgiaApp extends StatelessWidget {
  const NostalgiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NostalgiaProvider()..initialize(),
      child: Consumer<NostalgiaProvider>(
        builder: (context, provider, _) => MaterialApp.router(
          title: 'Nostalgia Time Machine',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: provider.themeMode,
          routerConfig: AppRouter.createRouter(provider),
        ),
      ),
    );
  }
}
