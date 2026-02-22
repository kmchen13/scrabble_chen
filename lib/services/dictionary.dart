import 'package:diacritic/diacritic.dart';

enum ScrabbleLanguage { fr, en, es }

class DictionaryService {
  ScrabbleLanguage _language = ScrabbleLanguage.fr;

  final Map<ScrabbleLanguage, Set<String>> _wordsByLang = {};

  /// NEW: normalized → canonical
  final Map<ScrabbleLanguage, Map<String, String>> _canonicalByLang = {};

  ScrabbleLanguage get language => _language;

  bool get isLoaded => _wordsByLang[_language]?.isNotEmpty ?? false;

  int get size => _wordsByLang[_language]?.length ?? 0;

  void setLanguage(ScrabbleLanguage lang) {
    _language = lang;
  }

  bool contains(String word) {
    final normalized = _normalize(word, _language);
    final words = _wordsByLang[_language] ?? {};
    return words.contains(normalized);
  }

  /// NEW METHOD
  String? getCanonicalForm(String word) {
    final normalized = _normalize(word, _language);
    return _canonicalByLang[_language]?[normalized];
  }

  void replaceFromText(String content, ScrabbleLanguage lang) {
    final words = <String>{};
    final canonicalMap = <String, String>{};

    for (final raw in content.split('\n')) {
      final canonical = raw.trim();
      if (canonical.isEmpty) continue;

      final normalized = _normalize(
        canonical,
        lang,
      ); // MAJUSCULES pour Scrabble

      words.add(normalized);

      /// stocker canonical en minuscules pour Wiktionnaire
      canonicalMap[normalized] = canonical.toLowerCase();
    }

    _wordsByLang[lang] = words;
    _canonicalByLang[lang] = canonicalMap;
  }

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
