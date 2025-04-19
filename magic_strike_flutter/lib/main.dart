import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/services/internet_connection.dart';
import 'widgets/footer_navigation.dart';
import 'screens/screen_home.dart';
import 'screens/screen_gameshistory.dart';
import 'screens/screen_moresettings.dart';
import 'screens/screen_stats.dart';
import 'screens/screen_play.dart';
import 'widgets/auth_gate.dart'; // Import AuthGate

//Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // if using FlutterFire CLI

// Create a global key to access the HomePage state
final GlobalKey<HomePageState> homePageKey = GlobalKey<HomePageState>();
s
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Disable the debug banner
      home: const AuthGate(), // Use AuthGate instead of AuthChoiceScreen
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

  final List<Widget> _screens = [
    HomeScreen(),
    StatsScreen(),
    const PlayScreen(),
    GamesHistoryScreen(),
    MoreSettingsScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Method to determine if app bar with logo should be shown
  PreferredSizeWidget? _buildAppBar() {
    // Show logo for Home (0), Stats (1), Games History (3) screens,
    // always for Play screen (2), and never for More screen (4)
    if (_selectedIndex == 0 ||
        _selectedIndex == 1 ||
        _selectedIndex == 2 ||
        _selectedIndex == 3) {
      return AppBar(
        backgroundColor: Colors.white,
        title: Padding(
          padding: const EdgeInsets.only(top: 24.0),
          child: Image.asset(
            'assets/MyLogoRing.png',
            height: 100,
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: true,
        toolbarHeight: 142,
      );
    } else {
      // No AppBar for the More screen (index 4)
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: ConnectivityWrapper(
        child: SafeArea(
          bottom:
              false, // Don't add bottom padding as it would double with the navbar
          child: IndexedStack(
            index: _selectedIndex,
            children: _screens,
          ),
        ),
      ),
      bottomNavigationBar: FooterNav(
        currentIndex: _selectedIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
