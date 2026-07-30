import 'package:flutter/material.dart';
import 'dart:async';
import 'package:scrabble_P2P/models/board.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/models/player_rack.dart';
import 'package:scrabble_P2P/models/star_painter.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/services/admob_manager.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/utility.dart';
import 'package:scrabble_P2P/services/game_callback_manager.dart'; // 🔥 NOUVEAU
import 'package:scrabble_P2P/services/game_end.dart';
import 'package:scrabble_P2P/services/turn_pass.dart';
import 'package:scrabble_P2P/services/game_update.dart';
import 'package:scrabble_P2P/services/dictionary.dart';
import 'package:scrabble_P2P/services/dictionary_loader.dart';
import 'package:scrabble_P2P/models/placed_letter.dart';
import 'package:scrabble_P2P/screens/show_bag.dart';
import 'package:scrabble_P2P/screens/home_screen.dart';
import 'package:scrabble_P2P/screens/admob_widgets.dart';
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
  ({List<String> words, int totalScore, int totalStarsUsed})? _cachedTurnResult;
  bool _cachedTurnValid = false;
  final AdMobManager _adMobManager = AdMobManager();
  final localName = settings.localUserName;

  void _applyGameState(GameState newState) {
    if (debug) {
      print("$logHeader(gameScreen._applyGameState) ${identityHashCode(this)}");
    }
    _appBarTitle = defaultTitle;

    _gameState = newState;

    _board = _gameState.board.map((row) => List<String>.from(row)).toList();

    _playerLetters = _gameState.localRack(localName);
    _initialRack = List.from(_playerLetters);

    _lettersPlacedThisTurn
      ..clear()
      ..addAll(_gameState.lettersPlacedThisTurn);

    _boardController.value = Matrix4.identity();
    _firstLetter = true;
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
        _net.resetGameOver();
        _endPopupShown = false;

        _applyGameState(newGameState);
        setState(() {});

        _net.startPolling(settings.localUserName);
      },
    );
  }

  @override
  void initState() {
    super.initState();

    _gameState = widget.gameState;
    _net = widget.net;

    _board = _gameState.board.map((row) => List<String>.from(row)).toList();
    _playerLetters = _gameState.localRack(settings.localUserName);
    _initialRack = List.from(_playerLetters);

    // 🔥 Création de l'handler (sans attach)
    _updateHandler = GameUpdateHandler(
      net: _net,
      applyIncomingState: (newState, {required bool updateUI}) async {
        if (debug) {
          print(
            "$logHeader(game_screen.applyIncomingState) ${identityHashCode(this)}",
          );
        }
        _applyGameState(newState);
        if (updateUI && mounted) setState(() {});
      },
      getCurrentGame: () => _gameState,
      isMounted: () => mounted,
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
                          net: widget.net,
                          gameState: incoming,
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
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erreur réseau: $msg')));
        }
      },
    );

    // 🔥 Enregistrement des callbacks via le manager (plus de attach())
    GameCallbackManager().setCallbacks(
      owner: 'game',
      onGameState: (GameState incoming) {
        _updateHandler.onGameStateReceived(incoming);
      },
      onGameOver: (GameState finalState) {
        _updateHandler.onGameOverReceived(finalState);
      },
      onGameQuit: (String partner) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$partner a quitté la partie'),
            duration: const Duration(seconds: 3),
          ),
        );
        final currentPartner = _gameState.partnerFrom(settings.localUserName);
        if (currentPartner == partner) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
          });
        }
      },
      onError: (String message) {
        _updateHandler.onErrorReceived(message);
      },
    );

    // 🔥 Flush initial (équivalent à l'ancien attach)
    _updateHandler.flushPending();

    // Chargement du dictionnaire
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

    // AdMob
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adMobManager.setCallbacks(
        onLoaded: () {
          if (mounted) setState(() {});
        },
        onFailed: () {
          if (mounted) setState(() {});
        },
      );
      _adMobManager.loadBanner(context);
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
      if (chosen == null) return;
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
        // ✅ DÉPLACEMENT D'UNE LETTRE

        // Retirer l'ancienne position
        final index = _lettersPlacedThisTurn.indexWhere(
          (e) => e.row == oldRow && e.col == oldCol,
        );
        if (index != -1) {
          final oldLetter = _lettersPlacedThisTurn[index];

          // ✅ Si c'était un joker, conserver ses infos
          if (oldLetter.isJoker) {
            // Utiliser les anciennes valeurs joker
            final newPlacedLetter = PlacedLetter(
              row: row,
              col: col,
              letter: oldLetter.letter, // '*'
              isJoker: true,
              jokerValue: oldLetter.jokerValue,
              placedThisTurn: true,
            );
            _lettersPlacedThisTurn[index] = newPlacedLetter;
          } else {
            // Lettre normale
            _lettersPlacedThisTurn[index] = placedLetter;
          }

          // Effacer l'ancienne position (ne pas effacer boardJokerInfo ici)
          _board[oldRow][oldCol] = '';
          _gameState.board[oldRow][oldCol] = '';
          // ⚠️ NE PAS effacer boardJokerInfo ici car on déplace la lettre
          // Elle sera mise à jour à la nouvelle position
        }

        // Placer à la nouvelle position
        _board[row][col] = _gameState.board[row][col] = effectiveLetter;

        // ✅ Mettre à jour les infos joker à la nouvelle position
        if (isJoker) {
          _gameState.boardJokerInfo[row][col] = {
            'isJoker': true,
            'jokerValue': effectiveLetter,
          };
        } else {
          // Si ce n'est pas un joker, effacer les infos à la nouvelle position
          _gameState.boardJokerInfo[row][col] = null;
        }

        // ✅ Nettoyer les infos joker à l'ancienne position
        // car la lettre a été déplacée
        _gameState.boardJokerInfo[oldRow][oldCol] = null;
      } else {
        // ✅ NOUVELLE LETTRE
        _playerLetters.remove(letter);
        _lettersPlacedThisTurn.add(placedLetter);

        _board[row][col] = _gameState.board[row][col] = effectiveLetter;

        // ✅ STOCKER LES INFOS JOKER
        if (isJoker) {
          _gameState.boardJokerInfo[row][col] = {
            'isJoker': true,
            'jokerValue': effectiveLetter,
          };
        } else {
          _gameState.boardJokerInfo[row][col] = null;
        }
      }

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
        // ✅ Pour un joker, remettre un espace ' ' dans le rack
        // Pour une lettre normale, remettre la lettre
        final letterToReturn = placed.isJoker ? ' ' : placed.letter;
        _playerLetters.add(letterToReturn);

        // ✅ Nettoyer complètement la case (board + infos joker)
        _board[placed.row][placed.col] = '';
        _gameState.board[placed.row][placed.col] = '';
        _gameState.boardJokerInfo[placed.row][placed.col] = null;
      }

      // ✅ Vider la liste des lettres placées
      _lettersPlacedThisTurn.clear();
      _firstLetter = true;
      _cachedTurnValid = false;
      _updateTitleWithProvisionalScore();
    });
  }

  void _handleSubmit() {
    if (_cachedTurnResult == null || !_cachedTurnValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Le coup n'est pas valide")));
      return;
    }

    final result = _cachedTurnResult!;
    final totalScore = result.totalScore;
    final totalStarsUsed = result.totalStarsUsed;

    print('📊 Score: $totalScore, Étoiles gagnées: $totalStarsUsed');

    setState(() {
      // Appliquer le score au joueur actif
      if (_gameState.isLeft) {
        _gameState.leftScore += totalScore;
        // ✅ Ajouter les étoiles gagnées (sans multiplier le score)
        _gameState.leftStars += totalStarsUsed;
        print('⭐ leftStars: ${_gameState.leftStars}');
      } else {
        _gameState.rightScore += totalScore;
        // ✅ Ajouter les étoiles gagnées (sans multiplier le score)
        _gameState.rightStars += totalStarsUsed;
        print('⭐ rightStars: ${_gameState.rightStars}');
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
      _playerLetters.addAll(drawn);

      // ✅ MISE À JOUR du GameState avec les nouvelles lettres
      if (_gameState.isLeft) {
        _gameState.leftLetters = List.from(_playerLetters);
      } else {
        _gameState.rightLetters = List.from(_playerLetters);
      }
    }
  }

  void _handleStarUsed() {
    if (debug)
      print("$logHeader(gameScreen._handleStarUsed) ${identityHashCode(this)}");
    final playerName = settings.localUserName;
    final isLeft = _gameState.leftName == playerName;

    if (isLeft && _gameState.leftStars <= 0) return;
    if (!isLeft && _gameState.rightStars <= 0) return;

    // ✅ Créer une copie du GameState avec les modifications
    GameState newState;

    if (isLeft) {
      final currentLetters = List<String>.from(_gameState.leftLetters);
      for (final letter in currentLetters) {
        _gameState.bag.addLetter(letter);
      }
      final newLetters = _gameState.bag.drawLetters(7);

      newState = _gameState.copyWith(
        leftStars: _gameState.leftStars - 1,
        leftLetters: newLetters,
        lettersPlacedThisTurn: [],
      );
    } else {
      final currentLetters = List<String>.from(_gameState.rightLetters);
      for (final letter in currentLetters) {
        _gameState.bag.addLetter(letter);
      }
      final newLetters = _gameState.bag.drawLetters(7);

      newState = _gameState.copyWith(
        rightStars: _gameState.rightStars - 1,
        rightLetters: newLetters,
        lettersPlacedThisTurn: [],
      );
    }

    // ✅ Remplacer l'ancien GameState par le nouveau
    _gameState = newState;
    _lettersPlacedThisTurn.clear();
    _appBarTitle = defaultTitle;

    // ✅ Sauvegarder
    gameStorage.save(_gameState);

    // ✅ Envoyer la mise à jour
    widget.net.sendGameState(_gameState);

    // ✅ Utiliser applyIncomingState pour forcer le rebuild (comme pour les messages réseau)
    _updateHandler.applyIncomingState(_gameState, updateUI: true);
  }

  /// 🔹 Gestion du passage de tour
  void _handlePass() {
    // Vérifier que c'est bien le tour du joueur
    final isCurrentTurn =
        _gameState.isLeft
            ? (_gameState.leftName == localName)
            : (_gameState.rightName == localName);

    if (!isCurrentTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce n\'est pas votre tour'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Ouvrir le dialogue de passage de tour
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return TurnPassDialog(
          playerLetters: _playerLetters,
          bag: _gameState.bag,
          onPass: (newLetters) {
            // ✅ Mettre à jour _playerLetters avec les nouvelles lettres
            _playerLetters = List.from(newLetters);

            // ✅ Créer une copie du GameState avec les modifications
            GameState newState;
            final playerName = settings.localUserName;
            final isLeft = _gameState.leftName == playerName;

            // Changer le tour (passer à l'autre joueur)
            final newIsLeft = !_gameState.isLeft;

            if (isLeft) {
              newState = _gameState.copyWith(
                leftLetters: _playerLetters,
                lettersPlacedThisTurn: [],
                isLeft: newIsLeft, // ✅ Changer le tour
              );
            } else {
              newState = _gameState.copyWith(
                rightLetters: _playerLetters,
                lettersPlacedThisTurn: [],
                isLeft: newIsLeft, // ✅ Changer le tour
              );
            }

            // ✅ Remplacer l'ancien GameState par le nouveau
            _gameState = newState;
            _lettersPlacedThisTurn.clear();
            _appBarTitle = defaultTitle;

            // ✅ Sauvegarder
            gameStorage.save(_gameState);

            // ✅ Envoyer la mise à jour sur le réseau
            widget.net.sendGameState(_gameState);

            // ✅ Mettre à jour l'UI
            setState(() {
              // Forcer le rebuild avec le nouveau state
            });

            // ✅ Utiliser applyIncomingState pour forcer le rebuild
            _updateHandler.applyIncomingState(_gameState, updateUI: true);

            // ✅ Afficher un feedback
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tour passé avec succès'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _net.onError = null;
    _adMobManager.dispose();
    // 🔥 Libérer les callbacks du GameScreen
    GameCallbackManager().clearCallbacks(owner: 'game');
    // Nettoyer l'handler si nécessaire (il n'y a plus de detach)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentTurn =
        _gameState.isLeft
            ? (_gameState.leftName == localName)
            : (_gameState.rightName == localName);

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;
    final isLargeScreen = screenWidth > 600;

    final double titleHeight =
        isVerySmallScreen ? 32 : (isSmallScreen ? 38 : 56);
    final double fontSize = isVerySmallScreen ? 12 : (isSmallScreen ? 14 : 20);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A2A3A),
        appBar: AdBannerAppBar(
          manager: _adMobManager,
          title: _appBarTitle,
          titleHeight: titleHeight,
          fontSize: fontSize,
        ),
        body: Column(
          children: [
            // ✅ SCOREBAR (sans bordure)
            _buildScoreBar(),

            // ✅ PLATEAU
            Expanded(
              flex: 5,
              child: GestureDetector(
                onDoubleTap: () => _boardController.value = Matrix4.identity(),
                child: InteractiveViewer(
                  transformationController: _boardController,
                  panEnabled: true,
                  minScale: 1.0,
                  maxScale: 15 / 12,
                  // Dans game_screen.dart build method
                  child: buildScrabbleBoard(
                    boardKey: _boardKey,
                    board: _board,
                    boardJokerInfo: _gameState.boardJokerInfo, // NOUVEAU
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

            // ✅ ESPACE RÉDUIT
            const SizedBox(height: 4),

            // ✅ RACK
            SizedBox(
              height: isSmallScreen ? 40 : 56,
              child: PlayerRack(
                letters: _playerLetters,
                onMove: (fromIndex, toIndex) {
                  setState(() {
                    final letter = _playerLetters.removeAt(fromIndex);
                    _playerLetters.insert(toIndex, letter);
                  });
                },
                onAddLetter: (String letter, {int? hoveredIndex}) {
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

            // ✅ ESPACE MINIMAL AVANT LE BOTTOMBAR
            const SizedBox(height: 2),

            // ✅ BOTTOMBAR (sans bannière, car elle est déjà dans l'AppBar)
            _buildBottomBar(isCurrentTurn, compact: isSmallScreen),
          ],
        ),
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

  Widget _buildBottomBar(bool isCurrentTurn, {bool compact = false}) {
    final iconSize = compact ? 18.0 : 24.0;
    final fontSize = compact ? 10.0 : 14.0;
    final buttonText = "Envoyer";

    // Récupérer le nombre d'étoiles du joueur local
    final playerName = settings.localUserName;
    final starBonus = _gameState.getStarsForPlayer(playerName);

    // ✅ Vérifier si c'est son tour ET s'il a des étoiles
    final canUseStar = isCurrentTurn && starBonus > 0;

    return BottomAppBar(
      color: const Color(0xFF1A2A3A),
      padding: EdgeInsets.zero,
      child: Padding(
        padding:
            compact
                ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bouton Home
            IconButton(
              tooltip: 'Retour à l’accueil',
              icon: Icon(Icons.home, size: iconSize),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
            ),

            // Bouton Annuler
            IconButton(
              icon: Icon(Icons.undo, size: iconSize),
              tooltip: "Annuler",
              onPressed: _handleUndo,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
            ),

            // ⭐ NOUVEAU : Bouton Passer son tour
            Tooltip(
              message: 'Passer son tour',
              preferBelow: false,
              child: IconButton(
                icon: Icon(Icons.skip_next, size: iconSize),
                color: isCurrentTurn ? Colors.white : Colors.grey.shade600,
                onPressed: isCurrentTurn ? _handlePass : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 18,
              ),
            ),

            // Bouton Envoyer
            ElevatedButton(
              onPressed: isCurrentTurn ? _handleSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 141, 23, 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(compact ? 10 : 20),
                ),
                padding:
                    compact
                        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                        : const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                minimumSize: compact ? const Size(32, 24) : null,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                buttonText,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
            ),

            // ============================================================
            // Étoile de bonus (grisée si pas son tour ou pas d'étoile)
            // ============================================================
            if (starBonus > 0)
              Tooltip(
                message:
                    canUseStar
                        ? 'Changer les lettres ($starBonus disponible${starBonus > 1 ? 's' : ''})'
                        : 'Attendez votre tour pour changer les lettres',
                preferBelow: false,
                child: GestureDetector(
                  onTap: canUseStar ? _handleStarUsed : null,
                  child: Opacity(
                    opacity: canUseStar ? 1.0 : 0.5,
                    child: SizedBox(
                      width: iconSize * 2.2,
                      height: iconSize * 2.2,
                      child: CustomPaint(
                        painter: StarPainter(
                          number: starBonus,
                          textSize: iconSize * 0.4,
                          textColor:
                              canUseStar
                                  ? const Color(0xFF006400) // Vert foncé
                                  : Colors.grey.shade600, // Grisé
                          starColor:
                              canUseStar
                                  ? const Color(0xFFFFD700) // Jaune
                                  : Colors.grey.shade500, // Grisé
                          backgroundColor:
                              canUseStar
                                  ? Colors.black
                                  : Colors.grey.shade900, // Fond grisé
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Bouton Sac
            IconButton(
              tooltip: "Sac",
              icon: Icon(Icons.inventory_2, size: iconSize),
              onPressed: () {
                _gameState.bag.showContents(context);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
            ),

            // Bouton Abandonner
            IconButton(
              tooltip: 'Abandonner',
              icon: Icon(Icons.exit_to_app, size: iconSize),
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

                        if (confirmQuit != true) return;

                        final user = settings.localUserName;
                        final partner = _gameState.partnerFrom(user);

                        try {
                          widget.net.sendGameQuit(user, partner);
                          widget.net.resetGameOver();
                        } catch (e) {
                          print("⛔ Erreur abandon: $e");
                        }

                        await gameStorage.delete(partner);

                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        }
                      }
                      : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              splashRadius: 18,
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
      // ✅ Retourner TOUJOURS un espace ' ' pour un joker
      // Le joker perd sa valeur de remplacement et redevient un joker vierge
      final letterToReturn = placedLetter.isJoker ? ' ' : placedLetter.letter;
      _playerLetters.add(letterToReturn);

      // Retirer la bonne instance du plateau
      final idx = _lettersPlacedThisTurn.indexWhere(
        (p) => p.row == placedLetter.row && p.col == placedLetter.col,
      );

      if (idx != -1) {
        _lettersPlacedThisTurn.removeAt(idx);

        // Nettoyer le board et les infos joker
        final row = placedLetter.row;
        final col = placedLetter.col;

        _board[row][col] = '';
        _gameState.board[row][col] = '';
        _gameState.boardJokerInfo[row][col] = null;
      }

      _cachedTurnValid = false;
      _updateTitleWithProvisionalScore();
    });
  }

  ///obtenir le statut joker d'une case
  bool _isJokerAtPosition(int row, int col) {
    final info = _gameState.boardJokerInfo[row][col];
    return info != null && info['isJoker'] == true;
  }

  ///
  String? _getJokerValueAtPosition(int row, int col) {
    final info = _gameState.boardJokerInfo[row][col];
    return info != null ? info['jokerValue'] as String? : null;
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
        boardJokerInfo: _gameState.boardJokerInfo,
      );

      // ✅ Le résultat contient maintenant words, totalScore ET totalStarsUsed
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

  // (utilisée uniquement quand on annule un tour ou qu'on remet toutes les lettres)
  void clearCellCompletely(int row, int col) {
    _board[row][col] = '';
    _gameState.board[row][col] = '';
    _gameState.boardJokerInfo[row][col] = null;
  }

  void clearLettersPlacedThisTurn() {
    setState(() {
      _lettersPlacedThisTurn.clear();
      _gameState.lettersPlacedThisTurn.clear();
    });
  }
}
