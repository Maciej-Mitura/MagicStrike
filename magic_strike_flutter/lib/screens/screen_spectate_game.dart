import 'dart:async';
import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/services/firestore_service.dart';
import 'package:magic_strike_flutter/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpectateGameScreen extends StatefulWidget {
  final String gameCode;

  const SpectateGameScreen({
    super.key,
    required this.gameCode,
  });

  @override
  State<SpectateGameScreen> createState() => _SpectateGameScreenState();
}

class _SpectateGameScreenState extends State<SpectateGameScreen> {
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
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _firestoreService = FirestoreService();
    _userService = UserService();

    // Connect to the game as a spectator
    _spectateGame();
  }

  @override
  void dispose() {
    // Clean up resources
    _gameDocSubscription?.cancel();
    _leaveGame();
    super.dispose();
  }

  Future<void> _spectateGame() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Add user as a spectator to the game
      final gameData = await _firestoreService.spectateGame(widget.gameCode);

      if (gameData == null) {
        throw Exception('Game not found with code: ${widget.gameCode}');
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
      _listenForGameUpdates();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
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
      await _firestoreService.removeSpectatorFromGame(widget.gameCode);
    } catch (e) {
      print('Error leaving game: $e');
    }
  }

  void _listenForGameUpdates() {
    // Listen for updates to the game document
    _gameDocSubscription = FirebaseFirestore.instance
        .collection('games')
        .where('roomId', isEqualTo: widget.gameCode)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = 'Game not found or has been removed';
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
        _errorMessage = 'Error receiving game updates: $error';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Spectating Game: ${widget.gameCode}'),
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
        body: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
                ? _buildErrorState()
                : _buildGameContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Connecting to game...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[700]),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ringPrimary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameContent() {
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

        // Display number of players and current frame
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Players: ${_processedPlayers.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Current Frame: $_currentFrame',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),

        // Scoreboard section
        Expanded(
          child: _processedPlayers.isEmpty
              ? const Center(child: Text('No players in the game yet'))
              : SingleChildScrollView(
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
    // This will need to be implemented to display the scoring grid for all players
    // For brevity, I'm omitting the detailed implementation here, but it would be
    // very similar to the _buildScoreboard method in the BowlingGameScreen

    return Column(
      children: [
        // Current player indicator
        if (_gameStatus == 'in_progress' &&
            _currentPlayerIndex < _processedPlayers.length)
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              color: AppColors.ringPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              'Current Turn: ${_processedPlayers[_currentPlayerIndex]['name']} (Throw: $_currentThrow)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.ringPrimary,
              ),
            ),
          ),

        // Player rows
        ..._processedPlayers.map((player) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        player['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Total: ${player['totalScore'] ?? 0}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Display simplified frame data (could be expanded in the future)
                  Table(
                    border: TableBorder.all(),
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                        ),
                        children: List.generate(
                            10,
                            (i) => TableCell(
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Text(
                                      '${i + 1}',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )),
                      ),
                      // Throws row
                      TableRow(
                        children: List.generate(10, (i) {
                          final frame = player['frames'][i];
                          final throws = frame['throws'] as List<dynamic>;
                          String display = '';

                          // Format the display based on the throws
                          if (throws.isNotEmpty) {
                            if (throws[0] == 10) {
                              display = 'X';
                            } else if (throws.length > 1) {
                              if (throws[0] + throws[1] == 10) {
                                display = '${throws[0]}/';
                              } else {
                                display = '${throws[0]}-${throws[1]}';
                              }
                            } else {
                              display = '${throws[0]}';
                            }

                            // Special case for 10th frame
                            if (i == 9 && throws.length > 2) {
                              if (throws[2] == 10) {
                                display += 'X';
                              } else {
                                display += throws[2].toString();
                              }
                            }
                          }

                          return TableCell(
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                display,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showGameInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spectator Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room Code: ${widget.gameCode}'),
            const SizedBox(height: 8),
            const Text(
              'You are currently in spectator mode. You can view the game progress but cannot participate in the game.',
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

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Spectator Mode?'),
            content: const Text(
                'Are you sure you want to stop spectating this game?'),
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
}
