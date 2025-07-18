import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/settings_service.dart';

import 'start_screen.dart';
import 'param_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettings();
  print('[DEBUG] localUserName = ' + settings.localUserName);
  runApp(const ScrabbleApp());
}

class ScrabbleApp extends StatelessWidget {
  const ScrabbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scrabble_chen ;-)")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!kIsWeb) ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StartScreen()),
                  );
                },
                child: const Text("Commencer une partie"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ParamScreen()),
                  );
                },
                child: const Text("Paramètres"),
              ),
              ElevatedButton(
                onPressed: () {
                  SystemNavigator.pop();
                },
                child: const Text("Quitter"),
              ),
            ] else
              const Text("P2P non disponible sur navigateur"),
          ],
        ),
      ),
    );
  }
}
