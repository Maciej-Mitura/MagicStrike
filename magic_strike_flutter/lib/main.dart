import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/services/internet_connection.dart';
import 'widgets/footer_navigation.dart';
import 'screens/screen_home.dart';
import 'screens/screen_gameshistory.dart';
import 'screens/screen_moresettings.dart';
import 'screens/screen_stats.dart';
import 'screens/screen_play.dart';
import 'screens/screen_auth_choice.dart';

// Create a global key to access the HomePage state
final GlobalKey<HomePageState> homePageKey = GlobalKey<HomePageState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Disable the debug banner
      home: const AuthChoiceScreen(), // Start with the auth choice screen
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _showLogoInPlayScreen = true;

  // Method to toggle logo visibility in play screen that can be called from outside
  void toggleLogoVisibility(bool show) {
    setState(() {
      _showLogoInPlayScreen = show;
    });
  }

  final List<Widget> _screens = [
    HomeScreen(),
    StatsScreen(),
    PlayScreen(),
    GamesHistoryScreen(),
    MoreSettingsScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Reset play screen logo visibility when navigating to play screen
      if (index == 2) {
        // Play screen index
        _showLogoInPlayScreen = true;
      }
    });
  }

  // Method to determine if app bar with logo should be shown
  PreferredSizeWidget? _buildAppBar() {
    // Show logo for Home (0), Stats (1), Games History (3) screens,
    // conditionally for Play screen (2), and never for More screen (4)
    if (_selectedIndex == 0 ||
        _selectedIndex == 1 ||
        _selectedIndex == 3 ||
        (_selectedIndex == 2 && _showLogoInPlayScreen)) {
      return AppBar(
        backgroundColor: Colors.white, // Changed back to white
        title: Padding(
          padding: const EdgeInsets.only(
              top: 24.0), // Increased top padding from 8 to 24
          child: Image.asset(
            'assets/MyLogoRing.png',
            height: 100,
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: true,
        toolbarHeight: 142, // Decreased from 158 to 142 (reduced by 16)
      );
    } else if (_selectedIndex == 4) {
      // For More screen, return an app bar without logo
      return AppBar(
        backgroundColor: Colors.white, // Changed back to white
        toolbarHeight: 142, // Decreased from 158 to 142 (reduced by 16)
      );
    } else {
      // For Play screen when logo should be hidden
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: ConnectivityWrapper(
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: FooterNav(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
