import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screen_login.dart';
import 'screen_register.dart';
import '../main.dart';

class AuthChoiceScreen extends StatefulWidget {
  const AuthChoiceScreen({super.key});

  @override
  State<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends State<AuthChoiceScreen> {
  @override
  void initState() {
    super.initState();
    // Check for existing user on initialization
    _checkCurrentUser();
  }

  // Check if a user is already signed in
  Future<void> _checkCurrentUser() async {
    User? currentUser = FirebaseAuth.instance.currentUser;

    // If user is already logged in, navigate to HomePage
    if (currentUser != null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(key: homePageKey),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo at the top - similar to HomePage
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.08),
                child: Image.asset(
                  'assets/MyLogoRing.png',
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),

              const Spacer(), // Push the buttons to the bottom

              // Login button - 60% width
              Center(
                child: SizedBox(
                  width: screenWidth * 0.6, // 60% of screen width
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFF72C22), // ringPrimary color
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent, // Remove shadow
                      surfaceTintColor:
                          Colors.transparent, // Remove surface tint
                      tapTargetSize: MaterialTapTargetSize
                          .shrinkWrap, // Tighter touch target
                      animationDuration:
                          const Duration(milliseconds: 50), // Faster animation
                    ).copyWith(
                      // Remove hover, focus and press effects
                      overlayColor:
                          MaterialStateProperty.all(Colors.transparent),
                    ),
                    child: const Text(
                      'Log in',
                      style: TextStyle(
                        fontSize:
                            24, // Larger text size (approximate to 46 in Figma)
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              // Spacing between button and text
              const SizedBox(height: 20),

              // Create account text - black without underline
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  'Create an account',
                  style: TextStyle(
                    color: Colors.black, // Changed to black
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    // Removed underline decoration
                  ),
                ),
              ),

              // Bottom padding - slightly more than space between elements
              SizedBox(
                  height: screenHeight *
                      0.1), // 10% of screen height as bottom padding
            ],
          ),
        ),
      ),
    );
  }
}
