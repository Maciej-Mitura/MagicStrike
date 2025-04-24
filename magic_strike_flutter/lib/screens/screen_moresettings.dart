import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';

import 'screen_auth_choice.dart';
import '../services/user_service.dart';
import '../widgets/achievements_row.dart';
import '../screens/screen_badges.dart';

class MoreSettingsScreen extends StatefulWidget {
  const MoreSettingsScreen({super.key});

  @override
  State<MoreSettingsScreen> createState() => _MoreSettingsScreenState();
}

class _MoreSettingsScreenState extends State<MoreSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _appVersion = 'Loading...';

  // User data map - will be populated from Firestore
  Map<String, dynamic> _userData = {
    'username': '',
    'firstName': '',
    'lastName': '',
    'dateOfBirth': '',
    'gender': '',
    'deRingID': '',
    'clubTeam': '', // Maps to clubOrTeam in Firestore
    'email': '',
    'password': '••••••••',
    'bowlingSide': '', // Maps to side in Firestore
    'bowlingStyle': '', // Maps to style in Firestore
    'memberSince': '',
  };

  // Profile picture URL state
  String? _profilePictureUrl;
  bool _isBase64Image = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    // Ensure status bar is transparent for maximum height usage
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));

    _fetchUserData();
    _getAppVersion();
    _loadProfilePicture();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload profile picture when screen is displayed
    if (mounted) {
      _refreshProfilePicture();
    }
  }

  // Get app version from package info
  Future<void> _getAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
      print('App version loaded: ${packageInfo.version}');
    } catch (e) {
      print('Error getting app version: $e');
      // Don't set a fallback version - keep the "Loading..." state to indicate an error
    }
  }

  // Fetch user data from Firestore
  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print('No user is currently logged in');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get user document from Firestore using the UID
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        print('User document does not exist in Firestore');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get user data
      final userData = userDoc.data() as Map<String, dynamic>;

      // Update the user data map with values from Firestore
      // Use empty string as default value if field is missing or empty
      setState(() {
        _userData = {
          'username': userData['displayName'] ?? '',
          'firstName': userData['firstName'] ?? '',
          'lastName': userData['lastName'] ?? '',
          'dateOfBirth': userData['dateOfBirth'] ?? '',
          'gender': userData['gender'] ?? '',
          'deRingID': userData['deRingID'] ?? '',
          'clubTeam':
              userData['clubOrTeam'] ?? '', // Maps to clubOrTeam in Firestore
          'email': userData['email'] ?? '',
          'password': '••••••••', // Always keep masked
          'bowlingSide': userData['side'] ?? '', // Maps to side in Firestore
          'bowlingStyle': userData['style'] ?? '', // Maps to style in Firestore
          'memberSince': _formatTimestamp(
              userData['createdAt']), // Format from Firestore timestamp
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Format Firestore timestamp to readable date
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      if (timestamp is Timestamp) {
        final DateTime dateTime = timestamp.toDate();
        return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
      }
    } catch (e) {
      print('Error formatting timestamp: $e');
    }
    return '';
  }

  // Method to refresh profile picture without changing loading state
  Future<void> _refreshProfilePicture() async {
    if (!mounted) return;

    try {
      print('Refreshing profile picture...');

      // If we already have a valid URL, no need to fetch again
      if (_profilePictureUrl != null &&
          (_profilePictureUrl!.startsWith('http') ||
              _profilePictureUrl!.startsWith('data:image'))) {
        print('Using existing profile picture URL');
        return;
      }

      // First try to get profile picture URL
      final url = await UserService().getProfilePictureUrl();

      if (url != null && mounted) {
        setState(() {
          print('Updated profile picture from URL: $url');
          _profilePictureUrl = url;
          _isBase64Image = url.startsWith('data:image');
        });
        return;
      }

      // If URL not available, check for base64 image
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data();
      final base64Image = userData?['profilePictureBase64'] as String?;

      if (base64Image != null && mounted) {
        setState(() {
          print('Updated profile picture from base64');
          _profilePictureUrl = base64Image;
          _isBase64Image = true;
        });
      }
    } catch (e) {
      print('Error refreshing profile picture: $e');
    }
  }

  // Load profile picture URL - either from storage URL or base64
  Future<void> _loadProfilePicture() async {
    if (!mounted) return;

    try {
      setState(() {
        // Show loading indicator only if we don't have a picture yet
        if (_profilePictureUrl == null) {
          _isLoading = true;
        }
      });

      // First try to get profile picture URL
      final url = await UserService().getProfilePictureUrl();

      if (url != null) {
        if (mounted) {
          setState(() {
            print('Loading profile picture from URL: $url');
            _profilePictureUrl = url;
            _isBase64Image = url.startsWith('data:image');
            _isLoading = false;
          });
        }
        return;
      }

      // If URL not available, check for base64 image
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final userData = userDoc.data();
      final base64Image = userData?['profilePictureBase64'] as String?;

      if (mounted) {
        setState(() {
          if (base64Image != null) {
            print('Loading profile picture from base64');
            _profilePictureUrl = base64Image;
            _isBase64Image = true;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile picture: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Basic approach - store a small image directly in Firestore as base64
  // This is highly reliable but only suitable for small images
  Future<String?> _simpleBase64Approach() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a small image...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Configure picker for reliable selection with smaller image size
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200, // Very small width
        maxHeight: 200, // Very small height
        imageQuality: 50, // Heavy compression
        requestFullMetadata:
            false, // Reduces memory usage and improves reliability
      );

      // Check if mounted after picker returns
      if (!mounted) return null;

      if (image == null) {
        print('Simple approach: No image selected (user cancelled)');
        return null;
      }

      print('Simple approach: Image selected: ${image.path}');

      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user is logged in');
      }

      // Read bytes directly from XFile - this is the most reliable approach
      Uint8List imageBytes;
      try {
        imageBytes = await image.readAsBytes();
        if (imageBytes.isEmpty) {
          throw Exception('Selected image is empty');
        }
        print(
            'Successfully read ${imageBytes.length} bytes from selected image');
      } catch (e) {
        print('Error reading image data: $e');
        return null;
      }

      // Check mounted again
      if (!mounted) return null;

      // Show processing feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing image...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Generate base64 string
      final String base64Image = base64Encode(imageBytes);
      print('Base64 image length: ${base64Image.length} characters');

      // Firestore has document size limits, so ensure it's not too large
      if (base64Image.length > 900000) {
        throw Exception('Image too large, please select a smaller image');
      }

      // Generate data URL (works in most browsers/apps)
      final String dataUrl = 'data:image/jpeg;base64,$base64Image';

      try {
        // Update user document with base64 image
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'profilePictureBase64': dataUrl,
          // Remove any URL-based image to avoid conflicts
          'profilePicture': FieldValue.delete(),
        });

        print('Simple approach: Profile picture saved as base64');
        return dataUrl;
      } catch (updateError) {
        print('Error updating Firestore: $updateError');

        // Try once more if operation was cancelled
        if (updateError.toString().contains('cancelled')) {
          try {
            await Future.delayed(const Duration(milliseconds: 1000));
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .update({
              'profilePictureBase64': dataUrl,
              'profilePicture': FieldValue.delete(),
            });

            print('Simple approach retry: Profile picture saved as base64');
            return dataUrl;
          } catch (retryError) {
            print('Retry also failed: $retryError');
            return null;
          }
        }
        return null;
      }
    } catch (e) {
      print('Error in simple base64 approach: $e');
      return null;
    }
  }

  // Handle profile picture selection and upload
  Future<void> _changeProfilePicture() async {
    // Early return if already loading
    if (_isLoading) return;

    try {
      // Show loading indicator first
      setState(() {
        _isLoading = true;
      });

      // First try direct approach with larger image and retry logic
      String? url = await _directImagePickerApproach();

      // Handle the result
      if (mounted) {
        if (url != null) {
          // Success - update the UI immediately using the refresh method
          setState(() {
            _isLoading = false;
            // Update the profile picture URL directly
            _profilePictureUrl = url;
            _isBase64Image = url.startsWith('data:image');
          });

          // Force refresh to ensure the image is displayed properly
          await _refreshProfilePicture();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          // No success with direct approach
          setState(() {
            _isLoading = false;
          });

          // Don't show error message for cancellation
          // The user has likely just cancelled the picker
        }
      }
    } catch (e) {
      print('Error changing profile picture: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show error with retry option
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error updating profile picture: ${e.toString().contains("Exception:") ? e.toString().split("Exception:")[1] : e}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _changeProfilePicture,
            ),
          ),
        );
      }
    }
  }

  // Direct approach using ImagePicker without going through UserService
  Future<String?> _directImagePickerApproach() async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an image...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Configure picker for more reliable selection
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
        requestFullMetadata:
            false, // Reduces memory usage and improves reliability
      );

      // Check if mounted after picker returns and if image was selected
      if (!mounted) return null;

      if (image == null) {
        print('Direct picker: No image selected (user cancelled)');
        return null;
      }

      print('Direct picker: Image selected: ${image.path}');

      // Get bytes directly from XFile - this is more reliable than using File
      Uint8List? imageBytes;
      try {
        // Try to read bytes directly from the XFile
        imageBytes = await image.readAsBytes();
        if (imageBytes.isEmpty) {
          throw Exception('Selected image is empty');
        }
        print(
            'Successfully read ${imageBytes.length} bytes from selected image');
      } catch (e) {
        print('Error reading image data: $e');
        return null;
      }

      // Check mounted again
      if (!mounted) return null;

      // Verify we have a valid user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user is logged in');
      }
      final String uid = currentUser.uid;

      // Create unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_${uid}_$timestamp.jpg';

      // IMPORTANT: Store the image data for later use if upload fails
      // Use a memory-efficient approach to temporarily cache the image
      final cachedBytes = imageBytes; // Keep a reference to the bytes

      // Show uploading feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing image...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Upload with retry logic
      return await _uploadImageWithRetry(uid, fileName, cachedBytes);
    } catch (e) {
      print('Error in direct approach: $e');
      return null;
    }
  }

  // Helper method to upload image with retry logic
  Future<String?> _uploadImageWithRetry(
      String uid, String fileName, Uint8List imageBytes,
      {int retryCount = 0}) async {
    try {
      // Reference to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child(fileName);

      print('Starting upload to: ${storageRef.fullPath}');

      // Create metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': uid,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString()
        },
      );

      // Upload image bytes with careful exception handling
      try {
        // Start the upload
        final uploadTask = storageRef.putData(imageBytes, metadata);
        print('Upload started...');

        // Wait for upload to complete
        final snapshot = await uploadTask;
        print('Upload successful, getting download URL...');

        // Get download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();
        print('Download URL obtained: $downloadUrl');

        // Update user document with new profile URL
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'profilePicture': downloadUrl,
          // Remove any base64 image to avoid conflicts
          'profilePictureBase64': FieldValue.delete(),
        });

        print('User document updated with new profile picture URL');
        return downloadUrl;
      } catch (uploadError) {
        print('Upload error: $uploadError');

        // Check if we should retry
        if (retryCount < 2 && uploadError.toString().contains('cancelled')) {
          print('Upload was cancelled. Retrying (${retryCount + 1}/2)...');
          // Wait a moment before retrying
          await Future.delayed(const Duration(milliseconds: 1000));
          return _uploadImageWithRetry(uid, fileName, imageBytes,
              retryCount: retryCount + 1);
        }

        // If it's not a cancellation or we've retried too many times, rethrow
        rethrow;
      }
    } catch (e) {
      print('Error during image upload: $e');

      // If we failed after retries or for other reasons, try the simpler base64 approach
      if (imageBytes.length < 900000) {
        // Only if the image is small enough
        print(
            'Trying direct Firestore update with base64 image as fallback...');
        try {
          // Convert to base64
          final base64Image = base64Encode(imageBytes);
          final dataUrl = 'data:image/jpeg;base64,$base64Image';

          // Update Firestore directly
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'profilePictureBase64': dataUrl,
            'profilePicture': FieldValue.delete(),
          });

          print('Profile picture saved as base64 (fallback method)');
          return dataUrl;
        } catch (base64Error) {
          print('Base64 fallback also failed: $base64Error');
        }
      }

      return null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEditDialog(String field, String currentValue) {
    // If the field is deRingID, it should not be editable
    if (field == 'deRingID') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('DeRingID cannot be changed'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // If the field is dateOfBirth, show a date picker
    if (field == 'dateOfBirth') {
      _showDatePickerDialog(currentValue);
      return;
    }

    // For password field, show password dialog
    if (field == 'password') {
      _showPasswordDialog();
      return;
    }

    final TextEditingController controller =
        TextEditingController(text: currentValue);

    // Convert UI field name to Firestore field name
    String firestoreField = field;
    if (field == 'clubTeam') firestoreField = 'clubOrTeam';
    if (field == 'bowlingSide') firestoreField = 'side';
    if (field == 'bowlingStyle') firestoreField = 'style';
    if (field == 'firstName') firestoreField = 'firstName';
    if (field == 'username') firestoreField = 'displayName';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $field'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter your $field',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final String newValue = controller.text.trim();
              if (newValue.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Value cannot be empty'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Show loading indicator
              setState(() {
                _isLoading = true;
              });

              try {
                final User? currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  // Update local UI first
                  setState(() {
                    _userData[field] = newValue;
                  });

                  // Special handling for firstName field
                  if (field == 'firstName') {
                    // Update displayName in Firebase Auth and Firestore
                    final String newDisplayName = newValue;
                    await currentUser.updateDisplayName(newDisplayName);

                    // Update username/displayName in our UI and database
                    setState(() {
                      _userData['username'] = newDisplayName;
                    });

                    // Update both firstName and displayName in Firestore
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .update({
                      'firstName': newValue,
                      'displayName': newDisplayName,
                    });

                    // Update the UserService cached value
                    UserService().updateCachedFirstName(newValue);

                    // Update all games with the new firstName
                    await UserService().updateGamesWithNewName(newValue);

                    print(
                        'Updated firstName to $newValue and displayName to $newDisplayName');
                  }
                  // Normal handling for other fields
                  else {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .update({firestoreField: newValue});

                    // If we're updating username/displayName, also update it in Firebase Auth
                    if (field == 'username') {
                      await currentUser.updateDisplayName(newValue);
                    }

                    print('Updated $firestoreField in Firestore to $newValue');
                  }
                }
              } catch (e) {
                print('Error updating $firestoreField: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                // Hide loading indicator
                setState(() {
                  _isLoading = false;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Show date picker for date of birth field
  void _showDatePickerDialog(String currentValue) async {
    // Parse current date if available
    DateTime initialDate;
    try {
      if (currentValue.isNotEmpty) {
        // Parse DD/MM/YYYY format
        List<String> parts = currentValue.split('/');
        if (parts.length == 3) {
          initialDate = DateTime(
            int.parse(parts[2]), // Year
            int.parse(parts[1]), // Month
            int.parse(parts[0]), // Day
          );
        } else {
          initialDate = DateTime.now()
              .subtract(const Duration(days: 365 * 18)); // Default 18 years ago
        }
      } else {
        initialDate = DateTime.now()
            .subtract(const Duration(days: 365 * 18)); // Default 18 years ago
      }
    } catch (e) {
      print('Error parsing date: $e');
      initialDate = DateTime.now()
          .subtract(const Duration(days: 365 * 18)); // Default 18 years ago
    }

    // Ensure initialDate is not after today
    if (initialDate.isAfter(DateTime.now())) {
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.ringPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Format date as DD/MM/YYYY
      String formattedDate =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';

      // Update local UI
      setState(() {
        _userData['dateOfBirth'] = formattedDate;
      });

      // Update Firestore
      try {
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({'dateOfBirth': formattedDate});
          print('Updated dateOfBirth in Firestore');
        }
      } catch (e) {
        print('Error updating dateOfBirth: $e');
      }
    }
  }

  // Show password change dialog with validation
  void _showPasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    String? passwordError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Enter new password',
                  errorText: passwordError,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Password must be at least 6 characters',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Validate password
                if (passwordController.text.isEmpty) {
                  setState(() {
                    passwordError = 'Please enter a password';
                  });
                  return;
                }

                if (passwordController.text.length < 6) {
                  setState(() {
                    passwordError = 'Password must be at least 6 characters';
                  });
                  return;
                }

                setState(() {
                  passwordError = null;
                });

                // Update Firebase Auth password
                try {
                  final User? currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    await currentUser.updatePassword(passwordController.text);

                    // Success message
                    if (this.mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('Password updated successfully'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  print('Error updating password: $e');
                  if (this.mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating password: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }

                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  void _showSelectionDialog(
      String field, List<String> options, String currentValue) {
    // Convert UI field name to Firestore field name
    String firestoreField = field;
    if (field == 'gender') firestoreField = 'gender';
    if (field == 'bowlingSide') firestoreField = 'side';
    if (field == 'bowlingStyle') firestoreField = 'style';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $field'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (option) => RadioListTile<String>(
                  title: Text(option),
                  value: option,
                  groupValue: currentValue,
                  onChanged: (value) async {
                    if (value == null) return;

                    // Update local UI first
                    setState(() {
                      _userData[field] = value;
                    });

                    // Update Firestore
                    try {
                      final User? currentUser =
                          FirebaseAuth.instance.currentUser;
                      if (currentUser != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .update({firestoreField: value});
                        print('Updated $firestoreField in Firestore');
                      }
                    } catch (e) {
                      print('Error updating $firestoreField: $e');
                    }

                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Handle logout
  Future<void> _handleLogout() async {
    // Show dialog to confirm logout
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Log Out'),
              content: const Text('Are you sure you want to log out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.ringPrimary,
                  ),
                  child: const Text('Log Out'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldLogout) {
      try {
        // Clear saved user data
        UserService().clearUserData();

        // Sign out from Firebase Auth
        await FirebaseAuth.instance.signOut();

        // Navigate to auth screen
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthChoiceScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        // Handle logout errors
        print('Error during logout: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Password confirmation dialog for account deletion
  void _showDeleteAccountDialog() {
    if (!mounted) return;

    final TextEditingController passwordController = TextEditingController();
    bool isPasswordIncorrect = false;
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (builderContext, setState) {
          return AlertDialog(
            title: const Text('Delete Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action cannot be undone. Please enter your password to confirm.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    errorText:
                        isPasswordIncorrect ? 'Incorrect password' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              if (isProcessing)
                const CircularProgressIndicator()
              else
                TextButton(
                  onPressed: () async {
                    // Start processing
                    setState(() {
                      isProcessing = true;
                    });

                    try {
                      final User? currentUser =
                          FirebaseAuth.instance.currentUser;
                      if (currentUser == null) {
                        throw Exception('No user is currently logged in');
                      }

                      // Re-authenticate user to confirm password
                      try {
                        // Get current user email
                        final String? email = currentUser.email;
                        if (email == null) {
                          throw Exception('User email not found');
                        }

                        // Create credential
                        final credential = EmailAuthProvider.credential(
                          email: email,
                          password: passwordController.text,
                        );

                        // Re-authenticate
                        await currentUser
                            .reauthenticateWithCredential(credential);

                        // Save user ID to be able to find games later
                        final String userId = currentUser.uid;

                        // Delete user from Firebase Auth
                        await currentUser.delete();

                        // Completely delete the user document from Firestore instead of just marking it
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .delete();

                        // Close the dialog
                        Navigator.of(dialogContext).pop();

                        // Clear user data from local storage
                        UserService().clearUserData();

                        // Show success message and redirect to auth screen
                        if (mounted) {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext successContext) {
                              return AlertDialog(
                                title: const Text('Account Deleted'),
                                content: const Text(
                                    'Your account has been deleted successfully.'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(successContext).pop();
                                      // Navigate to auth choice screen
                                      if (mounted) {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  const AuthChoiceScreen()),
                                          (route) => false,
                                        );
                                      }
                                    },
                                    child: const Text('OK'),
                                  ),
                                ],
                              );
                            },
                          );
                        }
                      } catch (authError) {
                        // Authentication failed, likely due to wrong password
                        print('Authentication error: $authError');
                        setState(() {
                          isPasswordIncorrect = true;
                          isProcessing = false;
                        });
                      }
                    } catch (e) {
                      // Handle general errors
                      print('Error during account deletion: $e');
                      setState(() {
                        isProcessing = false;
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error deleting account: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        Navigator.of(dialogContext).pop();
                      }
                    }
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.ringPrimary,
                  ),
                  child: const Text('Delete'),
                ),
            ],
          );
        });
      },
    );
  }

  void _showUrlDialog(String title, String url) {
    // Launch URL directly
    _launchURL(url);
  }

  // Add a new method to launch URLs
  Future<void> _launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // If unable to launch URL, show error dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cannot open link'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Unable to open the link. You can copy it manually:'),
                  const SizedBox(height: 8),
                  Text(
                    url,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.ringPrimary,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('URL copied to clipboard')),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Copy URL'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Tab buttons - positioned at the very top with minimal spacing
                  Container(
                    margin: const EdgeInsets.only(
                        left: 16, right: 16, top: 24, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Stack(
                      children: [
                        // Animated selection indicator
                        AnimatedAlign(
                          alignment: _tabController.index == 0
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: Container(
                            width: MediaQuery.of(context).size.width / 2 - 16,
                            height: 45,
                            decoration: BoxDecoration(
                              color: AppColors.ringPrimary,
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                        // Tab buttons
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _tabController.animateTo(0),
                                child: Container(
                                  height: 45,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Text(
                                    'Profile',
                                    style: TextStyle(
                                      color: _tabController.index == 0
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _tabController.animateTo(1),
                                child: Container(
                                  height: 45,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Text(
                                    'Settings',
                                    style: TextStyle(
                                      color: _tabController.index == 1
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildProfileTab(),
                        _buildSettingsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Username display
          Center(
            child: Column(
              children: [
                const SizedBox(height: 24), // Match spacing with tabs

                // Profile Picture with change button
                Stack(
                  children: [
                    // Profile Picture
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.ringPrimary,
                      ),
                      child: _profilePictureUrl != null
                          ? ClipOval(
                              child: _isBase64Image
                                  ? Builder(
                                      builder: (context) {
                                        try {
                                          // Try to decode base64 safely
                                          final List<String> parts =
                                              _profilePictureUrl!.split(',');
                                          if (parts.length < 2) {
                                            throw Exception(
                                                'Invalid base64 image format');
                                          }

                                          final Uint8List bytes =
                                              base64Decode(parts[1]);

                                          return Image.memory(
                                            bytes,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              print(
                                                  'Error displaying base64 image: $error');
                                              return const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Colors.white,
                                              );
                                            },
                                          );
                                        } catch (e) {
                                          print(
                                              'Error processing base64 image: $e');
                                          return const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.white,
                                          );
                                        }
                                      },
                                    )
                                  : Image.network(
                                      _profilePictureUrl!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        print(
                                            'Error loading network image: $error');
                                        return const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.white,
                                        );
                                      },
                                    ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            ),
                    ),

                    // Change Picture Button (positioned at bottom right)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _changeProfilePicture,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.ringPrimary,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: AppColors.ringPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _userData['firstName'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Achievements Section
          AchievementsRow(
            cardHeight: 140,
            cardWidth: 110,
            onViewAllPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BadgeScreen()),
              );
            },
          ),

          const SizedBox(height: 24),

          // Personal Info Section
          _buildSectionTitle('Personal Information'),
          _buildInfoBox([
            _buildInfoRow('First Name', _userData['firstName'],
                onTap: () =>
                    _showEditDialog('firstName', _userData['firstName'])),
            _buildInfoRow('Last Name', _userData['lastName'],
                onTap: () =>
                    _showEditDialog('lastName', _userData['lastName'])),
            _buildInfoRow('Date of Birth', _userData['dateOfBirth'],
                onTap: () =>
                    _showEditDialog('dateOfBirth', _userData['dateOfBirth'])),
            _buildInfoRow('Gender', _userData['gender'],
                onTap: () => _showSelectionDialog('gender',
                    ['Male', 'Female', 'Other'], _userData['gender'])),
            _buildInfoRow('deRingID', _userData['deRingID'], isEditable: false),
            _buildInfoRow('Club/Team', _userData['clubTeam'],
                onTap: () =>
                    _showEditDialog('clubTeam', _userData['clubTeam'])),
            _buildInfoRow('Email', _userData['email'],
                onTap: () => _showEditDialog('email', _userData['email'])),
            _buildInfoRow('Password', _userData['password'],
                onTap: () => _showEditDialog('password', '')),
          ]),

          const SizedBox(height: 24),

          // Bowling Info Section
          _buildSectionTitle('Bowling Information'),
          _buildInfoBox([
            _buildInfoRow('Side', _userData['bowlingSide'],
                onTap: () => _showSelectionDialog('bowlingSide',
                    ['Left', 'Right'], _userData['bowlingSide'])),
            _buildInfoRow('Style', _userData['bowlingStyle'],
                onTap: () => _showSelectionDialog(
                    'bowlingStyle',
                    ['Single-handed', 'Double-handed'],
                    _userData['bowlingStyle'])),
            _buildInfoRow('Member Since', _userData['memberSince'],
                isEditable: false),
          ]),

          const SizedBox(height: 32),

          // Log Out Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ringPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0, // Remove shadow
                shadowColor: Colors.transparent, // Remove shadow
                surfaceTintColor: Colors.transparent, // Remove surface tint
                tapTargetSize:
                    MaterialTapTargetSize.shrinkWrap, // Tighter touch target
                animationDuration:
                    const Duration(milliseconds: 50), // Faster animation
              ).copyWith(
                // Remove hover, focus and press effects
                overlayColor: MaterialStateProperty.all(Colors.transparent),
              ),
              child: const Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Support Section
          _buildSectionTitle('Support'),
          _buildInfoBox([
            _buildActionRow('How-to on YouTube', onTap: () {
              _showUrlDialog('Visit our YouTube channel',
                  'https://www.youtube.com/watch?v=xah1Cp9GA90');
            }),
            _buildActionRow('Terms of Use', onTap: () {
              _showUrlDialog('Terms of Use',
                  'https://gist.github.com/Maciej-Mitura/72d3c1bf4df99a2c468ba332cf77a219');
            }),
            _buildActionRow('Privacy Policy', onTap: () {
              _showUrlDialog('Privacy Policy',
                  'https://gist.github.com/Maciej-Mitura/72d3c1bf4df99a2c468ba332cf77a219');
            }),
            _buildActionRow('Contact Us', onTap: () {
              _showUrlDialog('Visit our website', 'https://bowlingdering.be');
            }),
            _buildActionRow('Find us', onTap: () {
              _showUrlDialog('Open in Google Maps',
                  'https://maps.app.goo.gl/ZQcNYsG4GRWL753G9');
            }),
            _buildInfoRow('Version', _appVersion, isEditable: false),
          ]),

          const SizedBox(height: 24),

          // Account Section
          _buildSectionTitle('Account'),
          _buildInfoBox([
            _buildInfoRow('Subscription', 'Free', isEditable: false),
            _buildInfoRow('Language', 'English', isEditable: false),
            _buildDeleteAccountRow(),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Special row for Delete Account with warning color
  Widget _buildDeleteAccountRow() {
    return InkWell(
      onTap: _showDeleteAccountDialog,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Delete Account',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.ringPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.ringPrimary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool isBlack = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isBlack ? Colors.black : AppColors.ringPrimary,
        ),
      ),
    );
  }

  Widget _buildInfoBox(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Function()? onTap, bool isEditable = true}) {
    return InkWell(
      onTap: isEditable ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.normal,
                  ),
                ),
                if (isEditable) const SizedBox(width: 8),
                if (isEditable)
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                    size: 20,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(String label, {required Function() onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
