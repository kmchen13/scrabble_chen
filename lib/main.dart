import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/settings_service.dart';
import 'services/app_log.dart';
import 'services/game_storage.dart';
import 'models/game_state.dart';
import 'screens/home_screen.dart';
import 'screens/param_screen.dart';
import 'package:scrabble_P2P/services/app_lifecycle.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
final appLifecycle = AppLifecycle();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLog().init();
  await loadSettings();
  await Hive.initFlutter();
  // Enregistrement des adapters générés
  Hive.registerAdapter(GameStateAdapter());
  // Ouverture de la box via ton wrapper
  await gameStorage.init();
  // Intercepter la fermeture de l'app
  ProcessSignal.sigint.watch().listen((_) async {
    await gameStorage.close();
    exit(0);
  });
  final appLifecycle = AppLifecycle();
  appLifecycle.start();
  _initializeAdMob();
  runApp(ScrabbleApp());
}

void _initializeAdMob() async {
  try {
    await MobileAds.instance.initialize();
    print('✅ AdMob initialized successfully');
  } catch (e) {
    print('❌ AdMob initialization failed: $e');
  }
}

class ScrabbleApp extends StatelessWidget {
  ScrabbleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [routeObserver],
      home: FutureBuilder(
        future: Future.value(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Rediriger vers ParamScreen si le user est vide
            if (settings.localUserName.isEmpty ||
                settings.relayAddress.substring(0, 8) == 'https//:') {
              return ParamScreen();
            } else {
              // Sinon, aller à HomeScreen
              return HomeScreen();
            }
          }
          // Affiche un écran de chargement pendant que les paramètres sont chargés
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),
      debugShowCheckedModeBanner: false,

      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          background: Colors.black,
          surface: Colors.black,
          primary: Colors.white,
          onBackground: Colors.white,
          onSurface: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
