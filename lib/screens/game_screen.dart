import 'package:flutter/material.dart';
import 'dart:async';
import 'package:scrabble_P2P/models/board.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/models/player_rack.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/utility.dart';
import 'package:scrabble_P2P/services/game_end.dart';
import 'package:scrabble_P2P/services/game_update.dart';
import 'package:scrabble_P2P/services/dictionary.dart';
import 'package:scrabble_P2P/services/dictionary_loader.dart';
import 'package:scrabble_P2P/models/placed_letter.dart';
import 'package:scrabble_P2P/screens/show_bag.dart';
import 'package:scrabble_P2P/screens/home_screen.dart';
import 'package:scrabble_P2P/score.dart';
import 'package:scrabble_P2P/constants.dart';

typedef MovePlayedCallback = void Function(GameMove move);

/// Structure représentant un coup joué.
class GameMove {
  final String letter;
  final int row;
  final int col;
  final bool isJoker;
  GameMove({
    required this.letter,
    required this.row,
    required this.col,
    required this.isJoker,
  });
}

class GameScreen extends StatefulWidget {
  final ScrabbleNet net;
  final GameState gameState;
  final MovePlayedCallback? onMovePlayed;
  final void Function(GameState updatedGameState)? onGameStateUpdated;

  const GameScreen({
    super.key,
    required this.net,
    required this.gameState,
    this.onMovePlayed,
    this.onGameStateUpdated,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GlobalKey _boardKey = GlobalKey();
  String _appBarTitle = defaultTitle;
  late ScrabbleNet _net;
  late List<String> _playerLetters;
  late List<List<String>> _board;
  late List<String> _initialRack;
  final List<PlacedLetter> _lettersPlacedThisTurn = [];
  final TransformationController _boardController = TransformationController();
  bool _firstLetter = true;
  late final GameUpdateHandler _updateHandler;
  bool _endPopupShown = false;
  late GameState _gameState;
  ({List<String> words, int totalScore})? _cachedTurnResult;
  bool _cachedTurnValid = false;

  void _applyGameState(GameState newState) {
    _appBarTitle = defaultTitle;

    setState(() {
      //Force flutter à reconnaître le changement de l’état du jeu
      // 🔥 REMPLACEMENT COMPLET (clé du bug)
      _gameState = newState;

      final localName = settings.localUserName;
      _board = _gameState.board.map((row) => List<String>.from(row)).toList();

      _playerLetters = _gameState.localRack(localName);
      _initialRack = List.from(_playerLetters);

      _lettersPlacedThisTurn
        ..clear()
        ..addAll(_gameState.lettersPlacedThisTurn);

      _boardController.value = Matrix4.identity();
      _firstLetter = true;
    });
  }

  void _onGameOver(GameState state) {
    if (!mounted || _endPopupShown) return;
    _endPopupShown = true;

    GameEndService.showEndGamePopup(
      context: context,
      finalState: state,
      net: _net,
      onRematchStarted: (newGameState) {
        if (!mounted) return;
        // 🔓 autoriser les envois
        _net.resetGameOver();
        // 🔁 prêt pour une nouvelle partie
        _endPopupShown = false;

        _applyGameState(newGameState);
        setState(() {});

        // ▶️ relancer le polling pour recevoir les coups du partenaire
        _net.startPolling(settings.localUserName);
      },
    );
  }

  ///compare deux GameState pour vérifier s'ils représentent la même partie
  bool compareGameState(GameState a, GameState b) {
    // Même couple de joueurs ? (dans n’importe quel sens)
    final setA = {a.leftName, a.rightName};
    final setB = {b.leftName, b.rightName};

    return setA.length == 2 && setA.containsAll(setB);
  }

  @override
  void initState() {
    super.initState();

    _gameState = widget.gameState;

    _net = widget.net;

    _net.onGameQuit = (partner) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$partner a quitté la partie'),
          duration: const Duration(seconds: 3),
        ),
      );

      // si je suis actuellement dans cette partie
      final currentPartner = _gameState.partnerFrom(settings.localUserName);

      if (currentPartner == partner) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;

          Navigator.of(context).popUntil((route) => route.isFirst);
        });
      }
    };
    _board = _gameState.board.map((row) => List<String>.from(row)).toList();

    _playerLetters = _gameState.localRack(settings.localUserName);
    _initialRack = List.from(_playerLetters);

    _updateHandler = GameUpdateHandler(
      net: _net,

      // 🔥 applique un état entrant (UI ou non)
      applyIncomingState: (newState, {required bool updateUI}) async {
        _applyGameState(newState);
        if (updateUI && mounted) setState(() {});
      },

      // 🔥 état courant TOUJOURS à jour
      getCurrentGame: () => _gameState,

      // 🔥 état du widget
      isMounted: () => mounted,

      // 🔔 notification quand un autre joueur joue sur une autre partie
      onBackgroundMove: (incoming) {
        if (!mounted) return;

        final opponent = incoming.partnerFrom(settings.localUserName);

        final context = this.context;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$opponent a joué un coup'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Ouvrir',
              onPressed: () async {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => GameScreen(
                          net: widget.net, // réutilise le net existant
                          gameState:
                              incoming, // gameState de la partie à ouvrir
                          onMovePlayed: widget.onMovePlayed,
                          onGameStateUpdated: widget.onGameStateUpdated,
                        ),
                  ),
                );
              },
            ),
          ),
        );
      },
      onGameOver: _onGameOver,
    );

    _updateHandler.attach();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await loadDefaultDictionary();

      if (debug) {
        print(
          '[GameScreen] dictionnaire prêt après affichage '
          '${dictionaryService.size} mots',
        );
      }
    });
    saveSettings();
  }

  Future<String?> _askJokerLetter() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        String selected = 'A';

        final letters = List.generate(26, (i) => String.fromCharCode(65 + i));

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Choisir la lettre du joker'),

              content: SizedBox(
                width: 260,
                height: 220,

                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),

                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.2,
                  ),

                  itemCount: letters.length,

                  itemBuilder: (context, index) {
                    final letter = letters[index];

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor:
                            selected == letter ? Colors.orange : null,
                      ),

                      onPressed: () {
                        setState(() {
                          selected = letter;
                        });
                      },

                      child: Text(
                        letter,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: Text('OK ($selected)'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void onLetterPlaced(
    String letter,
    int row,
    int col,
    int? oldRow,
    int? oldCol,
  ) async {
    if (_board[row][col].isNotEmpty) return;

    String effectiveLetter = letter;
    bool isJoker = false;

    if (letter == ' ') {
      final chosen = await _askJokerLetter();
      if (chosen == null) return; // sécurité
      effectiveLetter = chosen;
      isJoker = true;
    }

    setState(() {
      if (_firstLetter) {
        clearLettersPlacedThisTurn();
        _firstLetter = false;
      }

      final placedLetter = PlacedLetter(
        row: row,
        col: col,
        letter: effectiveLetter,
        isJoker: isJoker,
        jokerValue: isJoker ? effectiveLetter : null,
        placedThisTurn: true,
      );

      if (oldRow != null && oldCol != null) {
        final index = _lettersPlacedThisTurn.indexWhere(
          (e) => e.row == oldRow && e.col == oldCol,
        );
        if (index != -1) {
          _lettersPlacedThisTurn[index] = placedLetter;
        }
        clearBoard(oldRow, oldCol);
      } else {
        _playerLetters.remove(letter);
        _lettersPlacedThisTurn.add(placedLetter);
      }

      _board[row][col] = _gameState.board[row][col] = effectiveLetter;

      _cachedTurnValid = false;
      _updateTitleWithProvisionalScore();
    });

    widget.onMovePlayed?.call(
      GameMove(letter: effectiveLetter, row: row, col: col, isJoker: isJoker),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _zoomOnArea(row, col);
    });
  }

  void _zoomOnArea(int row, int col) {
    final context = _boardKey.currentContext;
    if (context == null) return;

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Size boardSize = box.size;

    final double cellSize = boardSize.width / 15;
    const int zoomCells = 12;

    final double scale = 15 / zoomCells;

    final double visibleSize = boardSize.width / scale;

    // 🎯 centrer la cellule
    double targetX = (col + 0.5) * cellSize - visibleSize / 2;
    double targetY = (row + 0.5) * cellSize - visibleSize / 2;

    final double max = boardSize.width - visibleSize;

    targetX = targetX.clamp(0.0, max);
    targetY = targetY.clamp(0.0, max);

    _boardController.value =
        Matrix4.identity()
          ..scale(scale)
          ..translate(-targetX, -targetY);
  }

  void _handleUndo() {
    if (_firstLetter) return;
    setState(() {
      for (final placed in _lettersPlacedThisTurn) {
        clearBoard(placed.row, placed.col);
        _playerLetters.add(placed.letter);
      }
      // _playerLetters = List.from(_initialRack);
      clearLettersPlacedThisTurn();
      _cachedTurnValid = false;
      _updateTitleWithProvisionalScore();
    });
  }

  void _handleSubmit() {
    if (_cachedTurnResult == null || !_cachedTurnValid) {
      // Aucun résultat validé à utiliser
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Le coup n'est pas valide")));
      return;
    }

    final result = _cachedTurnResult!;
    final totalScore = result.totalScore;

    setState(() {
      // Appliquer le score au joueur actif
      if (_gameState.isLeft) {
        _gameState.leftScore += totalScore;
      } else {
        _gameState.rightScore += totalScore;
      }

      // Placer définitivement les lettres sur le plateau
      for (final placed in _lettersPlacedThisTurn) {
        _gameState.board[placed.row][placed.col] = placed.letter;
      }
      // Transmettre les _lettersPlacedThisTurn pour surbrillance
      _gameState.lettersPlacedThisTurn = List.from(_lettersPlacedThisTurn);

      // Tirer de nouvelles lettres
      refillRack(7);

      // Passer au tour suivant
      _gameState.isLeft = !_gameState.isLeft;

      // La partie prend fin lorsqu'un joueur n'a plus de lettres
      // et que les 2 joueurs ont joué le même nombre de tours
      // Un joueur n’a plus de lettres
      final leftEmpty = _gameState.leftLetters.isEmpty;
      final rightEmpty = _gameState.rightLetters.isEmpty;

      if (leftEmpty || rightEmpty) {
        final finalState = GameState.fromJson(_gameState.toJson());
        final iAmLeft = settings.localUserName == finalState.leftName;
        final iAmRight = settings.localUserName == finalState.rightName;

        if (leftEmpty) {
          if (iAmLeft) {
            //G(gauche) a fini. Je suis G. J’ai joué mon dernier coup. Je dois attendre le dernier coup de D.
            _net.sendGameOver(finalState);
            _net.startPolling(settings.localUserName);
            return;
          }

          if (iAmRight) {
            //G a fini. Je suis D. J’ai reçu le GAMEOVER de G. Je dois jouer mon dernier coup.
            setState(() {
              _appBarTitle = "Dernier coup";
            });
            _net.sendGameOver(finalState);
            _onGameOver(finalState);
            return;
          }
        }

        if (rightEmpty) {
          //D a fini. Je suis D. J'envois gameOver à G et j'affiche le popup de fin de partie.
          if (iAmRight) {
            _net.sendGameOver(finalState);
            _onGameOver(finalState);
            return;
          }

          if (iAmLeft) {
            //D a fini. Je suis G. j'affiche le popup de fin de partie.
            _onGameOver(finalState);
            return;
          }
        }
      } else {
        // ⚡️ Envoyer le nouvel état de jeu
        widget.onGameStateUpdated?.call(_gameState);

        // ✅ Réinitialiser _lettersPlacedThisTurn pour neutraliser _returnLetterToRack
        clearLettersPlacedThisTurn();

        if (debug) print("${logHeader('handleSubmit')} Sauvegarde après envoi");
        gameStorage.save(_gameState);

        setState(() => _appBarTitle = defaultTitle);
      }
      // 🔹 Réinitialiser le zoom à 100% (identité)
      _boardController.value = Matrix4.identity();
    });
  }

  void refillRack(int rackSize) {
    int missing = rackSize - _playerLetters.length;
    if (missing > 0) {
      final drawn = _gameState.bag.drawLetters(missing);
      // _playerLetters.addAll(drawn);

      // ✅ MISE À JOUR du GameState avec les nouvelles lettres
      if (_gameState.isLeft) {
        _gameState.leftLetters = List.from(_playerLetters);
      } else {
        _gameState.rightLetters = List.from(_playerLetters);
      }
    }
  }

  @override
  void dispose() {
    _net.onError = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localName = settings.localUserName;

    // 🔹 C’est au joueur de gauche si isLeft == true
    final bool isCurrentTurn =
        _gameState.isLeft
            ? (_gameState.leftName == localName)
            : (_gameState.rightName == localName);

    return WillPopScope(
      onWillPop: () async => false, // ⛔ empêche flèche gauche
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // ⛔ flèche UI
          title: Text(_appBarTitle),
        ),
        body: Column(
          children: [
            _buildScoreBar(),
            Expanded(
              flex: 5,
              child: GestureDetector(
                onDoubleTap: () => _boardController.value = Matrix4.identity(),
                child: InteractiveViewer(
                  transformationController: _boardController,
                  panEnabled: true,
                  minScale: 1.0,
                  maxScale: 15 / 12,
                  child: buildScrabbleBoard(
                    boardKey: _boardKey,
                    board: _board,
                    dictionary: dictionaryService,
                    lettersPlacedThisTurn:
                        _lettersPlacedThisTurn
                            .map(
                              (e) => PlacedLetter(
                                row: e.row,
                                col: e.col,
                                letter: e.letter,
                                isJoker: e.isJoker,
                                jokerValue: e.jokerValue,
                                placedThisTurn: e.placedThisTurn,
                              ),
                            )
                            .toList(),
                    onLetterPlaced: onLetterPlaced,
                    onLetterReturned: _returnLetterToRack,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 60,
              child: PlayerRack(
                letters: _playerLetters,
                onMove: (fromIndex, toIndex) {
                  setState(() {
                    final letter = _playerLetters.removeAt(fromIndex);
                    _playerLetters.insert(toIndex, letter);
                  });
                },
                onAddLetter: (String letter, {int? hoveredIndex}) {
                  // Utilisez un paramètre nommé
                  setState(() {
                    if (hoveredIndex != null) {
                      _playerLetters.insert(hoveredIndex, letter);
                    } else {
                      _playerLetters.add(letter);
                    }
                  });
                },
                onRemoveFromBoard: (row, col) {
                  setState(() {
                    clearBoard(row, col);
                    _lettersPlacedThisTurn.removeWhere(
                      (placed) => placed.row == row && placed.col == col,
                    );
                  });
                },
                onRemoveLetter:
                    (i) => setState(() => _playerLetters.removeAt(i)),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(isCurrentTurn),
      ),
    );
  }

  Widget _buildScoreBar() {
    final nameDspl = settings.nameDisplayLimit;
    final screenWidth = MediaQuery.of(context).size.width;

    // Ajustement de la taille de police en fonction de la largeur de l'écran
    double nameFontSize;
    if (screenWidth < 350) {
      nameFontSize = 12;
    } else if (screenWidth < 500) {
      nameFontSize = 14;
    } else {
      nameFontSize = 16;
    }

    // Limite les noms à nameDspl caractères
    String shortLeftName =
        _gameState.leftName.length > nameDspl
            ? _gameState.leftName.substring(0, nameDspl)
            : _gameState.leftName;
    String shortRightName =
        _gameState.rightName.length > nameDspl
            ? _gameState.rightName.substring(0, nameDspl)
            : _gameState.rightName;

    return Container(
      color: const Color.fromARGB(255, 167, 156, 13),
      padding: const EdgeInsets.all(0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _scoreContainer(
            "$shortLeftName: ${_gameState.leftScore}",
            _gameState.isLeft,
            fontSize: nameFontSize,
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.deepPurple,
            child: Text("vs", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          _scoreContainer(
            "$shortRightName: ${_gameState.rightScore}",
            !_gameState.isLeft,
            fontSize: nameFontSize,
          ),
        ],
      ),
    );
  }

  Widget _scoreContainer(
    String text,
    bool isActive, {
    required double fontSize,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[700] : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isCurrentTurn) {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Retour à l’accueil',
              icon: const Icon(Icons.home),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false, // supprime toute la pile
                );
              },
            ),

            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: "Annuler",
              onPressed: _handleUndo,
            ),
            ElevatedButton(
              onPressed: isCurrentTurn ? _handleSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 141, 23, 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                "Envoyer",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: "Afficher le sac de lettres",
              icon: const Icon(Icons.inventory_2),
              onPressed: () {
                _gameState.bag.showContents(context);
              },
            ),
            IconButton(
              tooltip: 'Abandonner la partie', // ✅ Affiche ce texte au survol
              icon: const Icon(Icons.exit_to_app),
              onPressed:
                  isCurrentTurn
                      ? () async {
                        final bool? confirmQuit = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Confirmer l’abandon'),
                              content: const Text(
                                'Souhaitez-vous vraiment abandonner la partie ?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(false),
                                  child: const Text('Annuler'),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.of(context).pop(true),
                                  child: const Text('Abandonner'),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirmQuit != true)
                          return; // ✅ Si l’utilisateur annule, on quitte sans rien faire

                        final user = settings.localUserName;
                        final partner = _gameState.partnerFrom(user);

                        try {
                          // ensure quit completes before clearing / navigating
                          await widget.net.quit(user, partner);
                          widget.net.resetGameOver();
                        } catch (e) {
                          print("⛔ Erreur abandon: $e");
                        }

                        // Supprime le GameState local
                        await gameStorage.delete(partner);

                        // Retourne à l’écran d’accueil
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        }
                      }
                      : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Retourne une lettre placée sur le plateau dans le rack du joueur
  /// et supprime la lettre du plateau.
  void _returnLetterToRack(PlacedLetter placedLetter) {
    setState(() {
      // ⚡ Déterminer la lettre à remettre
      final letterToReturn = placedLetter.isJoker ? ' ' : placedLetter.letter;
      _playerLetters.add(letterToReturn);

      // ⚡ Retirer la bonne instance du plateau
      final idx = _lettersPlacedThisTurn.indexWhere(
        (p) => p.row == placedLetter.row && p.col == placedLetter.col,
      );

      if (idx != -1) {
        _lettersPlacedThisTurn.removeAt(idx);
        clearBoard(placedLetter.row, placedLetter.col);
      }

      _cachedTurnValid = false;
      _updateTitleWithProvisionalScore();
    });
  }

  void _updateTitleWithProvisionalScore() {
    if (_lettersPlacedThisTurn.isEmpty) {
      setState(() {
        _appBarTitle = defaultTitle;
        _cachedTurnResult = null;
        _cachedTurnValid = false;
      });
      return;
    }

    try {
      final result = getWordsCreatedAndScore(
        board: _gameState.board,
        lettersPlacedThisTurn: _lettersPlacedThisTurn,
        dictionary: dictionaryService,
      );

      _cachedTurnResult = result;
      _cachedTurnValid = true;

      setState(() {
        _appBarTitle = "Score provisoire : ${result.totalScore}";
      });
    } on InvalidWordException catch (e) {
      _cachedTurnResult = null;
      _cachedTurnValid = false;

      setState(() {
        _appBarTitle = "Mot invalide : ${e.word}";
      });
    }
  }

  void clearBoard(row, col) {
    setState(() {
      _gameState.board[row][col] = _board[row][col] = '';
    });
  }

  void clearLettersPlacedThisTurn() {
    setState(() {
      _lettersPlacedThisTurn.clear();
      _gameState.lettersPlacedThisTurn.clear();
    });
  }
}
