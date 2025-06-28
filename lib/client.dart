import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:io';

import 'models/game_state.dart';
import 'models/bag.dart';
import 'game_screen.dart';

// ------------------------
// Écran Client
// ------------------------
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  String _log = "";
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: "4567",
  );
  Socket? _socket;

  @override
  void initState() {
    super.initState();
    _listenForHost();
  }

  void _listenForHost() async {
    final udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      42100,
    );
    udpSocket.listen((RawSocketEvent event) async {
      if (event == RawSocketEvent.read) {
        Datagram? datagram = udpSocket.receive();
        if (datagram == null) return;

        String message = utf8.decode(datagram.data);
        if (message.startsWith('SCRABBLE_HOST:')) {
          List<String> parts = message.split(':');
          if (parts.length >= 2) {
            String hostIp = parts[1];

            setState(() {
              _log = "Hôte détecté : $hostIp";
              _ipController.text = hostIp;
            });

            udpSocket.close(); // On arrête d'écouter

            try {
              int port = int.tryParse(_portController.text) ?? 4567;
              Socket socket = await Socket.connect(hostIp, port);

              setState(() {
                _log += "\nConnecté à $hostIp:$port";
              });

              // On écoute les messages du serveur
              socket.listen((List<int> data) {
                String msg = utf8.decode(data);
                if (msg.startsWith("LETTERS:")) {
                  List<String> letters = parseLettersFromReceivedMessage(msg);

                  GameState state = GameState(
                    playerLetters: letters,
                    board: GameState.createEmptyBoard(15),
                    bag: null,
                  );

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (BuildContext context) =>
                              GameScreen(gameState: state),
                    ),
                  );
                }
              });
            } catch (e) {
              setState(() {
                _log += "\nErreur lors de la connexion au serveur : $e";
              });
            }
          }
        }
      }
    }); //udpsocket listen
  }

  List<String> parseLettersFromReceivedMessage(String message) {
    String dataPart = message.substring('LETTERS:'.length);
    List<String> letters = dataPart.split(',');
    return letters.map((String letter) => letter.trim()).toList();
  }

  @override
  void dispose() {
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("hébergé ;-)")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: "Adresse IP détectée",
              ),
            ),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: "Port"),
              keyboardType: TextInputType.number,
            ),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: SingleChildScrollView(
                child: Text(
                  _log,
                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
