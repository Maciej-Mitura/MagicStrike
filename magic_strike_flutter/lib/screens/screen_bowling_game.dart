import 'dart:async';
import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import 'package:collection/collection.dart';

// Temporary model classes until we have the real implementation
class BowlingGameModel {
  final String roomCode;
  final List<BowlingPlayer> players;
  int currentPlayerIndex = 0;
  int currentFrame = 1;
  int currentThrow = 1;

  BowlingGameModel({
    required this.roomCode,
    required this.players,
  });

  BowlingPlayer? getCurrentPlayer() {
    if (currentPlayerIndex >= players.length) return null;
    return players[currentPlayerIndex];
  }

  void recordThrow(int pinsDown) {
    if (currentPlayerIndex >= players.length) return;

    final player = players[currentPlayerIndex];

    // Ensure the player has enough frames
    while (player.frames.length < currentFrame) {
      player.frames.add(BowlingFrame(frameIndex: player.frames.length));
    }

    // Get the current frame
    final frame = player.frames[currentFrame - 1];

    // Record the throw
    if (currentThrow == 1) {
      // First throw
      frame.firstThrow = pinsDown;

      // If it's a strike, move to next player/frame (except in 10th frame)
      if (pinsDown == 10 && currentFrame < 10) {
        _advanceToNextPlayer();
      } else {
        // Not a strike or 10th frame, move to second throw
        currentThrow = 2;
      }
    } else if (currentThrow == 2) {
      // Second throw
      frame.secondThrow = pinsDown;

      // In 10th frame, check if player gets bonus throw
      if (currentFrame == 10) {
        // If strike or spare in 10th, get one more throw
        if (frame.firstThrow == 10 ||
            (frame.firstThrow != null && frame.firstThrow! + pinsDown == 10)) {
          currentThrow = 3;
        } else {
          // No bonus, move to next player
          _advanceToNextPlayer();
        }
      } else {
        // Not 10th frame, always advance to next player
        _advanceToNextPlayer();
      }
    } else if (currentThrow == 3 && currentFrame == 10) {
      // Third throw (only in 10th frame)
      frame.thirdThrow = pinsDown;

      // Move to next player
      _advanceToNextPlayer();
    }

    // Calculate scores after each throw
    _calculateScores();
  }

  void _advanceToNextPlayer() {
    currentThrow = 1;

    // Next player
    currentPlayerIndex++;

    // If we've gone through all players, advance to the next frame
    if (currentPlayerIndex >= players.length) {
      currentPlayerIndex = 0;

      // Only advance the frame if we're not in the 10th frame
      if (currentFrame < 10) {
        currentFrame++;
      }

      // Check if game is complete
      if (currentFrame >= 10 && _isLastFrameComplete()) {
        // Game complete - set to invalid index to stop play
        currentPlayerIndex = players.length;
      }
    }
  }

  bool _isLastFrameComplete() {
    // If we don't have enough players or frames, game is not complete
    if (players.isEmpty) return false;

    // Check if all players have completed the 10th frame
    for (final player in players) {
      // If player doesn't have 10 frames yet, game is not complete
      if (player.frames.length < 10) return false;

      // Check if 10th frame is complete
      final tenthFrame = player.frames[9];
      if (!tenthFrame.isComplete) return false;
    }

    // All players have completed the 10th frame
    return true;
  }

  void _calculateScores() {
    // Calculate scores for each player
    for (final player in players) {
      // Calculate running score for all frames
      int totalScore = 0;

      for (int i = 0; i < player.frames.length; i++) {
        final frame = player.frames[i];
        int frameScore = 0;

        // Only calculate completed frames
        if (!frame.isComplete) continue;

        // Add pins knocked down in this frame
        if (frame.firstThrow != null) {
          frameScore += frame.firstThrow!;
        }
        if (frame.secondThrow != null) {
          frameScore += frame.secondThrow!;
        }
        if (frame.thirdThrow != null) {
          frameScore += frame.thirdThrow!;
        }

        // Add bonus for strikes and spares
        if (frame.isStrike && i < 9) {
          // Strike bonus: Next two throws
          int throwsToAdd = 2;
          int nextFrameIndex = i + 1;

          while (throwsToAdd > 0 && nextFrameIndex < player.frames.length) {
            final nextFrame = player.frames[nextFrameIndex];

            if (nextFrame.firstThrow != null) {
              frameScore += nextFrame.firstThrow!;
              throwsToAdd--;
            }

            if (throwsToAdd > 0 && nextFrame.secondThrow != null) {
              frameScore += nextFrame.secondThrow!;
              throwsToAdd--;
            }

            if (throwsToAdd > 0) {
              nextFrameIndex++;
            }
          }
        } else if (frame.isSpare && i < 9) {
          // Spare bonus: Next one throw
          int nextFrameIndex = i + 1;

          if (nextFrameIndex < player.frames.length) {
            final nextFrame = player.frames[nextFrameIndex];
            if (nextFrame.firstThrow != null) {
              frameScore += nextFrame.firstThrow!;
            }
          }
        }

        // Update the total and save to frame
        totalScore += frameScore;
        frame.score = totalScore;
      }
    }
  }

  void editFrame(String playerId, int frameIndex, int firstThrow,
      int? secondThrow, int? thirdThrow) {
    // Find player
    final player =
        players.firstWhere((p) => p.id == playerId, orElse: () => players[0]);

    // Ensure frame exists
    while (player.frames.length <= frameIndex) {
      player.frames.add(BowlingFrame(frameIndex: player.frames.length));
    }

    // Update frame
    final frame = player.frames[frameIndex];
    frame.firstThrow = firstThrow;
    frame.secondThrow = secondThrow;
    frame.thirdThrow = thirdThrow;

    // Recalculate scores
    _calculateScores();
  }
}

class BowlingPlayer {
  final String id;
  final String name;
  final List<BowlingFrame> frames;

  BowlingPlayer({
    required this.id,
    required this.name,
    required this.frames,
  });
}

class BowlingFrame {
  int? firstThrow;
  int? secondThrow;
  int? thirdThrow;
  int score = 0;
  final int frameIndex;

  BowlingFrame({required this.frameIndex});

  bool get isComplete {
    bool isTenthFrame = frameIndex == 9;

    if (!isTenthFrame) {
      // Normal frames (1-9)
      if (firstThrow == 10) return true; // Strike
      return secondThrow != null; // Two throws
    } else {
      // 10th frame
      if (firstThrow == 10 ||
          (firstThrow != null &&
              secondThrow != null &&
              firstThrow! + secondThrow! == 10)) {
        // Strike or spare - need all three throws
        return thirdThrow != null;
      } else {
        // Open frame - only need two throws
        return secondThrow != null;
      }
    }
  }

  bool get isStrike => firstThrow == 10;

  bool get isSpare {
    if (firstThrow == null || secondThrow == null) return false;
    if (isStrike) return false;
    return firstThrow! + secondThrow! == 10;
  }
}

class BowlingGameScreen extends StatefulWidget {
  final String gameCode;
  final List<String> players;
  final bool isAdmin;

  const BowlingGameScreen({
    super.key,
    required this.gameCode,
    required this.players,
    required this.isAdmin,
  });

  @override
  State<BowlingGameScreen> createState() => _BowlingGameScreenState();
}

class _BowlingGameScreenState extends State<BowlingGameScreen> {
  late BowlingGameModel _game;
  late FirestoreService _firestoreService;
  late UserService _userService;

  // For real-time updates
  StreamSubscription<QuerySnapshot>? _gameDocSubscription;
  List<Map<String, dynamic>> _gamePlayers = [];

  // For tracking pins in current throw
  List<bool> _pinStates = List.generate(10, (_) => false);
  List<bool> _previouslyKnockedPins = List.generate(10, (_) => false);
  List<bool> _previouslyKnockedPins2 = List.generate(10, (_) => false);
  int _pinsDown = 0;
  int _remainingPins = 10; // Track how many pins are remaining

  // For editing frames
  int? _selectedFrameIndex;
  String? _selectedPlayerId;
  int _selectedEditThrow = 1;

  // Add this variable to track the last player index
  int _lastPlayerIndex = -1;

  // Helper properties for frame editing
  int? get _selectedEditFrame => _selectedFrameIndex;
  BowlingPlayer? get _selectedEditPlayer =>
      _game.players.firstWhereOrNull((p) => p.id == _selectedPlayerId);

  @override
  void initState() {
    super.initState();

    _firestoreService = FirestoreService();
    _userService = UserService();

    // Initialize game with initial players
    _game = BowlingGameModel(
      roomCode: widget.gameCode,
      players: widget.players.map((name) {
        // Create player with 10 empty frames
        final player = BowlingPlayer(id: name, name: name, frames: []);

        // Initialize all 10 frames
        for (int i = 0; i < 10; i++) {
          player.frames.add(BowlingFrame(frameIndex: i));
        }

        return player;
      }).toList(),
    );

    // Listen for game updates
    _listenForGameUpdates();
  }

  @override
  void dispose() {
    _gameDocSubscription?.cancel();
    super.dispose();
  }

  void _listenForGameUpdates() {
    // Listen for updates to the game document
    _gameDocSubscription = FirebaseFirestore.instance
        .collection('games')
        .where('roomId', isEqualTo: widget.gameCode)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      final gameDoc = snapshot.docs.first;
      final gameData = gameDoc.data();

      // Get the players array from the game document
      final List<dynamic> players = gameData['players'] ?? [];

      // Extract player names to update the game model
      final playerNames = players
          .map<String>((player) => player['firstName'] as String)
          .toList();

      if (mounted) {
        setState(() {
          // Update game players list for UI
          _gamePlayers = players
              .map<Map<String, dynamic>>((p) => Map<String, dynamic>.from(p))
              .toList();

          // Update the game model with the new players if needed
          if (playerNames.isNotEmpty) {
            if (playerNames.length != _game.players.length) {
              // Players list changed - create a new game model
              _game = BowlingGameModel(
                roomCode: widget.gameCode,
                players: playerNames
                    .map((name) =>
                        BowlingPlayer(id: name, name: name, frames: []))
                    .toList(),
              );
              print('Updated game players: ${playerNames.join(", ")}');
            }

            // Update player frames from Firestore data
            _updatePlayerFramesFromFirestore(players);

            // Update current frame and current player information
            if (gameData.containsKey('currentFrame')) {
              _game.currentFrame = gameData['currentFrame'] ?? 1;
            }

            if (gameData.containsKey('currentPlayerIndex')) {
              _game.currentPlayerIndex = gameData['currentPlayerIndex'] ?? 0;
            }

            if (gameData.containsKey('currentThrow')) {
              _game.currentThrow = gameData['currentThrow'] ?? 1;
            }

            // Check if game is marked as completed
            final String gameStatus = gameData['status'] ?? 'waiting';
            if (gameStatus == 'completed' && widget.isAdmin) {
              // Alert the admin that the game is complete
              if (!_isGameComplete()) {
                // Only show this once when status changes to completed
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'This game has been marked as completed. No more throws can be recorded.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            }
          }
        });
      }
    });
  }

  void _updatePlayerFramesFromFirestore(List<dynamic> playersData) {
    // For each player in our game model
    for (final player in _game.players) {
      // Find matching player data in Firestore
      final playerData = playersData.firstWhere(
        (p) => p['firstName'] == player.name,
        orElse: () => {},
      );

      if (playerData.isNotEmpty) {
        // Get throwsPerFrame data
        final Map<String, dynamic> throwsPerFrame =
            Map<String, dynamic>.from(playerData['throwsPerFrame'] ?? {});

        // Clear existing frames data to ensure a fresh start
        player.frames.clear();

        // For each frame (1 to 10)
        for (int frameIndex = 1; frameIndex <= 10; frameIndex++) {
          final String frameKey = frameIndex.toString();
          final List<dynamic> frameThrows =
              List.from(throwsPerFrame[frameKey] ?? []);

          // Create a new bowling frame
          final frame = BowlingFrame(frameIndex: frameIndex - 1);

          // Set throw values if they exist
          if (frameThrows.isNotEmpty && frameThrows.length >= 1) {
            frame.firstThrow = frameThrows[0];
          }

          if (frameThrows.isNotEmpty && frameThrows.length >= 2) {
            frame.secondThrow = frameThrows[1];
          }

          if (frameThrows.isNotEmpty &&
              frameThrows.length >= 3 &&
              frameIndex == 10) {
            frame.thirdThrow = frameThrows[2];
          }

          // Add the frame to the player
          player.frames.add(frame);
        }
      }
    }

    // Calculate scores after updating frames
    _game._calculateScores();
  }

  @override
  Widget build(BuildContext context) {
    // Reset pin states when switching players
    // This ensures each player gets fresh pins at the start of their turn
    final currentPlayer = _game.getCurrentPlayer();
    if (currentPlayer != null && _lastPlayerIndex != _game.currentPlayerIndex) {
      if (_game.currentThrow == 1) {
        // Only reset pins when starting a new frame with first throw
        _resetPins();
      }
      _lastPlayerIndex = _game.currentPlayerIndex;
    }

    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog when user tries to exit
        final shouldPop = await _showExitConfirmation();
        return shouldPop;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.ringPrimary,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Game Room: ${widget.gameCode}'),
              Text(
                widget.isAdmin ? 'You are the scorekeeper' : 'View only mode',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showGameInfo(),
            ),
          ],
        ),
        body: Column(
          children: [
            // Display number of players joined
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Players joined: ${_game.players.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

            // Scoreboard section
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildScoreboard(),
                ),
              ),
            ),

            // Pin input section
            if (widget.isAdmin)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: _buildPinInputSection(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreboard() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Current frame and player info
            _buildGameInfo(),

            const SizedBox(height: 12),

            // Frame headers
            _buildFrameHeaders(),

            // Player rows
            ..._game.players.map((player) => _buildPlayerRow(player)),
          ],
        ),
      ),
    );
  }

  Widget _buildGameInfo() {
    final currentPlayer = _game.getCurrentPlayer();
    final currentFrame = _game.currentFrame;
    final throwNumber = _game.currentThrow;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Frame $currentFrame',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (currentPlayer != null)
                Text(
                  'Throw $throwNumber',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (currentPlayer != null)
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(top: 8),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  children: [
                    const TextSpan(text: 'Current Player: '),
                    TextSpan(
                      text: currentPlayer.name,
                      style: TextStyle(
                        color: AppColors.ringPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(top: 8),
              child: const Text(
                'Game Complete!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFrameHeaders() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          // Player column
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.ringPrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Player',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Frame numbers
          ...List.generate(10, (index) {
            final isCurrentFrame = index + 1 == _game.currentFrame;

            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isCurrentFrame
                      ? AppColors.ringSecondary
                      : AppColors.ringPrimary,
                  borderRadius: index == 9
                      ? const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        )
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(BowlingPlayer player) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          // Player name
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(color: Colors.grey[300]!),
            ),
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                player.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          // Frame cells
          ...List.generate(10, (frameIndex) {
            final bool isCurrentFrame =
                _game.currentPlayerIndex == _game.players.indexOf(player) &&
                    _game.currentFrame == frameIndex + 1;

            final bool hasFrame = frameIndex < player.frames.length;
            final frame = hasFrame ? player.frames[frameIndex] : null;

            final bool isSelected = _selectedPlayerId == player.id &&
                _selectedFrameIndex == frameIndex;

            return Expanded(
              child: GestureDetector(
                onTap: widget.isAdmin && hasFrame && frame!.isComplete
                    ? () => _selectFrameForEdit(player.id, frameIndex)
                    : null,
                child: Container(
                  height: 50,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.ringSecondary.withAlpha(77)
                        : (isCurrentFrame
                            ? AppColors.ringBackground3rd.withAlpha(51)
                            : Colors.white),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.ringSecondary
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: hasFrame ? _buildFrameCell(frame!, frameIndex) : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFrameCell(BowlingFrame frame, int frameIndex) {
    final bool isTenthFrame = frameIndex == 9;

    return Stack(
      children: [
        Column(
          children: [
            // Throws display area
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  // First throw display
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(color: Colors.grey[300]!),
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: frame.firstThrow != null
                          ? Text(
                              frame.firstThrow == 10
                                  ? 'X'
                                  : frame.firstThrow == 0
                                      ? '-'
                                      : frame.firstThrow.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                  ),

                  // Second throw display
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: frame.secondThrow != null
                          ? Text(
                              frame.secondThrow == 10
                                  ? 'X'
                                  : (frame.firstThrow != null &&
                                          frame.firstThrow! +
                                                  frame.secondThrow! ==
                                              10)
                                      ? '/'
                                      : frame.secondThrow == 0
                                          ? '-'
                                          : frame.secondThrow.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                  ),

                  // Third throw display (10th frame only)
                  if (isTenthFrame)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.grey[300]!),
                            bottom: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: frame.thirdThrow != null
                            ? Text(
                                frame.thirdThrow == 10
                                    ? 'X'
                                    : (frame.secondThrow != null &&
                                            frame.secondThrow! +
                                                    frame.thirdThrow! ==
                                                10)
                                        ? '/'
                                        : frame.thirdThrow == 0
                                            ? '-'
                                            : frame.thirdThrow.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),

            // Score display
            Expanded(
              flex: 2,
              child: Container(
                alignment: Alignment.center,
                color: Colors.grey[100],
                child: frame.isComplete
                    ? Text(
                        '${frame.score}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPinInputSection() {
    return Column(
      children: [
        // Pins knocked down count and remaining pins
        Column(
          children: [
            Text(
              'Pins Knocked Down: $_pinsDown',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_game.currentThrow == 2 && _remainingPins < 10)
              Text(
                'Remaining Pins: $_remainingPins',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _pinsDown > _remainingPins ? Colors.red : null,
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // Pin layout
        _buildPinLayout(),

        const SizedBox(height: 16),

        // Record throw button - disabled if too many pins selected
        ElevatedButton.icon(
          onPressed: (_pinsDown > 0 && _pinsDown <= _remainingPins)
              ? _submitThrow
              : null,
          icon: const Icon(Icons.check),
          label: const Text('Record Throw'),
          style: ElevatedButton.styleFrom(
            backgroundColor: (_pinsDown > 0 && _pinsDown <= _remainingPins)
                ? AppColors.ringPrimary
                : Colors.grey,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(45),
            elevation: 0,
            splashFactory: NoSplash.splashFactory,
            shadowColor: Colors.transparent,
          ),
        ),

        // Warning message if too many pins selected
        if (_pinsDown > _remainingPins)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Too many pins selected! Maximum: $_remainingPins',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // Cancel edit button (if editing a frame)
        if (_selectedFrameIndex != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton(
              onPressed: _cancelFrameEdit,
              child: const Text('Cancel Edit'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                splashFactory: NoSplash.splashFactory,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPinLayout() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Bowling Pins',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
              ),

              // Row 1 (pins 7-10)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPin(6),
                  _buildPin(7),
                  _buildPin(8),
                  _buildPin(9),
                ],
              ),

              // Row 2 (pins 4-6)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPin(3),
                  _buildPin(4),
                  _buildPin(5),
                ],
              ),

              // Row 3 (pins 2-3)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPin(1),
                  _buildPin(2),
                ],
              ),

              // Row 4 (pin 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPin(0),
                ],
              ),
            ],
          ),

          // Gutter button in corner
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: "Record a gutter ball (0 pins)",
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _recordGutterBall,
                  borderRadius: BorderRadius.circular(20),
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cancel_outlined, size: 18),
                        const SizedBox(width: 4),
                        const Text(
                          'Gutter',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPin(int index) {
    final bool alreadyKnocked = _previouslyKnockedPins[index];
    final bool canSelect = !alreadyKnocked;

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: GestureDetector(
        onTap: canSelect ? () => _togglePin(index) : null,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: alreadyKnocked
                ? Colors.grey[400]! // Gray for pins already knocked down
                : (_pinStates[index]
                    ? Colors.grey[400]!
                    : AppColors.ringPrimary),
            border: Border.all(
              color: alreadyKnocked || _pinStates[index]
                  ? Colors.grey[500]!
                  : AppColors.ringBackground3rd,
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: _pinStates[index] || alreadyKnocked
                    ? Colors.black
                    : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _togglePin(int index) {
    setState(() {
      // Check if toggling this pin would exceed remaining pins for second throw
      if (!_pinStates[index] &&
          _pinsDown >= _remainingPins &&
          _game.currentThrow == 2) {
        // Don't allow selection if already at max pins
        return;
      }

      _pinStates[index] = !_pinStates[index];
      _pinsDown = _pinStates.where((isDown) => isDown).length;
    });
  }

  void _resetPins() {
    setState(() {
      _pinStates = List.generate(10, (_) => false);
      _previouslyKnockedPins = List.generate(10, (_) => false);
      _pinsDown = 0;
      _remainingPins = 10;
    });
  }

  void _cancelFrameEdit() {
    setState(() {
      _selectedFrameIndex = null;
      _selectedPlayerId = null;
      _selectedEditThrow = 1;
      _resetPins();
    });
  }

  bool _isGameComplete() {
    // The game is complete when all players have finished all their frames
    for (final player in _game.players) {
      // Check if player has 10 frames
      if (player.frames.length < 10) {
        return false;
      }

      // Check if all frames are complete, especially the 10th frame
      final tenthFrame = player.frames[9];
      if (!tenthFrame.isComplete) {
        return false;
      }
    }

    // All players have completed all frames
    return true;
  }

  // Update the game status to 'completed' in Firestore
  Future<void> _markGameAsCompleted() async {
    if (!widget.isAdmin) return;

    try {
      // Find the game document with this room code
      final querySnapshot = await FirebaseFirestore.instance
          .collection('games')
          .where('roomId', isEqualTo: widget.gameCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('Error: Game document not found for roomId: ${widget.gameCode}');
        return;
      }

      final gameDoc = querySnapshot.docs.first;

      // Set status to 'completed'
      await gameDoc.reference.update({'status': 'completed'});
      print('Game marked as completed');
    } catch (e) {
      print('Error marking game as completed: $e');
    }
  }

  void _submitThrow() {
    // Check if the game is already complete
    if (_isGameComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game is complete. No more throws can be recorded.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedFrameIndex != null && _selectedPlayerId != null) {
      // Editing an existing frame
      _submitEditedFrame();
      return;
    }

    // Store current state before advancing
    final currentThrow = _game.currentThrow;
    final isFirstThrow = currentThrow == 1;
    final wasStrike = _pinsDown == 10;
    final currentPlayerIndex = _game.currentPlayerIndex;
    final currentPlayer = _game.getCurrentPlayer();
    final currentFrame = _game.currentFrame;
    final isTenthFrame = currentFrame == 10;

    // Check if this is a spare in the 10th frame
    bool isSpareInTenth = false;
    if (isTenthFrame && currentThrow == 2 && currentPlayer != null) {
      final firstThrow = currentPlayer.frames[9].firstThrow ?? 0;
      isSpareInTenth = (firstThrow < 10) && (firstThrow + _pinsDown == 10);
    }

    // Save which specific pins were knocked down
    List<bool> knockedPins = List.from(_pinStates);

    // Record the throw in the game
    _game.recordThrow(_pinsDown);

    // Update the throw in Firestore database
    _updateThrowInFirestore(
        currentPlayer, currentFrame, currentThrow, _pinsDown);

    if (isFirstThrow && !wasStrike) {
      // First throw that wasn't a strike - mark pins as knocked down for the second throw
      // of the SAME player
      setState(() {
        // Store which specific pins were knocked down
        _previouslyKnockedPins = knockedPins;

        // Reset current pin selection
        _pinStates = List.generate(10, (_) => false);
        _pinsDown = 0;

        // Track remaining pins for second throw
        _remainingPins =
            10 - _previouslyKnockedPins.where((knocked) => knocked).length;
      });
    } else if (isTenthFrame && currentThrow == 2) {
      // In 10th frame after second throw
      setState(() {
        // Store which specific pins were knocked down in second throw
        for (int i = 0; i < 10; i++) {
          if (_pinStates[i]) {
            _previouslyKnockedPins2[i] = true;
          }
        }

        // Reset current pin selection
        _pinStates = List.generate(10, (_) => false);
        _pinsDown = 0;

        // If the second throw was a strike OR if player just made a spare,
        // all pins should be reset (all 10 pins available)
        if (wasStrike || isSpareInTenth) {
          _previouslyKnockedPins = List.generate(10, (_) => false);
          _remainingPins = 10;
        } else {
          // Otherwise, combine pins knocked down in both throws
          for (int i = 0; i < 10; i++) {
            // If pin was knocked down in first or second throw, it's not available
            // Special case for 10th frame: if first throw was a strike, only consider second throw
            if (currentPlayer != null &&
                currentPlayer.frames[9].firstThrow == 10) {
              _previouslyKnockedPins[i] = _previouslyKnockedPins2[i];
            } else {
              _previouslyKnockedPins[i] =
                  _previouslyKnockedPins[i] || _previouslyKnockedPins2[i];
            }
          }

          // Calculate remaining pins
          _remainingPins =
              10 - _previouslyKnockedPins.where((knocked) => knocked).length;
        }
      });
    } else {
      // Always reset all pins when:
      // 1. After a strike
      // 2. After a second throw (except in 10th frame when not a spare/strike)
      // 3. After the third throw in 10th frame
      // 4. When moving to a new player
      setState(() {
        _pinStates = List.generate(10, (_) => false);
        _previouslyKnockedPins = List.generate(10, (_) => false);
        _previouslyKnockedPins2 = List.generate(10, (_) => false);
        _pinsDown = 0;
        _remainingPins = 10;
      });
    }

    // Check for 10th frame third throw specifically
    if (isTenthFrame && currentThrow == 3) {
      // After recording third throw, check if all players have finished
      if (_isGameComplete() && widget.isAdmin) {
        // Mark the game as completed in Firestore
        _markGameAsCompleted();

        // Show completion dialog
        Future.delayed(const Duration(milliseconds: 500), () {
          _showGameCompleteDialog();
        });
      }
    }
    // Regular check for game completion (when not in 10th frame)
    else if (_isGameComplete()) {
      // Mark the game as completed in Firestore
      _markGameAsCompleted();

      // Show completion dialog if game is finished
      if (widget.isAdmin) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _showGameCompleteDialog();
        });
      } else {
        // Show a message for non-admin players
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Game complete! All players have finished their frames.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    setState(() {});
  }

  void _submitEditedFrame() {
    // Check if the game is already complete
    if (_isGameComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game is complete. No more edits can be made.'),
          backgroundColor: Colors.orange,
        ),
      );
      _cancelFrameEdit();
      return;
    }

    if (_selectedFrameIndex == null || _selectedPlayerId == null) return;

    final frameIndex = _selectedFrameIndex!;
    final playerId = _selectedPlayerId!;

    // Find the player
    final player = _game.players
        .firstWhere((p) => p.id == playerId, orElse: () => _game.players[0]);

    // Ensure frame exists
    while (player.frames.length <= frameIndex) {
      player.frames.add(BowlingFrame(frameIndex: player.frames.length));
    }

    // Update frame based on current throw
    if (_selectedEditThrow == 1) {
      // For first throw, update and prepare for second throw
      player.frames[frameIndex].firstThrow = _pinsDown;

      // Update in Firestore
      _updateEditedFrameInFirestore(player, frameIndex + 1, 1, _pinsDown);

      // If strike in a normal frame, we're done
      if (_pinsDown == 10 && frameIndex < 9) {
        player.frames[frameIndex].secondThrow = null;
        player.frames[frameIndex].thirdThrow = null;
        _completeFrameEdit();
      } else {
        // Setup for second throw
        _setupForSecondThrow();
      }
    } else if (_selectedEditThrow == 2) {
      // For second throw, update and finish (except 10th frame)
      player.frames[frameIndex].secondThrow = _pinsDown;

      // Update in Firestore
      _updateEditedFrameInFirestore(player, frameIndex + 1, 2, _pinsDown);

      // In 10th frame with strike or spare, setup for third throw
      if (frameIndex == 9 &&
          (player.frames[frameIndex].firstThrow == 10 ||
              player.frames[frameIndex].firstThrow! + _pinsDown == 10)) {
        _setupForThirdThrow();
      } else {
        // Done with frame
        player.frames[frameIndex].thirdThrow = null;
        _completeFrameEdit();
      }
    } else if (_selectedEditThrow == 3 && frameIndex == 9) {
      // For third throw in 10th frame, validate pins if needed
      final firstThrow = player.frames[frameIndex].firstThrow ?? 0;
      final secondThrow = player.frames[frameIndex].secondThrow ?? 0;

      // If both first and second throws weren't strikes, validate the pin count
      if (secondThrow != 10 && firstThrow != 10) {
        // Calculate how many pins should remain
        int remainingPins = 10 -
            (firstThrow == 10 ? 0 : firstThrow) -
            (secondThrow == 10 ? 0 : secondThrow);

        // If we're trying to knock down more pins than are standing
        if (_pinsDown > remainingPins) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Invalid throw: Cannot knock down more pins than are standing'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
      }

      // For third throw in 10th frame, update and finish
      player.frames[frameIndex].thirdThrow = _pinsDown;

      // Update in Firestore
      _updateEditedFrameInFirestore(player, frameIndex + 1, 3, _pinsDown);

      _completeFrameEdit();
    }

    // Recalculate scores
    _game._calculateScores();

    // Check if game is complete after this edit
    if (_isGameComplete() && widget.isAdmin) {
      // Mark the game as completed in Firestore
      _markGameAsCompleted();

      // Show completion dialog
      Future.delayed(const Duration(milliseconds: 500), () {
        _showGameCompleteDialog();
      });
    }
  }

  // Method to update throw in Firestore
  Future<void> _updateThrowInFirestore(BowlingPlayer? player, int frameNumber,
      int throwNumber, int pinsDown) async {
    if (player == null || !widget.isAdmin) return;

    try {
      // Find the game document with this roomId
      final querySnapshot = await FirebaseFirestore.instance
          .collection('games')
          .where('roomId', isEqualTo: widget.gameCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('Error: Game document not found for roomId: ${widget.gameCode}');
        return;
      }

      final gameDoc = querySnapshot.docs.first;
      final gameData = gameDoc.data();

      // Get the players array from the game document
      final List<dynamic> players = List.from(gameData['players'] ?? []);

      // Find the player in the array
      int playerIndex = -1;
      for (int i = 0; i < players.length; i++) {
        if (players[i]['firstName'] == player.name) {
          playerIndex = i;
          break;
        }
      }

      if (playerIndex == -1) {
        print('Error: Player ${player.name} not found in the game document');
        return;
      }

      // Update the throw in the player's throwsPerFrame
      final Map<String, dynamic> throwsPerFrame =
          Map<String, dynamic>.from(players[playerIndex]['throwsPerFrame']);

      // Frame key is 1-based index as string
      final String frameKey = frameNumber.toString();

      // Get current throws for this frame
      List<dynamic> frameThrows = List.from(throwsPerFrame[frameKey] ?? []);

      // Update or add the throw
      if (throwNumber <= frameThrows.length) {
        frameThrows[throwNumber - 1] = pinsDown;
      } else {
        // Add throw
        while (frameThrows.length < throwNumber - 1) {
          frameThrows.add(0); // Pad with 0s if needed
        }
        frameThrows.add(pinsDown);
      }

      // Update throwsPerFrame
      throwsPerFrame[frameKey] = frameThrows;
      players[playerIndex]['throwsPerFrame'] = throwsPerFrame;

      // Calculate scores using model methods
      for (var i = 0; i < players.length; i++) {
        final currentPlayer = BowlingPlayer(
          id: players[i]['userId'] ?? players[i]['firstName'],
          name: players[i]['firstName'],
          frames: [],
        );

        // Convert throwsPerFrame to BowlingFrame objects
        final Map<String, dynamic> playerThrows =
            Map<String, dynamic>.from(players[i]['throwsPerFrame'] ?? {});

        for (int frameIndex = 1; frameIndex <= 10; frameIndex++) {
          final String fKey = frameIndex.toString();
          final List<dynamic> fThrows = List.from(playerThrows[fKey] ?? []);

          final frame = BowlingFrame(frameIndex: frameIndex - 1);
          if (fThrows.isNotEmpty && fThrows.length >= 1) {
            frame.firstThrow = fThrows[0];
          }
          if (fThrows.isNotEmpty && fThrows.length >= 2) {
            frame.secondThrow = fThrows[1];
          }
          if (fThrows.isNotEmpty && fThrows.length >= 3 && frameIndex == 10) {
            frame.thirdThrow = fThrows[2];
          }

          currentPlayer.frames.add(frame);
        }

        // Calculate scores for this player
        _calculateScoresForPlayer(currentPlayer);

        // Update totalScore in the Firestore data
        if (player.frames.isNotEmpty) {
          final lastFrameWithScore =
              player.frames.lastWhere((frame) => frame.score > 0, orElse: () {
            return BowlingFrame(frameIndex: 0);
          });

          players[playerIndex]['totalScore'] = lastFrameWithScore.score;
        }
      }

      // Ensure currentFrame never exceeds 10
      int updatedCurrentFrame = _game.currentFrame;
      if (updatedCurrentFrame > 10) {
        updatedCurrentFrame = 10;
      }

      // Create the updated game data with current game state
      final Map<String, dynamic> updatedGameData = {
        'players': players,
        'currentFrame': updatedCurrentFrame,
        'currentPlayerIndex': _game.currentPlayerIndex >= _game.players.length
            ? 0
            : _game.currentPlayerIndex,
        'currentThrow': _game.currentThrow,
      };

      // Update the game document in Firestore
      await gameDoc.reference.update(updatedGameData);

      print(
          'Successfully updated ${player.name}\'s throw in frame $frameNumber');
    } catch (e) {
      print('Error updating throw in Firestore: $e');
    }
  }

  // Method to update edited frame in Firestore
  Future<BowlingFrame> _updateEditedFrameInFirestore(BowlingPlayer player,
      int frameNumber, int throwNumber, int pinsDown) async {
    if (!widget.isAdmin) {
      return player.frames[frameNumber - 1];
    }

    try {
      // Get the game document
      final querySnapshot = await FirebaseFirestore.instance
          .collection('bowlingGames')
          .where('roomId', isEqualTo: widget.gameCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('Error: Game document not found for roomId: ${widget.gameCode}');
        return player.frames[frameNumber - 1];
      }

      final gameDoc = querySnapshot.docs.first;

      // Get the current players array from the document
      final data = gameDoc.data();
      final List<dynamic> players = List.from(data['players']);

      // Find the player
      final playerIndex = players.indexWhere((p) => p['id'] == player.id);
      if (playerIndex == -1) {
        print('Error: Player not found');
        return player.frames[frameNumber - 1];
      }

      // Update this throw in the player's frames data
      if (players[playerIndex]['frames'] == null) {
        players[playerIndex]['frames'] = [];
      }

      // Ensure the frame exists
      while (players[playerIndex]['frames'].length < frameNumber) {
        players[playerIndex]['frames'].add({
          'frameIndex': players[playerIndex]['frames'].length,
          'firstThrow': null,
          'secondThrow': null,
          'thirdThrow': null,
        });
      }

      // Get the frame
      final frameIndex = frameNumber - 1;
      final frame = players[playerIndex]['frames'][frameIndex];

      // Update the appropriate throw
      if (throwNumber == 1) {
        frame['firstThrow'] = pinsDown;
      } else if (throwNumber == 2) {
        frame['secondThrow'] = pinsDown;
      } else if (throwNumber == 3) {
        frame['thirdThrow'] = pinsDown;
      }

      // Recalculate scores for the entire game
      for (var i = 0; i < players.length; i++) {
        final currentPlayer = BowlingPlayer(
          id: players[i]['id'],
          name: players[i]['name'],
          frames: [],
        );

        // Convert frames from map to BowlingFrame objects
        for (var frameData in players[i]['frames']) {
          final frame = BowlingFrame(frameIndex: frameData['frameIndex']);
          frame.firstThrow = frameData['firstThrow'];
          frame.secondThrow = frameData['secondThrow'];
          frame.thirdThrow = frameData['thirdThrow'];
          currentPlayer.frames.add(frame);
        }

        // Calculate scores
        _calculateScoresForPlayer(currentPlayer);

        // Update the frame scores back to the Firestore data
        for (var j = 0; j < currentPlayer.frames.length; j++) {
          players[i]['frames'][j]['score'] = currentPlayer.frames[j].score;
        }

        // Get the highest frame that has a score
        final lastFrameWithScore = currentPlayer.frames
            .lastWhere((frame) => frame.score > 0, orElse: () {
          return BowlingFrame(frameIndex: 0);
        });

        players[i]['totalScore'] = lastFrameWithScore.score;
      }

      // Create the updated game data
      final Map<String, dynamic> updatedGameData = {
        'players': players,
      };

      // Update the game document in Firestore
      await gameDoc.reference.update(updatedGameData);

      print(
          'Successfully updated ${player.name}\'s frame $frameNumber, throw $throwNumber');
      return player.frames[frameNumber - 1];
    } catch (e) {
      print('Error updating edited frame in Firestore: $e');
      return player.frames[frameNumber - 1];
    }
  }

  // Calculate scores for a player - similar to the game model's _calculateScores method
  void _calculateScoresForPlayer(BowlingPlayer player) {
    int totalScore = 0;

    for (int i = 0; i < player.frames.length; i++) {
      final frame = player.frames[i];
      frame.score = 0;

      // Basic score for this frame
      int frameScore = 0;

      // First throw
      if (frame.firstThrow != null) {
        frameScore += frame.firstThrow!;
      }

      // Second throw
      if (frame.secondThrow != null) {
        frameScore += frame.secondThrow!;
      }

      // Third throw (10th frame only)
      if (i == 9 && frame.thirdThrow != null) {
        frameScore += frame.thirdThrow!;
      }

      // Add strike/spare bonuses for frames 1-9
      if (i < 9) {
        // Strike bonus - next two throws
        if (frame.isStrike) {
          // Get next throw
          int? nextThrow = _getNextThrow(player, i);
          if (nextThrow != null) frameScore += nextThrow;

          // Get second next throw
          int? secondNextThrow = _getSecondNextThrow(player, i);
          if (secondNextThrow != null) frameScore += secondNextThrow;
        }
        // Spare bonus - next throw
        else if (frame.isSpare) {
          int? nextThrow = _getNextThrow(player, i);
          if (nextThrow != null) frameScore += nextThrow;
        }
      }

      // Add frame score to total
      totalScore += frameScore;
      frame.score = totalScore;
    }
  }

  // Get the next throw after a given frame
  int? _getNextThrow(BowlingPlayer player, int frameIndex) {
    // Next frame exists
    if (frameIndex + 1 < player.frames.length) {
      final nextFrame = player.frames[frameIndex + 1];

      // Return first throw of next frame
      return nextFrame.firstThrow;
    }

    return null;
  }

  // Get the second next throw after a given frame
  int? _getSecondNextThrow(BowlingPlayer player, int frameIndex) {
    // If the next frame is a strike, we need to look at the frame after that
    if (frameIndex + 1 < player.frames.length) {
      final nextFrame = player.frames[frameIndex + 1];

      if (nextFrame.isStrike) {
        // If next frame is a strike, look at first throw of the frame after
        if (frameIndex + 2 < player.frames.length) {
          return player.frames[frameIndex + 2].firstThrow;
        }
      } else {
        // Otherwise, return second throw of next frame
        return nextFrame.secondThrow;
      }
    }

    return null;
  }

  void _setupForSecondThrow() {
    // Save pins that were knocked down in first throw
    setState(() {
      // Store which specific pins were knocked down
      for (int i = 0; i < 10; i++) {
        _previouslyKnockedPins[i] = _pinStates[i];
      }

      // Reset current selection
      _pinStates = List.generate(10, (_) => false);
      _pinsDown = 0;
      _selectedEditThrow = 2;
    });
  }

  void _setupForThirdThrow() {
    // Save pins that were knocked down in second throw
    setState(() {
      // Store which specific pins were knocked down in second throw
      for (int i = 0; i < 10; i++) {
        if (_pinStates[i]) {
          _previouslyKnockedPins2[i] = true;
        }
      }

      // Reset current selection
      _pinStates = List.generate(10, (_) => false);
      _pinsDown = 0;
      _selectedEditThrow = 3;

      // Calculate remaining pins for the third throw
      if (_selectedEditPlayer != null && _selectedEditFrame != null) {
        final frame = _selectedEditPlayer!.frames[_selectedEditFrame! - 1];
        final firstThrow = frame.firstThrow ?? 0;
        final secondThrow = frame.secondThrow ?? 0;

        // For the 10th frame:
        // 1. If first throw was a strike, the second throw resets all pins
        // 2. If second throw was a strike, reset all pins for third throw
        // 3. If first+second is a spare (sum to 10), reset all pins for third throw

        // Case: after a spare or if second throw was a strike
        if (secondThrow == 10 ||
            (firstThrow != 10 && firstThrow + secondThrow == 10)) {
          // Reset all pins for third throw
          _previouslyKnockedPins = List.generate(10, (_) => false);
          _remainingPins = 10;
        }
        // Case: second throw wasn't a strike and player didn't make a spare
        else if (secondThrow != 10) {
          // If first throw was a strike, only consider pins from second throw
          if (firstThrow == 10) {
            _previouslyKnockedPins = List.from(_previouslyKnockedPins2);
          } else {
            // Otherwise combine pins from both throws
            for (int i = 0; i < 10; i++) {
              _previouslyKnockedPins[i] =
                  _previouslyKnockedPins[i] || _previouslyKnockedPins2[i];
            }
          }

          // Calculate remaining pins for the third throw
          _remainingPins =
              10 - _previouslyKnockedPins.where((knocked) => knocked).length;
        }
      }
    });
  }

  void _completeFrameEdit() async {
    if (_selectedEditFrame == null || _selectedEditPlayer == null) {
      return;
    }

    final frameNumber = _selectedEditFrame!;
    final player = _selectedEditPlayer!;

    // Get the current frame
    final frame = player.frames[frameNumber - 1];

    // Updating first throw
    if (_selectedEditThrow == 1) {
      final pinsDown = _pinsDown;

      // Update in memory
      setState(() {
        frame.firstThrow = pinsDown;

        // If strike, clear second throw (except in 10th frame)
        if (pinsDown == 10 && frameNumber < 10) {
          frame.secondThrow = 0;
        }
      });

      // Update in Firestore
      await _updateEditedFrameInFirestore(player, frameNumber, 1, pinsDown);

      // If strike and not 10th frame, we're done
      if (pinsDown == 10 && frameNumber < 10) {
        _exitEditMode();
      } else {
        // Otherwise, set up for second throw
        _setupForSecondThrow();
      }
    }
    // Updating second throw
    else if (_selectedEditThrow == 2) {
      final pinsDown = _pinsDown;

      // Validate second throw (can't knock down more pins than are standing)
      final firstThrow = frame.firstThrow ?? 0;
      if (firstThrow < 10 && firstThrow + pinsDown > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Invalid throw: Cannot knock down more than 10 pins total'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Update in memory
      setState(() {
        frame.secondThrow = pinsDown;
      });

      // Update in Firestore
      await _updateEditedFrameInFirestore(player, frameNumber, 2, pinsDown);

      // If 10th frame and strike/spare, set up for third throw
      if (frameNumber == 10 &&
          (firstThrow == 10 || firstThrow + pinsDown == 10)) {
        _setupForThirdThrow();
      } else {
        _exitEditMode();
      }
    }
    // Updating third throw (10th frame only)
    else if (_selectedEditThrow == 3) {
      final pinsDown = _pinsDown;

      // Validate third throw
      final secondThrow = frame.secondThrow ?? 0;
      if (frame.firstThrow == 10 &&
          secondThrow < 10 &&
          secondThrow + pinsDown > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Invalid throw: Cannot knock down more than 10 pins total'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Update in memory
      setState(() {
        frame.thirdThrow = pinsDown;
      });

      // Update in Firestore
      await _updateEditedFrameInFirestore(player, frameNumber, 3, pinsDown);

      _exitEditMode();
    }
  }

  void _exitEditMode() {
    setState(() {
      _selectedFrameIndex = null;
      _selectedPlayerId = null;
      _selectedEditThrow = 1;
      _pinStates = List.generate(10, (_) => false);
      _previouslyKnockedPins = List.generate(10, (_) => false);
      _previouslyKnockedPins2 = List.generate(10, (_) => false);
      _pinsDown = 0;
    });
  }

  void _selectFrameForEdit(String playerId, int frameIndex) {
    // Reset for first throw
    setState(() {
      _selectedPlayerId = playerId;
      _selectedFrameIndex = frameIndex;
      _selectedEditThrow = 1;
      _resetPins();
    });
  }

  void _showGameCompleteDialog() {
    // Create a controller for the location input
    final TextEditingController locationController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.emoji_events,
                  color: AppColors.ringSecondary, size: 28),
              const SizedBox(width: 10),
              const Text('Game Complete!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('All players have completed their frames.'),
              const SizedBox(height: 20),
              // Show final scores
              ..._game.players.map((player) {
                final score =
                    player.frames.isNotEmpty ? player.frames.last.score : 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(player.name),
                      Text(
                        '$score',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              // Location input field
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  hintText: 'e.g. Bowling Alley Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                splashFactory: NoSplash.splashFactory,
              ),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      // Show loading state
                      setState(() {
                        isSaving = true;
                      });

                      // Save the game
                      try {
                        await _saveGameToFirestore(
                          locationController.text,
                          dialogContext,
                        );
                      } finally {
                        // Ensure we reset state even on error
                        if (mounted) {
                          setState(() {
                            isSaving = false;
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ringPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                splashFactory: NoSplash.splashFactory,
                shadowColor: Colors.transparent,
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                  : const Text('Save Game'),
            ),
          ],
        ),
      ),
    );
  }

  // Save game data to Firestore
  Future<void> _saveGameToFirestore(
      String location, BuildContext dialogContext) async {
    try {
      // Prepare game data for Firestore
      final FirestoreService firestoreService = FirestoreService();
      final UserService userService = UserService();

      // Get user data
      final userData = await userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        throw Exception('Unable to save game: User data not available');
      }

      // Format players data for Firestore
      final List<Map<String, dynamic>> playersData =
          _game.players.map((player) {
        // Determine if this is the current user
        final bool isCurrentUser = player.name == firstName;

        // For better data structure, convert frames to a map
        final Map<String, List<int>> throwsPerFrame = {};
        for (int i = 1; i <= player.frames.length; i++) {
          final frame = player.frames[i - 1];
          throwsPerFrame[i.toString()] = [
            frame.firstThrow ?? 0,
            frame.secondThrow ?? 0,
            if (i == 10 && frame.thirdThrow != null) frame.thirdThrow!,
          ];
        }

        return {
          'userId': isCurrentUser
              ? deRingID
              : 'Guest-${DateTime.now().millisecondsSinceEpoch}',
          'firstName': player.name,
          'totalScore': player.frames.isNotEmpty ? player.frames.last.score : 0,
          'throwsPerFrame': throwsPerFrame,
        };
      }).toList();

      // Save game to Firestore
      final gameId = await firestoreService.saveGame(
        // Use "Bowling DeRing" as default if no location provided
        location: location.isNotEmpty ? location : 'Bowling DeRing',
        players: playersData,
        date: DateTime.now(),
      );

      if (gameId == null) {
        throw Exception('Failed to save game');
      }

      // Delete the original live game document once it's saved
      await _deleteLiveGameDocument();

      // Close dialog
      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.of(dialogContext).pop();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Game saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving game: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to delete the live game document from Firestore
  Future<void> _deleteLiveGameDocument() async {
    try {
      // Find the game document with this room code
      final querySnapshot = await FirebaseFirestore.instance
          .collection('games')
          .where('roomId', isEqualTo: widget.gameCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print(
            'No live game document found to delete for roomId: ${widget.gameCode}');
        return;
      }

      final gameDoc = querySnapshot.docs.first;

      // Delete the document
      await gameDoc.reference.delete();
      print(
          'Successfully deleted live game document for roomId: ${widget.gameCode}');
    } catch (e) {
      print('Error deleting live game document: $e');
    }
  }

  void _showGameInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Game Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room Code: ${widget.gameCode}'),
            const SizedBox(height: 8),
            Text('Players: ${widget.players.join(", ")}'),
            const SizedBox(height: 16),
            const Text(
              'Pin input functionality is under development and will be implemented soon.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
              splashFactory: NoSplash.splashFactory,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Add method for gutter ball
  void _recordGutterBall() {
    // Clear any selected pins
    setState(() {
      _pinStates = List.generate(10, (_) => false);
      _pinsDown = 0;
    });

    // Submit a throw with 0 pins
    _submitThrow();
  }

  Future<bool> _showExitConfirmation() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Game?'),
            content: widget.isAdmin
                ? const Text(
                    'If you exit this screen as the room owner, the game will end for all players. Make sure you have saved the game before exiting if you want to keep the scores.')
                : const Text(
                    'If you exit this screen, you won\'t be able to contribute further to this game and following frames will be counted as not thrown.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  splashFactory: NoSplash.splashFactory,
                ),
                child: const Text('Stay'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ringPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  splashFactory: NoSplash.splashFactory,
                  shadowColor: Colors.transparent,
                ),
                child: widget.isAdmin
                    ? const Text('Exit & End Game')
                    : const Text('Leave Game'),
              ),
            ],
          ),
        ) ??
        false; // Default to false (don't exit) if dialog is dismissed

    if (confirmed) {
      // If admin/room owner is leaving, delete the game document
      if (widget.isAdmin) {
        try {
          // Check if the game is complete first
          final isComplete = _isGameComplete();

          // If game is complete, delete the live document as we assume it's already been saved
          if (isComplete) {
            await _deleteLiveGameDocument();
          } else {
            // If game isn't complete, show a warning dialog
            final shouldDeleteGame = await _showUnsavedGameWarning();
            if (shouldDeleteGame) {
              await _deleteLiveGameDocument();
            }
          }
        } catch (e) {
          print('Error cleaning up game document: $e');
        }
      }
      // If regular player is leaving, just remove them
      else if (!widget.isAdmin) {
        try {
          await _firestoreService.removePlayerFromGame(widget.gameCode);
        } catch (e) {
          print('Error removing player from game: $e');
        }
      }
    }

    return confirmed;
  }

  // Warning dialog shown when admin tries to exit an incomplete game
  Future<bool> _showUnsavedGameWarning() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Game Not Complete'),
            content: const Text(
                'This game is not complete yet. If you exit now without saving, all game progress will be lost. Do you want to continue and delete the game?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black,
                  splashFactory: NoSplash.splashFactory,
                ),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  splashFactory: NoSplash.splashFactory,
                  shadowColor: Colors.transparent,
                ),
                child: const Text('Delete Game'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
