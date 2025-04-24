import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../screens/screen_auth_choice.dart';
import '../main.dart';
import '../services/badge_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _errorMessage;
  final BadgeService _badgeService = BadgeService();

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  // Check if user is already logged in
  Future<void> _checkAuthStatus() async {
    try {
      // Ensure Firebase is initialized
      await Firebase.initializeApp();

      // Get current user (will be null if not logged in)
      User? currentUser = FirebaseAuth.instance.currentUser;

      // Small delay to ensure Firebase Auth is initialized
      await Future.delayed(const Duration(milliseconds: 500));

      // If user is logged in, migrate badge format
      if (currentUser != null) {
        print('🔄 User logged in, migrating badge format');
        await _badgeService.migrateBadgesFormat();
      }

      // Update state based on auth status
      if (mounted) {
        setState(() {
          _isLoggedIn = currentUser != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Handle initialization errors
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show error message if initialization failed
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _checkAuthStatus();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF72C22), // ringPrimary color
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Show loading spinner while checking auth status
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Image.asset(
                  'assets/MyLogoRing.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),

              // Loading spinner
              const CircularProgressIndicator(
                color: Color(0xFFF72C22), // ringPrimary color
              ),

              const SizedBox(height: 24),

              // Loading text
              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Navigate to appropriate screen based on login status
    return _isLoggedIn ? HomePage(key: homePageKey) : const AuthChoiceScreen();
  }
}
