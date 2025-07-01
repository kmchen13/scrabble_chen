import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/settings_service.dart';

import 'join_screen.dart';
import 'host_screen.dart';
import 'param_screen.dart';
import 'relay_P2P/join_screen.dart';
import 'relay_P2P/host_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettings(); // chargement global
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
      appBar: AppBar(title: const Text("Scrabble P2P")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!kIsWeb) ...[
              ElevatedButton(
                onPressed: () {
                  final mode = settings.communicationMode;
                  if (mode == 'web') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RelayHostScreen(),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HostScreen()),
                    );
                  }
                },
                child: const Text("Héberger une partie"),
              ),
              ElevatedButton(
                onPressed: () {
                  final mode = settings.communicationMode;
                  if (mode == 'web') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RelayJoinScreen(),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JoinScreen()),
                    );
                  }
                },
                child: const Text("Rejoindre une partie"),
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
                  SystemNavigator.pop(); // ferme proprement l'app, comme un "back" ultime
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
