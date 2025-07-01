// local_server.dart (nouvelle version intégrée à l'architecture modulaire)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'scrabble_server.dart';
import '../services/settings_service.dart';

class LocalScrabbleServer implements ScrabbleServer {
  ServerSocket? _server;
  Socket? _clientSocket;
  RawDatagramSocket? _udpSocket;
  Timer? _broadcastTimer;

  late void Function(String remoteUserName) _onClientConnected;
  late void Function(Object error) _onError;

  @override
  Future<void> start({
    required void Function(String) onClientConnected,
    required void Function(Object error) onError,
  }) async {
    _onClientConnected = onClientConnected;
    _onError = onError;

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, 4567);
      _server!.listen(_handleClient, onError: _onError);

      await _startBroadcast();
    } catch (e) {
      _onError(e);
    }
  }

  Future<void> _startBroadcast() async {
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _udpSocket!.broadcastEnabled = true;

    final ip = await _getLocalIp();
    final userName = settings.localUserName;
    final message = 'SCRABBLE_HOST:$ip:4567:$userName';
    final data = utf8.encode(message);

    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _udpSocket!.send(data, InternetAddress('255.255.255.255'), 42100);
    });
  }

  Future<String> _getLocalIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (!addr.isLoopback && addr.address.startsWith('192.168.')) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }

  void _handleClient(Socket client) {
    _clientSocket = client;
    String remoteUserName = 'Invité';

    client.listen(
      (data) {
        final message = utf8.decode(data);
        if (message.startsWith('USERNAME:')) {
          remoteUserName = message.substring('USERNAME:'.length).trim();
          _onClientConnected(remoteUserName);
        }
      },
      onDone: () => _clientSocket = null,
      onError: (e) => _onError(e),
    );
  }

  @override
  void sendToClient(String message) {
    _clientSocket?.writeln(message);
  }

  @override
  void stop() {
    _server?.close();
    _clientSocket?.destroy();
    _udpSocket?.close();
    _broadcastTimer?.cancel();
  }
}
