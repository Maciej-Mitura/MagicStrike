import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/screens/screen_bowling_game.dart';

class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key});

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final TextEditingController _codeController = TextEditingController();
  // This would come from Firebase in the future
  final String _playerName = "User123";
  final _formKey = GlobalKey<FormState>();
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _joinGame() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isJoining = true;
        _errorMessage = null;
      });

      // Get room code
      final roomCode = _codeController.text.trim();

      // Simulate checking if the room exists (in a real app, this would connect to backend)
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        // For demo, accept any 6-digit code
        if (roomCode.length == 6 && int.tryParse(roomCode) != null) {
          // Navigate to game screen as non-admin
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BowlingGameScreen(
                gameCode: roomCode,
                players: [
                  _playerName
                ], // We only know our own name when joining
                isAdmin: false,
              ),
            ),
          );
        } else {
          setState(() {
            _isJoining = false;
            _errorMessage = 'Game room not found. Please check the code.';
          });
        }
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
          'Join Game Room',
          style: TextStyle(color: Colors.black),
        ),
        elevation: 0,
      ),
      body: _isJoining
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
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Game Room Code',
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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
            'Joining game room...',
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
