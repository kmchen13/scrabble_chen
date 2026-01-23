import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:hive_flutter/hive_flutter.dart';
import 'services/settings_service.dart';
import 'services/dictionary.dart';
import 'services/game_storage.dart';
import 'models/game_state.dart';
import 'screens/home_screen.dart';
import 'screens/param_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> loadDefaultDictionary() async {
  try {
    final content = await rootBundle.loadString('assets/dictionary.txt');
    dictionaryService.replaceFromText(content);
  } catch (e) {
    // Affiche un snackbar si impossible de charger le dictionnaire
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Impossible de charger le dictionnaire par défaut: $e',
            style: const TextStyle(fontSize: 14),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettings();
  await Hive.initFlutter();
  // Enregistrement des adapters générés
  Hive.registerAdapter(GameStateAdapter());
  // Ouverture de la box via ton wrapper
  await gameStorage.init();
  // Charger le dictionnaire par défaut
  await loadDefaultDictionary();
  // Intercepter la fermeture de l'app
  ProcessSignal.sigint.watch().listen((_) async {
    await gameStorage.close();
    exit(0);
  });

  runApp(ScrabbleApp());
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
            // Rediriger vers ParamScreen si le userName est vide
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
