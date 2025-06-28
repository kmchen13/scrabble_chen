
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'client.dart';
import 'server.dart';
void main() {
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HostScreen()),
                ),
                child: const Text("Héberger une partie"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinScreen()),
                ),
                child: const Text("Rejoindre une partie"),
              ),
            ] else
              const Text("P2P non disponible sur navigateur")
          ],
        ),
      ),
    );
  }
}

