import 'dart:math';
import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/screens/screen_bowling_game.dart';

class CreateGameScreen extends StatefulWidget {
  const CreateGameScreen({super.key});

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  int _numPlayers = 1;
  // This would come from Firebase in the future
  final String _creatorName = "User123";
  final List<String?> _playerNames = ["User123"];
  final _formKey = GlobalKey<FormState>();
  String _gameCode = '';
  bool _isCreatingRoom = false;

  @override
  void initState() {
    super.initState();
    _generateRoomCode();
  }

  void _generateRoomCode() {
    // Generate a random 6-digit code for the room
    final random = Random();
    final code = List.generate(6, (_) => random.nextInt(10)).join();
    setState(() {
      _gameCode = code;
    });
  }

  void _updatePlayerCount(int count) {
    if (count < 1) count = 1;
    if (count > 6) count = 6; // Maximum 6 players

    setState(() {
      if (count > _numPlayers) {
        // Add new placeholder players
        for (int i = _numPlayers; i < count; i++) {
          _playerNames.add(null); // null means waiting for player
        }
      } else if (count < _numPlayers) {
        // Remove excess players
        _playerNames.removeRange(count, _numPlayers);
      }
      _numPlayers = count;
    });
  }

  // This would be triggered by Firebase events in the future
  void _simulatePlayerJoined(int playerIndex, String name) {
    // For demo - simulate players joining automatically after 1-3 seconds
    if (playerIndex > 0 && playerIndex < _playerNames.length) {
      Future.delayed(Duration(seconds: Random().nextInt(3) + 1), () {
        if (!mounted) return;
        setState(() {
          _playerNames[playerIndex] = "Player ${playerIndex + 1}";
        });
      });
    }
  }

  bool get _allPlayersJoined => !_playerNames.contains(null);

  void _startGame() {
    if (_formKey.currentState!.validate() && _allPlayersJoined) {
      setState(() {
        _isCreatingRoom = true;
      });

      // Create player list from joined players
      final players = _playerNames.whereType<String>().toList();

      // Simulate network delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BowlingGameScreen(
              gameCode: _gameCode,
              players: players,
              isAdmin: true,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        title: const Text(
          'Create Game Room',
          style: TextStyle(color: Colors.black),
        ),
        elevation: 0,
      ),
      body: _isCreatingRoom
          ? _buildLoadingState()
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Room code display
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Your Room Code',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _gameCode,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ringPrimary,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Share this code with other players',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Player count selector
                      const Text(
                        'Number of Players',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () =>
                                _updatePlayerCount(_numPlayers - 1),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.black,
                              size: 36,
                            ),
                            splashRadius: 24,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                          Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_numPlayers',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                _updatePlayerCount(_numPlayers + 1),
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.black,
                              size: 36,
                            ),
                            splashRadius: 24,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // Player list
                      const Text(
                        'Players',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ..._buildPlayerList(),

                      const SizedBox(height: 40),

                      // Start game button
                      ElevatedButton(
                        onPressed: _allPlayersJoined ? _startGame : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ringPrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _allPlayersJoined
                              ? 'Start Game'
                              : 'Waiting for Players...',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Creating game room...',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.ringPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlayerList() {
    final playerWidgets = <Widget>[];

    for (int i = 0; i < _numPlayers; i++) {
      // For demo, simulate player joining when added
      if (i > 0 && _playerNames[i] == null) {
        _simulatePlayerJoined(i, "Player ${i + 1}");
      }

      playerWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: AppColors.ringPrimary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: i == 0
                      ? Text(
                          _creatorName, // Creator (current user)
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : _playerNames[i] != null
                          ? Text(
                              _playerNames[i]!, // Joined player
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                          : Row(
                              children: const [
                                Text(
                                  'Waiting for player...',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                SizedBox(width: 8),
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return playerWidgets;
  }
}
