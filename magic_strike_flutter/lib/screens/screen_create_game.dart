import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/screens/screen_bowling_game.dart';
import 'package:magic_strike_flutter/services/firestore_service.dart';
import 'package:magic_strike_flutter/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateGameScreen extends StatefulWidget {
  const CreateGameScreen({super.key});

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  int _numPlayers = 1;
  String _creatorName = "User123";
  String? _creatorDeRingID;
  List<Map<String, dynamic>> _players =
      []; // Store player info with userId, firstName
  final _formKey = GlobalKey<FormState>();
  String _gameCode = '';
  bool _isCreatingRoom = false;
  final FirestoreService _firestoreService = FirestoreService();
  final UserService _userService = UserService();
  StreamSubscription<QuerySnapshot>? _gameRoomSubscription;

  @override
  void initState() {
    super.initState();

    // Show loading state immediately
    setState(() {
      _isCreatingRoom = true;
    });

    // Load user data first, then generate room code
    _loadUserData().then((_) {
      if (mounted) {
        _generateRoomCode();
      }
    }).catchError((error) {
      print('Error in initialization: $error');
      if (mounted) {
        setState(() {
          _isCreatingRoom = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating room: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    // Cancel the subscription when leaving the screen
    _gameRoomSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _userService.getCurrentUserData();

      if (!mounted) return;

      setState(() {
        _creatorName = userData['firstName'] ?? 'User123';
        _creatorDeRingID = userData['deRingID'];

        // Add creator as first player
        _players = [
          {
            'userId': _creatorDeRingID,
            'firstName': _creatorName,
            'isCreator': true
          }
        ];
      });

      print(
          'Loaded user data - Name: $_creatorName, DeRingID: $_creatorDeRingID');
    } catch (e) {
      print('Error loading user data: $e');
      throw Exception('Failed to load user data: $e');
    }
  }

  Future<void> _generateRoomCode() async {
    try {
      setState(() {
        _isCreatingRoom = true;
      });

      // Make sure we have the creator ID before continuing
      if (_creatorDeRingID == null) {
        throw Exception('User data not available yet');
      }

      bool isUnique = false;
      String code = '';
      final random = Random();

      // Keep generating codes until we find a unique one
      while (!isUnique) {
        // Generate a random 6-digit code for the room
        code = List.generate(6, (_) => random.nextInt(10)).join();

        // Check if a game with this roomId already exists
        final QuerySnapshot existingGames = await FirebaseFirestore.instance
            .collection('games')
            .where('roomId', isEqualTo: code)
            .limit(1)
            .get();

        isUnique = existingGames.docs.isEmpty;
      }

      setState(() {
        _gameCode = code;
      });

      // Create a new game document with the required structure
      await _createGameDocument();

      // Start listening for players joining the game
      _listenForPlayersJoining();

      setState(() {
        _isCreatingRoom = false;
      });

      print('Game successfully created with code: $_gameCode');
    } catch (e) {
      print('Error in game creation process: $e');

      if (e.toString().contains('User data not available')) {
        // Retry after a short delay if user data wasn't ready
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _generateRoomCode();
          }
        });
        return;
      }

      // Fallback to simple generation if there's an unrecoverable error
      final random = Random();
      final code = List.generate(6, (_) => random.nextInt(10)).join();

      setState(() {
        _gameCode = code;
        _isCreatingRoom = false;
      });
    }
  }

  void _listenForPlayersJoining() {
    // Listen to the game document instead of gameRooms
    _gameRoomSubscription = FirebaseFirestore.instance
        .collection('games')
        .where('roomId', isEqualTo: _gameCode)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) return;

      final gameDoc = snapshot.docs.first;
      final gameData = gameDoc.data();
      final List<dynamic> gamePlayers = gameData['players'] ?? [];

      // Convert to our internal player format and update UI
      final updatedPlayers = <Map<String, dynamic>>[];

      // Add all players from the game document
      for (final player in gamePlayers) {
        final userId = player['userId'];
        final firstName = player['firstName'];

        updatedPlayers.add({
          'userId': userId,
          'firstName': firstName,
          'isCreator': userId == _creatorDeRingID
        });
      }

      if (mounted) {
        setState(() {
          _players = updatedPlayers;
        });
      }
    }, onError: (error) {
      print('Error listening to game updates: $error');
    });
  }

  void _updatePlayerCount(int count) {
    if (count < 1) count = 1;
    if (count < _players.length)
      count = _players.length; // Don't reduce below actual player count
    if (count > 6) count = 6; // Maximum 6 players

    setState(() {
      _numPlayers = count;
    });

    // Update maxPlayers in Firebase
    _updateMaxPlayersInFirestore(count);
  }

  Future<void> _updateMaxPlayersInFirestore(int maxPlayers) async {
    try {
      // Check if game document exists
      if (_gameCode.isEmpty) {
        print('Cannot update max players: Game code not available yet');
        return;
      }

      // Find the game document with this roomId
      final QuerySnapshot gamesQuery = await FirebaseFirestore.instance
          .collection('games')
          .where('roomId', isEqualTo: _gameCode)
          .limit(1)
          .get();

      if (gamesQuery.docs.isEmpty) {
        print('Game not found with roomId: $_gameCode');
        return;
      }

      final gameDoc = gamesQuery.docs.first;

      // Update maxPlayers field
      await gameDoc.reference.update({'maxPlayers': maxPlayers});

      print('Updated maxPlayers to $maxPlayers for room: $_gameCode');
    } catch (e) {
      print('Error updating maxPlayers in Firestore: $e');
    }
  }

  bool get _allPlayersJoined => _players.length >= _numPlayers;

  Future<void> _startGame() async {
    if (_formKey.currentState!.validate() && _allPlayersJoined) {
      setState(() {
        _isCreatingRoom = true;
      });

      try {
        // Find the game document with this roomId
        final QuerySnapshot gameQuery = await FirebaseFirestore.instance
            .collection('games')
            .where('roomId', isEqualTo: _gameCode)
            .limit(1)
            .get();

        if (gameQuery.docs.isEmpty) {
          throw Exception('Game not found with roomId: $_gameCode');
        }

        final gameDoc = gameQuery.docs.first;

        // Set status to 'in_progress' and update startTime to current time
        await gameDoc.reference.update({
          'status': 'in_progress',
          'startTime': FieldValue
              .serverTimestamp(), // Set actual start time when game begins
        });

        // Get player names for the BowlingGameScreen
        final playerNames =
            _players.map((p) => p['firstName'] as String).toList();

        // Navigate to the bowling game screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BowlingGameScreen(
                gameCode: _gameCode,
                players: playerNames,
                isAdmin: true,
              ),
            ),
          );
        }
      } catch (e) {
        // Handle any errors
        print('Error starting game: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error starting game: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isCreatingRoom = false;
          });
        }
      }
    }
  }

  Future<void> _createGameDocument() async {
    try {
      if (_creatorDeRingID == null) {
        throw Exception('Creator deRingID is not available');
      }

      // Current time for creation time
      final now = DateTime.now();

      // Create empty throwsPerFrame structure for a new game
      final throwsPerFrame = {
        '1': [],
        '2': [],
        '3': [],
        '4': [],
        '5': [],
        '6': [],
        '7': [],
        '8': [],
        '9': [],
        '10': []
      };

      // Create game document with the exact structure from the requirements
      final gameData = {
        'date': now,
        'duration':
            0, // Default duration: will be calculated when game is saved
        'startTime': now, // Use startTime instead of endTime for game start
        'location': 'Bowling DeRing', // Default location
        'roomId': _gameCode,
        'status':
            'waiting', // Add status field to indicate game is waiting for players
        'maxPlayers': _numPlayers, // Maximum number of players allowed to join
        'players': [
          {
            'firstName': _creatorName,
            'userId': _creatorDeRingID,
            'throwsPerFrame': throwsPerFrame,
            'totalScore': 0
          }
        ]
      };

      // Add to Firestore
      await FirebaseFirestore.instance.collection('games').add(gameData);
      print('Created new game document with roomId: $_gameCode');
    } catch (e) {
      print('Error creating game document: $e');
      throw Exception('Failed to create game document: $e');
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
                          elevation: 0,
                          shadowColor: Colors.transparent,
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

    // First, add the players we know about
    for (int i = 0; i < _players.length; i++) {
      final player = _players[i];

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
                  color: player['isCreator'] == true
                      ? AppColors.ringPrimary
                      : AppColors.ringSecondary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "${player['firstName']}${player['isCreator'] == true ? ' (Creator)' : ''}",
                    style: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Then add empty waiting slots
    for (int i = _players.length; i < _numPlayers; i++) {
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
                  Icons.person_outline,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
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
