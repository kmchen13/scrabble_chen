import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models/game_state.dart';
import 'models/bag.dart';
import 'game_screen.dart';
import 'game_logic.dart';

// ------------------------
// Écran Serveur
// ------------------------
class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  ServerSocket? server;
  String _log = "En attente de connexion...\n";
  Timer? _broadcastTimer;
  RawDatagramSocket? _broadcastSocket;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  void _startServer() async {
    Future<String?> getLocalIpAddress() async {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false, // on veut éviter 127.0.0.1
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
            // ou 10.0. ou 172.16.–31.
            return addr.address;
          }
        }
      }

      return null;
    }

    final ip = await getLocalIpAddress();
    _log += '\nIP serveur ${ip ?? "inconnue"}:4567';

    try {
      server = await ServerSocket.bind(InternetAddress.anyIPv4, 4567);
      _broadcastPresence(); // Démarrer le broadcast UDP

      setState(() {
        _log +=
            "\nBroadcast lancé sur ${server!.address.address}:${server!.port}\nEn attente de connexion...";
      });

      server!.listen((client) {
        stopBroadcast();

        setState(() {
          _log +=
              "\nClient connecté : ${client.remoteAddress.address}:${client.remotePort}";
        });

        final bag = BagModel();
        final player1Letters = bag.drawLetters(7);
        final player2Letters = bag.drawLetters(7);

        // Envoie les lettres du client via TCP (client = socket)
        client.write('LETTERS:${player2Letters.join(",")}');

        GameState state = GameState(
          playerLetters: player1Letters,
          board: GameState.createEmptyBoard(15),
          bag: bag,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (BuildContext context) => GameScreen(gameState: state),
          ),
        );

        client.listen((data) {
          setState(() {
            _log += "\nReçu : ${utf8.decode(data)}";
          });
          client.write("Message reçu !");
        });
      });
    } catch (e) {
      setState(() {
        _log += "\nErreur : $e";
      });
    }
  }

  void _broadcastPresence() async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled =
        true; // ← OBLIGATOIRE pour envoyer sur 255.255.255.255

    final ip =
        (await NetworkInterface.list())
            .where(
              (iface) => iface.name.contains("wlan"),
            ) // filters to Wi-Fi interface
            .expand((i) => i.addresses)
            .first
            .address;

    const port = 42100;

    String msg = 'SCRABBLE_HOST:$ip';
    setState(() {
      _log += "\nmessage broadcasté $msg";
    });

    final message = utf8.encode('SCRABBLE_HOST:$ip');

    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      print("Broadcast actif");
      socket.send(message, InternetAddress('255.255.255.255'), port);
    });
  }

  void stopBroadcast() {
    _broadcastTimer?.cancel();
    _broadcastSocket?.close();
    _broadcastTimer = null;
    _broadcastSocket = null;
  }

  @override
  void dispose() {
    server?.close();
    stopBroadcast();
    print("Broadcast actif");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hébergeur ;-)")),
      body: Padding(padding: const EdgeInsets.all(16), child: Text(_log)),
    );
  }
}
