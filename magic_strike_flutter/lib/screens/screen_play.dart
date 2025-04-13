import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/main.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  bool _showContent = false;

  void _hideAppBarLogo() {
    // Use the global key to access the HomePage state
    homePageKey.currentState?.toggleLogoVisibility(false);
  }

  void _showAppBarLogo() {
    // Use the global key to access the HomePage state
    homePageKey.currentState?.toggleLogoVisibility(true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_showContent) {
      // Initial view with a button
      return Center(
        child: ElevatedButton(
          onPressed: () {
            _hideAppBarLogo();
            setState(() {
              _showContent = true;
            });
          },
          child: const Text('Start Playing'),
        ),
      );
    } else {
      // Content view after button is clicked
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Game Content Goes Here',
                style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showContent = false;
                });
                _showAppBarLogo();
              },
              child: const Text('Back'),
            ),
          ],
        ),
      );
    }
  }
}
