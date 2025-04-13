import 'package:flutter/material.dart';
import 'screen_login.dart';
import 'screen_register.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

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
