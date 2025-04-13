import 'package:flutter/material.dart';
import '../main.dart'; // Import the main.dart to access the HomePage

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Track focused state for each field
  bool _isEmailFocused = false;
  bool _isUsernameFocused = false;
  bool _isPasswordFocused = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final primaryColor = const Color(0xFFF72C22); // ringPrimary color

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      // Logo at the top
                      Padding(
                        padding: const EdgeInsets.only(top: 40.0, bottom: 40.0),
                        child: Image.asset(
                          'assets/MyLogoRing.png',
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),

                      // Register text - larger and bolder
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30.0),
                        child: Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 42, // Increased from 36 to 42
                            fontWeight:
                                FontWeight.w900, // Extra bold (was bold)
                            color: primaryColor,
                          ),
                        ),
                      ),

                      // Email input with focus detection
                      Focus(
                        onFocusChange: (hasFocus) {
                          setState(() {
                            _isEmailFocused = hasFocus;
                          });
                        },
                        child: TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            prefixIcon: Icon(
                              Icons.email,
                              color:
                                  _isEmailFocused ? primaryColor : Colors.grey,
                            ),
                            labelStyle: TextStyle(
                              color:
                                  _isEmailFocused ? primaryColor : Colors.grey,
                            ),
                            floatingLabelStyle: TextStyle(color: primaryColor),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Username input with focus detection
                      Focus(
                        onFocusChange: (hasFocus) {
                          setState(() {
                            _isUsernameFocused = hasFocus;
                          });
                        },
                        child: TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            prefixIcon: Icon(
                              Icons.person,
                              color: _isUsernameFocused
                                  ? primaryColor
                                  : Colors.grey,
                            ),
                            labelStyle: TextStyle(
                              color: _isUsernameFocused
                                  ? primaryColor
                                  : Colors.grey,
                            ),
                            floatingLabelStyle: TextStyle(color: primaryColor),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Password input with focus detection
                      Focus(
                        onFocusChange: (hasFocus) {
                          setState(() {
                            _isPasswordFocused = hasFocus;
                          });
                        },
                        child: TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            prefixIcon: Icon(
                              Icons.lock,
                              color: _isPasswordFocused
                                  ? primaryColor
                                  : Colors.grey,
                            ),
                            labelStyle: TextStyle(
                              color: _isPasswordFocused
                                  ? primaryColor
                                  : Colors.grey,
                            ),
                            floatingLabelStyle: TextStyle(color: primaryColor),
                          ),
                          obscureText: true,
                        ),
                      ),
                    ],
                  ),

                  // Bottom navigation buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back arrow - thicker
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: primaryColor,
                              size: 60,
                              weight: 800,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),

                        // Let's go button - with updated corners
                        SizedBox(
                          width: screenWidth * 0.6,
                          height: 70,
                          child: ElevatedButton(
                            onPressed: () {
                              // Navigate to the main app screen (HomePage)
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      HomePage(key: homePageKey),
                                ),
                                (route) => false, // Remove all previous routes
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    8.0), // Changed to match login button on first screen
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Let's go",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
