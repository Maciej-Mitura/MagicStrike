import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';

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
        // If strike in first throw or spare, get one more throw
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
      currentFrame++;

      // Check if game is complete
      if (currentFrame > 10) {
        // Game complete
        currentFrame = 10;
        currentPlayerIndex = players.length; // Set to invalid index
      }
    }
  }

  void _calculateScores() {
    for (final player in players) {
      int totalScore = 0;

      for (int i = 0; i < player.frames.length; i++) {
        final frame = player.frames[i];
        int frameScore = 0;

        // Add base points from this frame
        if (frame.firstThrow != null) {
          frameScore += frame.firstThrow!;
        }
        if (frame.secondThrow != null) {
          frameScore += frame.secondThrow!;
        }

        // In 10th frame, add third throw if it exists
        if (i == 9 && frame.thirdThrow != null) {
          frameScore += frame.thirdThrow!;
        }

        // Add bonus points for strikes and spares (except in 10th frame)
        if (i < 9) {
          // Strike bonus: next two rolls
          if (frame.isStrike) {
            // Look ahead for next two rolls
            int bonusPinsFound = 0;
            int bonusPoints = 0;

            // Look in next frame(s)
            for (int j = i + 1;
                j < player.frames.length && bonusPinsFound < 2;
                j++) {
              final nextFrame = player.frames[j];

              // First throw
              if (nextFrame.firstThrow != null && bonusPinsFound < 2) {
                bonusPoints += nextFrame.firstThrow!;
                bonusPinsFound++;

                // If strike and need one more bonus, continue to next frame
                if (nextFrame.firstThrow == 10 && bonusPinsFound < 2 && j < 9) {
                  continue;
                }
              }

              // Second throw (if needed)
              if (nextFrame.secondThrow != null && bonusPinsFound < 2) {
                bonusPoints += nextFrame.secondThrow!;
                bonusPinsFound++;
              }

              // Third throw in 10th frame (if needed)
              if (j == 9 &&
                  nextFrame.thirdThrow != null &&
                  bonusPinsFound < 2) {
                bonusPoints += nextFrame.thirdThrow!;
                bonusPinsFound++;
              }
            }

            frameScore += bonusPoints;
          }
          // Spare bonus: next roll
          else if (frame.isSpare) {
            // Look ahead for next roll
            for (int j = i + 1; j < player.frames.length; j++) {
              final nextFrame = player.frames[j];
              if (nextFrame.firstThrow != null) {
                frameScore += nextFrame.firstThrow!;
                break;
              }
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

  // For tracking pins in current throw
  List<bool> _pinStates = List.generate(10, (_) => false);
  List<bool> _previouslyKnockedPins = List.generate(10, (_) => false);
  int _pinsDown = 0;
  int _remainingPins = 10; // Track how many pins are remaining

  // For editing frames
  int? _selectedFrameIndex;
  String? _selectedPlayerId;

  // Add this variable to track the last player index
  int _lastPlayerIndex = -1;

  @override
  void initState() {
    super.initState();

    // Initialize game with players
    _game = BowlingGameModel(
      roomCode: widget.gameCode,
      players: widget.players
          .map((name) => BowlingPlayer(id: name, name: name, frames: []))
          .toList(),
    );
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

    return Scaffold(
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
              child: Text(
                'Current Player: ${currentPlayer.name}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ringPrimary,
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
              child: InkWell(
                onTap: _recordGutterBall,
                borderRadius: BorderRadius.circular(20),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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
                  : AppColors.ringPrimary.withOpacity(0.7),
              width: 1.0,
            ),
            boxShadow: _pinStates[index] || alreadyKnocked
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(25),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
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
      _resetPins();
    });
  }

  void _submitThrow() {
    if (_selectedFrameIndex != null && _selectedPlayerId != null) {
      // Editing an existing frame
      _submitEditedFrame();
      return;
    }

    // Store current state before advancing
    final currentThrow = _game.currentThrow;
    final isFirstThrow = currentThrow == 1;
    final wasStrike = _pinsDown == 10;

    // Save which specific pins were knocked down
    List<bool> knockedPins = List.from(_pinStates);

    // Record the throw in the game
    _game.recordThrow(_pinsDown);

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
    } else {
      // Always reset all pins when:
      // 1. After a strike
      // 2. After a second throw
      // 3. For bonus throws in 10th frame
      // 4. When moving to a new player
      setState(() {
        _pinStates = List.generate(10, (_) => false);
        _previouslyKnockedPins = List.generate(10, (_) => false);
        _pinsDown = 0;
        _remainingPins = 10;
      });
    }

    // Check if game is complete
    final isGameComplete = _game.currentPlayerIndex >= _game.players.length;

    // Show completion dialog if game is finished
    if (isGameComplete && widget.isAdmin) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _showGameCompleteDialog();
      });
    }

    setState(() {});
  }

  void _submitEditedFrame() {
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
      // For third throw in 10th frame, update and finish
      player.frames[frameIndex].thirdThrow = _pinsDown;
      _completeFrameEdit();
    }

    // Recalculate scores
    _game._calculateScores();
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

      // Calculate remaining pins for second throw
      _remainingPins =
          10 - _previouslyKnockedPins.where((knocked) => knocked).length;
    });
  }

  void _setupForThirdThrow() {
    // Reset all pins for third throw in 10th frame
    setState(() {
      _pinStates = List.generate(10, (_) => false);
      _previouslyKnockedPins = List.generate(10, (_) => false);
      _pinsDown = 0;
      _selectedEditThrow = 3;
      _remainingPins = 10; // Reset to 10 pins for bonus throw
    });
  }

  void _completeFrameEdit() {
    // Clear selection and reset pins
    setState(() {
      _selectedFrameIndex = null;
      _selectedPlayerId = null;
      _selectedEditThrow = 1;
      _resetPins();
    });
  }

  // For editing frames
  int _selectedEditThrow = 1;

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: AppColors.ringSecondary, size: 28),
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
}
