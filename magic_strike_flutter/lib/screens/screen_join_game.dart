import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/screens/screen_bowling_game.dart';
import 'package:magic_strike_flutter/services/firestore_service.dart';
import 'package:magic_strike_flutter/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key});

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final TextEditingController _codeController = TextEditingController();
  String _playerName = "User123"; // This will be updated with actual user data
  String? _deRingID; // Store user's ID
  final _formKey = GlobalKey<FormState>();
  bool _isJoining = false;
  bool _isLoadingUserData = true; // Track if user data is still loading
  String? _errorMessage;
  final FirestoreService _firestoreService = FirestoreService();
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingUserData = true;
    });

    try {
      final userData = await _userService.getCurrentUserData();

      if (mounted) {
        setState(() {
          _playerName = userData['firstName'] ?? 'User123';
          _deRingID = userData['deRingID'];
          _isLoadingUserData = false;
        });

        print('Loaded user data - Name: $_playerName, DeRingID: $_deRingID');

        // If deRingID is still null, try to initialize user data
        if (_deRingID == null) {
          print('DeRingID is null, initializing user data...');
          final initializedData = await _userService.initializeUserData();

          if (mounted) {
            setState(() {
              _playerName = initializedData['firstName'] ?? 'User123';
              _deRingID = initializedData['deRingID'];
              _isLoadingUserData = false;
            });

            print(
                'Initialized user data - Name: $_playerName, DeRingID: $_deRingID');
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinGame() async {
    // Don't proceed if we're still loading user data or if user ID is missing
    if (_isLoadingUserData) {
      setState(() {
        _errorMessage = 'Still loading user data, please wait...';
      });
      return;
    }

    if (_deRingID == null) {
      setState(() {
        _errorMessage =
            'User data not available. Please try again or restart the app.';
      });
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isJoining = true;
        _errorMessage = null;
      });

      try {
        // Get room code
        final roomCode = _codeController.text.trim();

        print(
            'Attempting to join game $roomCode with user $_playerName (ID: $_deRingID)');

        // Check if the game exists
        final QuerySnapshot gameQuery = await FirebaseFirestore.instance
            .collection('games')
            .where('roomId', isEqualTo: roomCode)
            .limit(1)
            .get();

        if (gameQuery.docs.isEmpty) {
          throw Exception('Game not found');
        }

        // Add player to the game
        final success = await _firestoreService.addPlayerToGameRoom(
          roomCode,
          _playerName,
        );

        if (!success) {
          throw Exception('Failed to join game');
        }

        // Get updated game data
        final updatedGameQuery = await FirebaseFirestore.instance
            .collection('games')
            .where('roomId', isEqualTo: roomCode)
            .limit(1)
            .get();

        if (updatedGameQuery.docs.isEmpty) {
          throw Exception('Could not retrieve updated game data');
        }

        final gameDoc = updatedGameQuery.docs.first;
        final gameData = gameDoc.data();

        // Extract player names from the game data
        final List<dynamic> gamePlayers = gameData['players'] ?? [];
        final List<String> playerNames = gamePlayers
            .map<String>((player) => player['firstName'] as String)
            .toList();

        // Navigate to game screen as non-admin
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BowlingGameScreen(
                gameCode: roomCode,
                players: playerNames, // Use all players from the game
                isAdmin: false,
              ),
            ),
          );
        }
      } catch (e) {
        print('Error joining game: $e');
        if (mounted) {
          setState(() {
            _isJoining = false;
            if (e.toString().contains('not found')) {
              _errorMessage = 'Game not found. Please check the code.';
            } else if (e.toString().contains('already started')) {
              _errorMessage =
                  'This game has already started and cannot be joined.';
            } else if (e.toString().contains('Room is full')) {
              _errorMessage =
                  'This game room is full and cannot accept more players.';
            } else {
              _errorMessage = 'Error joining game: ${e.toString()}';
            }
          });
        }
      }
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
          'Join Game Room',
          style: TextStyle(color: Colors.black),
        ),
        elevation: 0,
      ),
      body: _isJoining || _isLoadingUserData
          ? _buildLoadingState()
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title and description at the top with padding
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                        child: Column(
                          children: [
                            Text(
                              'Join an Existing Room',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ringPrimary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Enter the room code provided by the game creator',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Room code input
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: AppColors.ringPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Game Room Code',
                          labelStyle: const TextStyle(color: Colors.grey),
                          floatingLabelStyle: WidgetStateTextStyle.resolveWith(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.focused)) {
                                return TextStyle(color: AppColors.ringPrimary);
                              }
                              return const TextStyle(color: Colors.grey);
                            },
                          ),
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.ringPrimary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        cursorColor: AppColors.ringPrimary,
                        // Update the style when field gets focus
                        onTap: () {
                          setState(() {
                            _codeController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _codeController.text.length,
                            );
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the room code';
                          }
                          if (value.length != 6 ||
                              int.tryParse(value) == null) {
                            return 'Room code must be 6 digits';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 30),

                      // Player name display (non-editable)
                      Container(
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
                              child: Text(
                                _playerName, // From the user profile
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

                      // Error message
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const SizedBox(height: 40),

                      // Join button
                      ElevatedButton(
                        onPressed: _joinGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ringPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0, // No drop shadow
                          shadowColor: Colors
                              .transparent, // Prevents shadow when pressed
                        ),
                        child: const Text(
                          'Join Game',
                          style: TextStyle(
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
            _isLoadingUserData
                ? 'Loading user data...'
                : 'Joining game room...',
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
}
