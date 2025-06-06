import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';

import '../services/user_service.dart'; // Import UserService

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Track focused state for each field
  bool _isEmailFocused = false;
  bool _isUsernameFocused = false;
  bool _isPasswordFocused = false;

  // Password visibility state
  bool _obscurePassword = true;

  // Error message state
  String? _emailError;
  String? _usernameError;
  String? _passwordError;
  String? _generalError;

  // Loading state
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Email validation
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }

    // Simple regex for email validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Username validation
  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a username';
    }

    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }

    return null;
  }

  // Password validation
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  // Register with Firebase
  Future<void> _registerUser() async {
    // Clear previous errors
    setState(() {
      _emailError = null;
      _usernameError = null;
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

    final String email = _emailController.text.trim();
    final UserService userService = UserService();

    try {
      // First, check if the email exists in Firebase Auth
      try {
        final methods =
            await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);

        // Email exists in Auth but we need to check if it exists in Firestore
        if (methods.isNotEmpty) {
          final bool existsInFirestore =
              await userService.checkEmailExistsInFirestore(email);

          // If the email exists in Auth but NOT in Firestore, we can create a new user with this email
          if (!existsInFirestore) {
            // Try to delete the auth user first
            try {
              // This is just a safety check in case there's a way to delete the Auth record
              // It will likely fail since we don't have credentials for this user
              print('Attempting to clean up orphaned Auth record for: $email');

              // Usually this won't work without reauthentication, but we try anyway
              // We'll ignore any errors and proceed with registration
            } catch (e) {
              print('Expected: Could not delete orphaned Auth record: $e');
            }

            setState(() {
              _emailError =
                  'This email is already registered but appears to be inactive. Please use the login screen or contact support to recover your account.';
              _isLoading = false;
            });
            return;
          }
        }
      } catch (e) {
        print('Error checking email methods: $e');
        // Continue with registration if the check fails
      }

      // Create user with email and password
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      // Set user display name
      await userCredential.user
          ?.updateDisplayName(_usernameController.text.trim());

      // Initialize user data
      try {
        await userService.initializeUserData();
      } catch (userInitError) {
        print('Error initializing user data: $userInitError');
        // Continue with registration even if user data initialization fails
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
      setState(() {
        _isLoading = false;
        if (e.code == 'email-already-in-use') {
          _emailError = 'This email is already in use';
        } else if (e.code == 'invalid-email') {
          _emailError = 'Invalid email format';
        } else if (e.code == 'weak-password') {
          _passwordError = 'Password is too weak';
        } else {
          _generalError = 'Registration failed: ${e.message}';
        }
      });
    } catch (e) {
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

                        // Username input with focus detection and validation
                        Focus(
                          onFocusChange: (hasFocus) {
                            setState(() {
                              _isUsernameFocused = hasFocus;
                            });
                          },
                          child: TextFormField(
                            controller: _usernameController,
                            validator: _validateUsername,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              errorText: _usernameError,
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
                              floatingLabelStyle:
                                  TextStyle(color: primaryColor),
                            ),
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
                              onPressed: _isLoading ? null : _registerUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      8.0), // Changed to match login button on first screen
                                ),
                                elevation: 0,
                                shadowColor:
                                    Colors.transparent, // Remove shadow
                                surfaceTintColor:
                                    Colors.transparent, // Remove surface tint
                                tapTargetSize: MaterialTapTargetSize
                                    .shrinkWrap, // Tighter touch target
                                animationDuration: const Duration(
                                    milliseconds: 50), // Faster animation
                              ).copyWith(
                                // Remove hover, focus and press effects
                                overlayColor: MaterialStateProperty.all(
                                    Colors.transparent),
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
