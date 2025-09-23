import 'package:logger/logger.dart';

// Instance globale de logger
var logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1, // nombre de méthodes affichées dans la stacktrace
    errorMethodCount: 8,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

void logProjectStack([String msg = ""]) {
  final trace = StackTrace.current
      .toString()
      .split('\n')
      .where(
        (line) => line.contains('scrabble_P2P/'),
      ) // filtre les frames de ton projet
      .join('\n');

  if (msg.isNotEmpty) {
    print("[$msg]");
  }
  print(trace);
}
