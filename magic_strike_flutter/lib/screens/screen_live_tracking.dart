import 'dart:async';
import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/models/game_model.dart';
import 'package:magic_strike_flutter/services/firestore_service.dart';
import 'package:magic_strike_flutter/services/user_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => LiveTrackingScreenState();
}

class LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final TextEditingController _gameIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late FirestoreService _firestoreService;
  late UserService _userService;

  // For real-time updates
  StreamSubscription<QuerySnapshot>? _gameDocSubscription;

  // Game data
  Map<String, dynamic>? _gameData;
  List<dynamic> _gamePlayers = [];
  List<Map<String, dynamic>> _processedPlayers = [];
  String _gameStatus = 'waiting';
  int _currentFrame = 1;
  int _currentPlayerIndex = 0;
  int _currentThrow = 1;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
    _userService = UserService();
  }

  @override
  void dispose() {
    // Clean up controller and subscription
    _gameIdController.dispose();
    _gameDocSubscription?.cancel();
    _leaveGame();
    super.dispose();
  }

  Future<void> _trackGame(String gameId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Add user as a spectator to the game
      final gameData = await _firestoreService.spectateGame(gameId);

      if (gameData == null) {
        throw Exception('Game not found with code: $gameId');
      }

      setState(() {
        _gameData = gameData;
        _gamePlayers = gameData['players'] ?? [];
        _gameStatus = gameData['status'] ?? 'waiting';
        _currentFrame = gameData['currentFrame'] ?? 1;
        _currentPlayerIndex = gameData['currentPlayerIndex'] ?? 0;
        _currentThrow = gameData['currentThrow'] ?? 1;

        // Process players for display
        _processPlayers();

        _isLoading = false;
      });

      // Start listening for game updates
      _listenForGameUpdates(gameId);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _processPlayers() {
    _processedPlayers = [];

    for (final playerData in _gamePlayers) {
      final name = playerData['firstName'] ?? 'Unknown';
      final totalScore = playerData['totalScore'] ?? 0;
      final throwsPerFrame =
          Map<String, dynamic>.from(playerData['throwsPerFrame'] ?? {});

      // Process frames
      final frames = <Map<String, dynamic>>[];

      for (int i = 1; i <= 10; i++) {
        final frameKey = i.toString();
        final throwsList = List<dynamic>.from(throwsPerFrame[frameKey] ?? []);

        final frame = {
          'frameIndex': i - 1,
          'throws': throwsList,
          'isComplete': _isFrameComplete(i, throwsList),
        };

        frames.add(frame);
      }

      _processedPlayers.add({
        'name': name,
        'totalScore': totalScore,
        'frames': frames,
        'userId': playerData['userId'] ?? '',
        'isActive':
            playerData['isActive'] != false, // default to true if not specified
      });
    }
  }

  bool _isFrameComplete(int frameIndex, List<dynamic> throws) {
    // For frames 1-9
    if (frameIndex < 10) {
      return throws.length >= 2 || (throws.isNotEmpty && throws[0] == 10);
    }
    // For 10th frame
    else {
      if (throws.isEmpty) return false;

      // If first throw is a strike, need 3 throws
      if (throws[0] == 10) {
        return throws.length >= 3;
      }
      // If first + second is a spare, need 3 throws
      else if (throws.length >= 2 && throws[0] + throws[1] == 10) {
        return throws.length >= 3;
      }
      // Otherwise need 2 throws
      else {
        return throws.length >= 2;
      }
    }
  }

  Future<void> _leaveGame() async {
    try {
      if (_gameData != null) {
        await _firestoreService.removeSpectatorFromGame(_gameData!['roomId']);
      }
    } catch (e) {
      print('Error leaving game: $e');
    }
  }

  void _listenForGameUpdates(String gameId) {
    // Listen for updates to the game document
    _gameDocSubscription = FirebaseFirestore.instance
        .collection('games')
        .where('roomId', isEqualTo: gameId)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        setState(() {
          _error = 'Game not found or has been removed';
        });
        return;
      }

      final gameDoc = snapshot.docs.first;
      final gameData = gameDoc.data();

      // Get the players array from the game document
      final List<dynamic> players = gameData['players'] ?? [];

      if (mounted) {
        setState(() {
          _gamePlayers = players;
          _gameStatus = gameData['status'] ?? 'waiting';
          _currentFrame = gameData['currentFrame'] ?? 1;
          _currentPlayerIndex = gameData['currentPlayerIndex'] ?? 0;
          _currentThrow = gameData['currentThrow'] ?? 1;

          // Update the processed players
          _processPlayers();
        });
      }
    }, onError: (error) {
      setState(() {
        _error = 'Error receiving game updates: $error';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show confirmation dialog when user tries to exit
        if (_gameData != null) {
          final shouldPop = await _showExitConfirmation();
          return shouldPop;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _gameData == null
            ? AppBar(
                title: const Text('Live Tracking'),
                centerTitle: true,
              )
            : AppBar(
                backgroundColor: AppColors.ringPrimary,
                foregroundColor: Colors.white,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tracking Game: ${_gameData!['roomId']}'),
                    const Text(
                      'View only mode',
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
        body: _gameData == null ? _buildGameIdForm() : _buildLiveGame(),
      ),
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
                  hintText: 'Enter room code',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                ),
                cursorColor: AppColors.ringPrimary,
                style: TextStyle(
                  color: AppColors.ringPrimary,
                  fontWeight: FontWeight.bold,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a Game ID';
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
                          _trackGame(
                              _gameIdController.text.trim().toUpperCase());
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
    return Column(
      children: [
        // Status bar
        Container(
          padding: const EdgeInsets.all(8.0),
          color: _gameStatus == 'waiting'
              ? Colors.orange[100]
              : _gameStatus == 'in_progress'
                  ? Colors.blue[100]
                  : Colors.green[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _gameStatus == 'waiting'
                    ? Icons.hourglass_empty
                    : _gameStatus == 'in_progress'
                        ? Icons.play_arrow
                        : Icons.check_circle,
                color: _gameStatus == 'waiting'
                    ? Colors.orange[800]
                    : _gameStatus == 'in_progress'
                        ? Colors.blue[800]
                        : Colors.green[800],
              ),
              const SizedBox(width: 8),
              Text(
                'Game Status: ${_gameStatus.toUpperCase()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _gameStatus == 'waiting'
                      ? Colors.orange[800]
                      : _gameStatus == 'in_progress'
                          ? Colors.blue[800]
                          : Colors.green[800],
                ),
              ),
            ],
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
      ],
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
            ..._processedPlayers.map((player) => _buildPlayerRow(player)),
          ],
        ),
      ),
    );
  }

  Widget _buildGameInfo() {
    // Get current player name
    String? currentPlayerName;
    if (_currentPlayerIndex < _processedPlayers.length) {
      currentPlayerName = _processedPlayers[_currentPlayerIndex]['name'];
    }

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
                'Frame $_currentFrame',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_gameStatus == 'in_progress')
                Text(
                  'Throw $_currentThrow',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (_gameStatus == 'in_progress' && currentPlayerName != null)
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Current Player: $currentPlayerName',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ringPrimary,
                ),
              ),
            )
          else if (_gameStatus == 'completed')
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
            final isCurrentFrame = index + 1 == _currentFrame;

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

  Widget _buildPlayerRow(Map<String, dynamic> player) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        children: [
          // Player name column
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(
                  player['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ringPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${player['totalScore']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Player's frames
          ...List.generate(
            10,
            (frameIndex) {
              final frames = player['frames'] as List<Map<String, dynamic>>;
              final frame = frames[frameIndex];
              return Expanded(
                child: _buildFrameCell(frame),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFrameCell(Map<String, dynamic> frame) {
    final frameIndex = frame['frameIndex'] as int;
    final bool isTenthFrame = frameIndex == 9;
    final throwsList = frame['throws'] as List<dynamic>;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: frameIndex == 9
            ? const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              )
            : null,
      ),
      height: 50,
      child: Column(
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
                    child: throwsList.isNotEmpty
                        ? Text(
                            throwsList[0] == 10
                                ? 'X'
                                : throwsList[0] == 0
                                    ? '-'
                                    : throwsList[0].toString(),
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
                    child: throwsList.length > 1
                        ? Text(
                            throwsList[1] == 10
                                ? 'X'
                                : (throwsList[0] != 10 &&
                                        throwsList[0] + throwsList[1] == 10)
                                    ? '/'
                                    : throwsList[1] == 0
                                        ? '-'
                                        : throwsList[1].toString(),
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
                      child: throwsList.length > 2
                          ? Text(
                              throwsList[2] == 10
                                  ? 'X'
                                  : (throwsList[1] == 10 ||
                                          (throwsList[0] != 10 &&
                                                  throwsList[0] +
                                                          throwsList[1] ==
                                                      10) &&
                                              throwsList[2] + throwsList[1] ==
                                                  10)
                                      ? '/'
                                      : throwsList[2] == 0
                                          ? '-'
                                          : throwsList[2].toString(),
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

          // Score display area
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.center,
              color: Colors.grey[100],
              child: frame['isComplete']
                  ? Text(
                      '${_calculateFrameScore(frame)}',
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
    );
  }

  int _calculateFrameScore(Map<String, dynamic> frame) {
    // In a real implementation, this would calculate the proper score
    // For demo purposes, we'll display a placeholder or use the running total
    final frameIndex = frame['frameIndex'] as int;
    final throwsList = frame['throws'] as List<dynamic>;

    // Simple sum of throws for demo
    int score = 0;
    for (var throwValue in throwsList) {
      score += throwValue as int;
    }

    // Multiply by frame index to simulate a running score
    return score * (frameIndex + 1);
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Tracking Mode?'),
            content:
                const Text('Are you sure you want to stop tracking this game?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Continue Watching'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ringPrimary,
                ),
                child: const Text('Exit Game'),
              ),
            ],
          ),
        ) ??
        false; // Default to false (don't exit) if dialog is dismissed
  }

  void _showGameInfo() {
    int spectatorCount =
        (_gameData?['spectators'] as List<dynamic>? ?? []).length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.ringPrimary),
            const SizedBox(width: 8),
            const Text('Game Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Game ID', _gameData?['roomId'] ?? 'Unknown'),
            _buildInfoRow('Status', _gameStatus.toUpperCase()),
            _buildInfoRow('Players', '${_gamePlayers.length}'),
            _buildInfoRow('Spectators', '$spectatorCount'),
            _buildInfoRow('Current Frame', '$_currentFrame'),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
