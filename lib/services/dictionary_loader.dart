import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'settings_service.dart';
import 'dictionary.dart';
import '../constants.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

ScrabbleLanguage scrabbleLanguageFromString(String lang) {
  switch (lang.toLowerCase()) {
    case 'fr':
      return ScrabbleLanguage.fr;
    case 'en':
      return ScrabbleLanguage.en;
    case 'es':
      return ScrabbleLanguage.es;
    default:
      return ScrabbleLanguage.fr; // valeur par défaut
  }
}

Future<void>? _dictionaryLoadingFuture;

Future<void> loadDefaultDictionary() {
  final langEnum = scrabbleLanguageFromString(settings.language);

  if (dictionaryService.language == langEnum && dictionaryService.isLoaded) {
    return Future.value();
  }

  return _dictionaryLoadingFuture ??= _loadDefaultDictionaryInternal(langEnum);
}

Future<void> _loadDefaultDictionaryInternal(ScrabbleLanguage langEnum) async {
  try {
    final content = await rootBundle.loadString('assets/dictionary.txt');

    dictionaryService.replaceFromText(content, langEnum);
    dictionaryService.setLanguage(langEnum);

    if (debug) {
      print(
        '[Dictionary] ${dictionaryService.size} mots chargés '
        '(${langEnum.name})',
      );
    }
  } catch (e, stack) {
    debugPrint('Dictionary load error: $e');
    debugPrint('$stack');

    _showDictionaryError(e);
  } finally {
    _dictionaryLoadingFuture = null;
  }
}

void _showDictionaryError(Object e) {
  final context = navigatorKey.currentContext;

  if (context == null || !context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '⚠️ Impossible de charger le dictionnaire: $e',
        style: const TextStyle(fontSize: 14),
      ),
      backgroundColor: Colors.redAccent,
      duration: const Duration(seconds: 4),
    ),
  );
}
