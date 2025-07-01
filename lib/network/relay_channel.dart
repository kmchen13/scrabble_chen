import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/game_channel.dart';

class RelayGameChannel implements GameChannel {
  final WebSocketChannel _channel;

  RelayGameChannel(this._channel);

  @override
  void send(String message) {
    _channel.sink.add(message);
  }

  @override
  Stream<String> get messages => _channel.stream.cast<String>();

  @override
  void dispose() {
    _channel.sink.close();
  }
}
