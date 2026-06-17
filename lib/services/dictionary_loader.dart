import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scrabble_P2P/constants.dart';
import 'settings_service.dart';
import 'package:scrabble_P2P/services/assets_manager.dart';
import 'dictionary.dart';

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
      return ScrabbleLanguage.fr;
  }
}

Future<void>? _dictionaryLoadingFuture;

Future<void> loadDefaultDictionary() {
  final langEnum = scrabbleLanguageFromString(settings.language);

  // déjà chargé
  if (dictionaryService.language == langEnum && dictionaryService.isLoaded) {
    return Future.value();
  }

  // un chargement est déjà en cours
  return _dictionaryLoadingFuture ??= _loadDefaultDictionaryInternal(langEnum);
}

Future<void> _loadDefaultDictionaryInternal(ScrabbleLanguage langEnum) async {
  try {
    final content = await AssetManager.loadString('assets/dictionary.txt');
    dictionaryService.replaceFromText(content, langEnum);

    dictionaryService.setLanguage(langEnum);

    if (debug) {
      print(
        '[Dictionary] '
        '${dictionaryService.size} mots chargés '
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

  if (context == null || !context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('⚠️ Impossible de charger le dictionnaire: $e'),
      backgroundColor: Colors.redAccent,
    ),
  );
}
