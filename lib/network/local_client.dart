import 'dart:convert';
import 'dart:io';

import 'scrabble_client.dart';

class LocalScrabbleClient implements ScrabbleClient {
  RawDatagramSocket? _udpSocket;
  late void Function(String) _onHostDetected;
  // ...

  Future<void> discoverHost(
    Function(String ip, int port, String hostUserName) onFound,
  ) async {
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 42100);

    _udpSocket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _udpSocket!.receive();
        if (datagram == null) return;

        final message = utf8.decode(datagram.data);
        if (message.startsWith('SCRABBLE_HOST:')) {
          final parts = message.split(':');
          if (parts.length >= 4) {
            final ip = parts[1];
            final port = int.tryParse(parts[2]) ?? 4567;
            final remoteUserName = parts[3];

            _udpSocket?.close();
            onFound(ip, port, remoteUserName);
          }
        }
      }
    });
  }

  // connect, sendMessage, etc.
}
