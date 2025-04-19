import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screen_auth_choice.dart';
import '../services/user_service.dart';

class MoreSettingsScreen extends StatefulWidget {
  const MoreSettingsScreen({super.key});

  @override
  State<MoreSettingsScreen> createState() => _MoreSettingsScreenState();
}

class _MoreSettingsScreenState extends State<MoreSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _fetchUserData();
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    // Show a loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user is logged in');
      }

      // Get current user data from service for comparison
      final userData = await UserService().getCurrentUserData();
      final oldFirstName = userData['firstName'];

      // Create a map of data to update in Firestore
      final Map<String, dynamic> dataToUpdate = {
        'firstName': _userData['firstName'],
        'lastName': _userData['lastName'],
        'displayName': _userData['username'],
        'email': _userData['email'],
        'clubOrTeam': _userData['clubTeam'],
        'dateOfBirth': _userData['dateOfBirth'],
        'gender': _userData['gender'],
        'side': _userData['bowlingSide'],
        'style': _userData['bowlingStyle'],
      };

      // Update Firestore document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update(dataToUpdate);

      // Update Firebase Auth displayName
      await currentUser.updateDisplayName(_userData['username']);

      // Update the UserService cached values
      UserService().updateCachedFirstName(_userData['firstName']);

      // Update all games if firstName changed
      if (oldFirstName != _userData['firstName']) {
        await UserService().updateGamesWithNewName(_userData['firstName']);
      }

      // Fetch the updated data to ensure everything is in sync
      await _fetchUserData();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error saving profile: $e');
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });
    }
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
              TextButton(
                onPressed: () {
                  // Check if password is correct (dummy check for now)
                  // In a real app, this would verify with the backend
                  if (passwordController.text == 'password') {
                    Navigator.of(dialogContext).pop();

                    // Show success message
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
                  } else {
                    // Show error for incorrect password
                    setState(() {
                      isPasswordIncorrect = true;
                    });
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

  // Launch URL with simplified approach
  Future<void> _launchURL(String url) async {
    // Show a message instead of launching URLs for now
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening website...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showUrlDialog(String title, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please visit:'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          // Remove system padding at top
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
          ),
          title: const Text(''), // Empty title
          actions: [
            IconButton(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save, color: Colors.black),
              tooltip: 'Save Settings',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab buttons
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                const SizedBox(height: 16),
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.ringPrimary,
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _userData['firstName'],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  _userData['username'].isEmpty
                      ? ''
                      : '@${_userData['username']}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Personal Info Section
          _buildSectionTitle('Personal Information', isBlack: true),
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
              _showUrlDialog(
                  'Visit our YouTube channel', 'https://flutter.dev');
            }),
            _buildActionRow('Terms of Use', onTap: () {
              _showUrlDialog('Terms of Use', 'https://example.com/terms');
            }),
            _buildActionRow('Privacy Policy', onTap: () {
              _showUrlDialog('Privacy Policy', 'https://example.com/privacy');
            }),
            _buildActionRow('Contact Us', onTap: () {
              _showUrlDialog('Visit our website', 'https://google.com');
            }),
            _buildInfoRow('Version', 'v1.0.0', isEditable: false),
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

  Widget _buildSectionTitle(String title, {bool isBlack = false}) {
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
