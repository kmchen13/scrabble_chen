import 'package:diacritic/diacritic.dart';

enum ScrabbleLanguage { fr, en, es }

class DictionaryService {
  ScrabbleLanguage _language = ScrabbleLanguage.fr;
  final Map<ScrabbleLanguage, Set<String>> _wordsByLang = {};

  ScrabbleLanguage get language => _language;

  bool get isLoaded => _wordsByLang[_language]?.isNotEmpty ?? false;

  int get size => _wordsByLang[_language]?.length ?? 0;

  /// Définit la langue active et remplace le dictionnaire si besoin
  void setLanguage(ScrabbleLanguage lang) {
    _language = lang;
  }

  /// Vérifie si le mot est dans le dictionnaire Scrabble
  bool contains(String word) {
    final normalized = _normalize(word, _language);
    final words = _wordsByLang[_language] ?? {};
    return words.contains(normalized);
  }

  /// Remplace le dictionnaire pour une langue
  void replaceFromText(String content, ScrabbleLanguage lang) {
    final words =
        content
            .split('\n')
            .map((w) => w.trim())
            .where((w) => w.isNotEmpty)
            .map((w) => _normalize(w, lang))
            .toSet();

    _wordsByLang[lang] = words;
  }

  /// Normalisation selon la langue
  /// - FR / ES : supprime les accents
  /// - EN : majuscule seulement
  String _normalize(String word, ScrabbleLanguage lang) {
    switch (lang) {
      case ScrabbleLanguage.fr:
      case ScrabbleLanguage.es:
        return removeDiacritics(word).toUpperCase();
      case ScrabbleLanguage.en:
        return word.toUpperCase();
    }
  }
}

// instance globale unique
final dictionaryService = DictionaryService();

extension ScrabbleLanguageX on ScrabbleLanguage {
  /// Convertit un String ('fr', 'en', 'es') en ScrabbleLanguage
  static ScrabbleLanguage fromString(String lang) {
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
}
