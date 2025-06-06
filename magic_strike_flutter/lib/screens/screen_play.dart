import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/screens/screen_start_game.dart';
import 'package:magic_strike_flutter/screens/screen_live_tracking.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * 0.8;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24), // Space after logo app bar

              // "Let's Bowl!" title
              Center(
                child: Text(
                  "Let's Bowl!",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ringPrimary,
                  ),
                ),
              ),
              const SizedBox(
                  height: 4), // Reduced space between title and subtitle

              // Subtitle
              const Center(
                child: Text(
                  "Add games to your profile or watch games that are currently being played",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black,
                  ),
                ),
              ),

              const SizedBox(height: 60), // Added more space after subtitle

              // Buttons with vertical alignment and top padding instead of center
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Start a game button with scale animation
                      TapScaleButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StartGameScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: buttonWidth,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          decoration: BoxDecoration(
                            color: AppColors.ringBackground3rd,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FaIcon(
                                FontAwesomeIcons.bowlingBall,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Play a game",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Live tracking button with scale animation
                      TapScaleButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LiveTrackingScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: buttonWidth,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          decoration: BoxDecoration(
                            color: AppColors.ringBackground3rd,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.visibility,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Live tracking",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Add some empty space at the bottom
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom widget that scales down slightly when tapped
class TapScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const TapScaleButton({
    super.key,
    required this.child,
    required this.onPressed,
  });

  @override
  State<TapScaleButton> createState() => _TapScaleButtonState();
}

class _TapScaleButtonState extends State<TapScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0, // Scale down to 95% when pressed
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
