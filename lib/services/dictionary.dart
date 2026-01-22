class DictionaryService {
  Set<String> _words = {};

  bool get isLoaded => _words.isNotEmpty;

  bool contains(String word) {
    return _words.contains(word.toUpperCase());
  }

  void replaceFromText(String content) {
    _words =
        content
            .split('\n')
            .map((w) => w.trim().toUpperCase())
            .where((w) => w.isNotEmpty)
            .toSet();
  }

  int get size => _words.length;
}

// instance globale unique
final dictionaryService = DictionaryService();
