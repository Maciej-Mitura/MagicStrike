import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart'; // Import the main.dart to access the HomePage
import '../services/user_service.dart'; // Import UserService

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Track focused state for each field
  bool _isEmailFocused = false;
  bool _isPasswordFocused = false;

  // Password visibility state
  bool _obscurePassword = true;

  // Error message state
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  // Loading state
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }

  // Login with Firebase
  Future<void> _loginUser() async {
    // Clear previous errors
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
      _isLoading = true;
    });

    // Validate form
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Sign in with email and password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Initialize user data after successful login
      try {
        await UserService().initializeUserData();
      } catch (userInitError) {
        print('Error initializing user data: $userInitError');
        // Continue with login even if user data initialization fails
      }

      // If successful, navigate to home page
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(key: homePageKey),
        ),
        (route) => false, // Remove all previous routes
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (e.code == 'user-not-found') {
          _emailError = 'No user found with this email';
        } else if (e.code == 'wrong-password') {
          _passwordError = 'Incorrect password';
        } else if (e.code == 'invalid-email') {
          _emailError = 'Invalid email format';
        } else if (e.code == 'user-disabled') {
          _generalError = 'This account has been disabled';
        } else {
          _generalError = 'Login failed: ${e.message}';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _generalError = 'An unexpected error occurred: $e';
      });
    }
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        // Logo at the top
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 40.0, bottom: 40.0),
                          child: Image.asset(
                            'assets/MyLogoRing.png',
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Login text - larger and bolder
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30.0),
                          child: Text(
                            'Log in',
                            style: TextStyle(
                              fontSize: 42, // Increased from 36 to 42
                              fontWeight:
                                  FontWeight.w900, // Extra bold (was bold)
                              color: primaryColor,
                            ),
                          ),
                        ),

                        // General error message
                        if (_generalError != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _generalError!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Email input with focus detection and validation
                        Focus(
                          onFocusChange: (hasFocus) {
                            setState(() {
                              _isEmailFocused = hasFocus;
                            });
                          },
                          child: TextFormField(
                            controller: _emailController,
                            validator: _validateEmail,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              errorText: _emailError,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide: BorderSide(color: primaryColor),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              prefixIcon: Icon(
                                Icons.email,
                                color: _isEmailFocused
                                    ? primaryColor
                                    : Colors.grey,
                              ),
                              labelStyle: TextStyle(
                                color: _isEmailFocused
                                    ? primaryColor
                                    : Colors.grey,
                              ),
                              floatingLabelStyle:
                                  TextStyle(color: primaryColor),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Password input with focus detection and validation
                        Focus(
                          onFocusChange: (hasFocus) {
                            setState(() {
                              _isPasswordFocused = hasFocus;
                            });
                          },
                          child: TextFormField(
                            controller: _passwordController,
                            validator: _validatePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              errorText: _passwordError,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide: BorderSide(color: primaryColor),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25.0),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              prefixIcon: Icon(
                                Icons.lock,
                                color: _isPasswordFocused
                                    ? primaryColor
                                    : Colors.grey,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: _isPasswordFocused
                                      ? primaryColor
                                      : Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              labelStyle: TextStyle(
                                color: _isPasswordFocused
                                    ? primaryColor
                                    : Colors.grey,
                              ),
                              floatingLabelStyle:
                                  TextStyle(color: primaryColor),
                            ),
                            obscureText: _obscurePassword,
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
                            decoration: const BoxDecoration(
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
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                    },
                            ),
                          ),

                          // Let's go button - with updated corners
                          SizedBox(
                            width: screenWidth * 0.6,
                            height: 70,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      8.0), // Changed to match login button on first screen
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : const Text(
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
      ),
    );
  }
}
