import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/settings_service.dart';
import 'services/game_storage.dart';
import 'services/utility.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'screens/home_screen.dart';
import 'screens/param_screen.dart';
import 'constants.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettings();
  await Hive.initFlutter();
  // Enregistrement des adapters générés
  Hive.registerAdapter(GameStateAdapter());
  // Ouverture de la box via ton wrapper
  await gameStorage.init();
  if (debug) {
    print("${logHeader('main')} Application démarrée");
  }
  runApp(ScrabbleApp());
}

class ScrabbleApp extends StatelessWidget {
  ScrabbleApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [routeObserver],
      home: FutureBuilder(
        future: loadSettings(),
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
    );
  }
}
