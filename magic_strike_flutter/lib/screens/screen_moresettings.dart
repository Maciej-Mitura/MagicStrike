import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screen_auth_choice.dart';

class MoreSettingsScreen extends StatefulWidget {
  const MoreSettingsScreen({super.key});

  @override
  State<MoreSettingsScreen> createState() => _MoreSettingsScreenState();
}

class _MoreSettingsScreenState extends State<MoreSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock user data - would be fetched from Firebase in real app
  final Map<String, dynamic> _userData = {
    'username': 'JohnDoe123',
    'firstName': 'John',
    'lastName': 'Doe',
    'dateOfBirth': '15/05/1990',
    'gender': 'Male',
    'deRingID': 'DR78901',
    'clubTeam': 'Strike Force',
    'email': 'john.doe@example.com',
    'password': '••••••••',
    'bowlingSide': 'Right',
    'bowlingStyle': 'Single-handed',
    'memberSince': '10/01/2023',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    // Show a snackbar to indicate settings were saved
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully'),
        duration: Duration(seconds: 2),
      ),
    );
    // Here you would save the data to Firebase
  }

  void _showEditDialog(String field, String currentValue) {
    final TextEditingController controller =
        TextEditingController(text: currentValue);

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
            onPressed: () {
              setState(() {
                _userData[field.toLowerCase().replaceAll(' ', '')] =
                    controller.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSelectionDialog(
      String field, List<String> options, String currentValue) {
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
                  onChanged: (value) {
                    setState(() {
                      _userData[field.toLowerCase().replaceAll(' ', '')] =
                          value;
                    });
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

  void _logOut() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Close the dialog
                Navigator.pop(dialogContext);

                try {
                  // Sign out from Firebase
                  await FirebaseAuth.instance.signOut();

                  // Navigate to auth choice screen and remove all previous routes
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AuthChoiceScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  // Show error if logout fails
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Logout failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.ringPrimary,
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
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
      body: Column(
        children: [
          // Tab buttons
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  _userData['username'],
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

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
            _buildInfoRow('deRingID', _userData['deRingID'],
                onTap: () =>
                    _showEditDialog('deRingID', _userData['deRingID'])),
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
              onPressed: _logOut,
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
              // Would open YouTube tutorials
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening YouTube tutorials...')),
              );
            }),
            _buildActionRow('Terms of Use', onTap: () {
              // Would open terms of use
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening Terms of Use...')),
              );
            }),
            _buildActionRow('Privacy Policy', onTap: () {
              // Would open privacy policy
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening Privacy Policy...')),
              );
            }),
            _buildActionRow('Contact Us', onTap: () {
              // Would open contact form or email
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening Contact Form...')),
              );
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.ringPrimary,
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
