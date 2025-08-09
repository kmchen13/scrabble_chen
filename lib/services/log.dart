import 'package:logger/logger.dart';

// Instance globale de logger
var logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2, // nombre de méthodes affichées dans la stacktrace
    errorMethodCount: 8,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);
