abstract class GameChannel {
  void send(String message);
  Stream<String> get messages;
  void dispose();
}
