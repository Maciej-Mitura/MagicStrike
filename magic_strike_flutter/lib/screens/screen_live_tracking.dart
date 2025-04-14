import 'dart:async';
import 'package:flutter/material.dart';

import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/models/game_model.dart';
import 'package:magic_strike_flutter/services/game_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => LiveTrackingScreenState();
}

class LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final TextEditingController _gameIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final GameService _gameService = GameService();

  // Add a constant viewerId for development/testing
  // This will be replaced with a backend-provided ID in the future
  final String _viewerId = 'test-viewer-123';

  // Stream subscription for game updates
  StreamSubscription<LiveGame>? _gameSubscription;

  // Current game state
  LiveGame? _game;

  // Loading state
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    // Clean up controller and subscription
    _gameIdController.dispose();
    _leaveGame();
    super.dispose();
  }

  // Join a live game
  void _joinGame(String gameId) {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Leave previous game if any
      _leaveGame();

      // Add a shorter delay only for simulation purposes
      // We'll check if it's a completed game (STRIKE456) to provide immediate feedback
      if (gameId == 'STRIKE456') {
        // Perfect game is already complete, connect faster
        _connectToGame(gameId);
      } else {
        // For other demo games, use a shorter delay
        Future.delayed(const Duration(milliseconds: 150), () {
          _connectToGame(gameId);
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Helper method to connect to a game
  void _connectToGame(String gameId) {
    try {
      // Join the new game with error handling for the type cast issue
      _gameSubscription = _gameService.joinGame(gameId, _viewerId).listen(
        (game) {
          setState(() {
            _game = game;
            _isLoading = false;
          });
        },
        onError: (error) {
          setState(() {
            _error = "Error joining game: ${error.toString()}";
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = "Failed to join game: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  // Leave the current game
  void _leaveGame() {
    if (_game != null) {
      _gameService.leaveGame(_game!.id, _viewerId);
    }

    _gameSubscription?.cancel();
    _gameSubscription = null;

    setState(() {
      _game = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Live Tracking'),
        centerTitle: true,
      ),
      body: _game == null ? _buildGameIdForm() : _buildLiveGame(),
    );
  }

  Widget _buildGameIdForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Enter Game ID to track live',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _gameIdController,
                decoration: InputDecoration(
                  labelText: 'Game ID',
                  // Only use color when focused
                  labelStyle: const TextStyle(color: Colors.grey),
                  floatingLabelStyle: WidgetStateTextStyle.resolveWith(
                    (Set<WidgetState> states) {
                      if (states.contains(WidgetState.focused)) {
                        return TextStyle(color: AppColors.ringPrimary);
                      }
                      return const TextStyle(color: Colors.grey);
                    },
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    borderSide:
                        BorderSide(color: AppColors.ringPrimary, width: 2),
                  ),
                ),
                cursorColor: AppColors.ringPrimary,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a Game ID';
                  }

                  // Check if it's one of our demo game IDs
                  if (value != 'BOWL123' &&
                      value != 'STRIKE456' &&
                      value != 'GAME789') {
                    return 'Invalid Game ID. Try BOWL123, STRIKE456, or GAME789';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          _joinGame(_gameIdController.text);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ringPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0, // No drop shadow
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(
                      double.infinity, 50), // Full width button with height 50
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Track Game',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveGame() {
    if (_game == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildGameHeader(),
        _buildCurrentFrame(),
        Expanded(
          child: _buildScoreboard(),
        ),
      ],
    );
  }

  Widget _buildGameHeader() {
    // Check if the game is complete (all players have finished all 10 frames)
    bool isGameComplete = true;
    if (_game != null) {
      for (final player in _game!.players) {
        if (player.frames.length < 10 || !player.frames[9].isComplete) {
          isGameComplete = false;
          break;
        }
      }

      // Update game status if complete but not marked as completed
      if (isGameComplete && _game!.status != 'completed') {
        _game!.status = 'completed';
      }
    }

    // Add a border bottom for visual separation
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Game ID: ${_game!.id}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Status: ',
                    style: const TextStyle(
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    _game!.status,
                    style: TextStyle(
                      color: _game!.status == 'completed'
                          ? Colors.green
                          : Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.people, color: AppColors.ringPrimary),
              const SizedBox(width: 4),
              Text(
                '${_game!.viewerCount}',
                style: TextStyle(
                  color: AppColors.ringPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentFrame() {
    // Add a border bottom for visual separation
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.bowlingBall, size: 24, color: Colors.black),
          const SizedBox(width: 8),
          Text(
            'Current Frame: ${_game!.currentFrame}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Live Scoreboard',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                // Allocate column widths for player names, frames, and total score
                final nameColumnWidth = availableWidth * 0.15;
                final framesWidth = availableWidth * 0.80;
                final totColumnWidth = availableWidth * 0.05;
                // Calculate frame width
                final frameWidth = (framesWidth / 10) - 1;
                final frameHeight = frameWidth * 0.9;

                return Column(
                  children: [
                    // Frame numbers header
                    Row(
                      children: [
                        // Empty space above player names
                        SizedBox(width: nameColumnWidth),
                        // Frame numbers
                        SizedBox(
                          width: framesWidth,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(10, (frameIndex) {
                              return SizedBox(
                                width: frameWidth,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _game!.currentFrame == frameIndex + 1
                                        ? AppColors.ringSecondary
                                        : AppColors.ringPrimary,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(3),
                                      topRight: Radius.circular(3),
                                    ),
                                  ),
                                  child: Text(
                                    '${frameIndex + 1}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        // Total score header
                        Container(
                          width: totColumnWidth,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: const BoxDecoration(
                            color: AppColors.ringPrimary,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(3),
                              topRight: Radius.circular(3),
                            ),
                          ),
                          child: const Text(
                            'T',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Player rows with frames
                    Expanded(
                      child: ListView.builder(
                        itemCount: _game!.players.length,
                        itemBuilder: (context, playerIndex) {
                          final player = _game!.players[playerIndex];

                          // Display shortened name if too long
                          final displayName = player.name.length > 5
                              ? '${player.name.substring(0, 4)}.'
                              : player.name;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1.0),
                            child: Row(
                              children: [
                                // Player name column
                                SizedBox(
                                  width: nameColumnWidth,
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Player frames
                                SizedBox(
                                  width: framesWidth,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(10, (frameIndex) {
                                      // Check if this frame exists for the player
                                      bool hasFrame =
                                          frameIndex < player.frames.length;

                                      return SizedBox(
                                        width: frameWidth,
                                        height: frameHeight,
                                        child: Container(
                                          margin: const EdgeInsets.all(0.5),
                                          decoration: BoxDecoration(
                                            color: frameIndex + 1 ==
                                                    _game!.currentFrame
                                                ? AppColors.ringBackground3rd
                                                    .withAlpha(76)
                                                : Colors.white,
                                            border: Border.all(
                                                color: Colors.grey[300]!),
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                          child: hasFrame
                                              ? _buildFrameCell(
                                                  player.frames[frameIndex],
                                                  frameIndex + 1 ==
                                                      _game!.currentFrame)
                                              : const SizedBox(),
                                        ),
                                      );
                                    }),
                                  ),
                                ),

                                // Total score
                                Container(
                                  width: totColumnWidth,
                                  height: frameHeight,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${player.totalScore}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrameCell(BowlingFrame frame, bool isCurrentFrame) {
    // Check if this might be the 10th frame based on the frameScore field
    bool isTenthFrame = frame.frameScore == 10;
    bool isStrike = frame.throws.isNotEmpty && frame.throws[0].isStrike;

    return Stack(
      children: [
        // First throw - always centered
        if (frame.throws.isNotEmpty)
          Positioned.fill(
            child: Center(
              child: Text(
                frame.throws[0].display,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16, // Consistent size for all throws
                ),
              ),
            ),
          ),

        // Handle second throw differently for regular frames vs 10th frame
        if (frame.throws.length > 1)
          if (isTenthFrame)
            // Second throw in 10th frame - top right with more padding
            Positioned(
              top: 2,
              right: 4,
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  frame.throws[1].display,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
              ),
            )
          else if (!isStrike)
            // Second throw for regular frames
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  frame.throws[1].display,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),

        // Third throw (10th frame only)
        if (isTenthFrame && frame.throws.length > 2)
          Positioned(
            bottom: 2,
            right: 4,
            child: Container(
              alignment: Alignment.center,
              child: Text(
                frame.throws[2].display,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 8, // Smaller for 10th frame extra throws
                ),
              ),
            ),
          ),
      ],
    );
  }
}
