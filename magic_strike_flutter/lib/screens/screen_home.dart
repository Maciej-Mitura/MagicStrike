import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _latestGames = [];
  bool _isLoading = true;
  bool _hasError = false;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _fetchLatestGames();
  }

  /// Fetch the latest games from Firestore
  Future<void> _fetchLatestGames() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final games = await _firestoreService.getLatestGames();

      // Debug the game data structure
      if (games.isNotEmpty) {
        print('Sample game structure:');
        print('Date: ${games[0]['date']}');
        print('Location: ${games[0]['location']}');
        print('Players: ${games[0]['players']}');

        if (games[0]['players'] != null &&
            (games[0]['players'] as List).isNotEmpty) {
          final firstPlayer = (games[0]['players'] as List).first;
          print('Player structure: $firstPlayer');
          print('Throws per frame: ${firstPlayer['throwsPerFrame']}');
        }
      }

      setState(() {
        _latestGames = games;
        _isLoading = false;
      });

      // Show a success message if manually refreshed (not on initial load)
      if (mounted && !_isInitialLoad) {
        _showFeedbackMessage('Games refreshed');
      }

      // Set initial load to false after first load
      _isInitialLoad = false;
    } catch (e) {
      print('Error in HomeScreen: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });

      // Show error message, even on initial load
      if (mounted) {
        _showFeedbackMessage('Error refreshing games', isError: true);
      }

      // Set initial load to false after first load, even on error
      _isInitialLoad = false;
    }
  }

  /// Shows a quick feedback message to the user
  void _showFeedbackMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? Colors.red : AppColors.ringPrimary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate the width and height of the game card
    final cardWidth = screenWidth * 0.85; // 85% of screen width

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Fixed app bar that doesn't scroll
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(
                left: 24.0, right: 24.0, top: 50.0, bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Latest games',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Transform.translate(
                        offset: const Offset(0, 2),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.grey[600],
                                      strokeWidth: 2.0,
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      Icons.refresh,
                                      color: Colors.grey[600],
                                      size: 24,
                                    ),
                                    onPressed: _fetchLatestGames,
                                    tooltip: 'Refresh games',
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
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

          // Scrollable content below the fixed app bar
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading games',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _fetchLatestGames,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.ringPrimary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : _latestGames.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sports_score,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No games found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Play some games to see them here',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetchLatestGames,
                            color: AppColors.ringPrimary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  24.0, 8.0, 24.0, 24.0),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _latestGames.length,
                              itemBuilder: (context, index) {
                                final game = _latestGames[index];

                                // Format timestamp to readable date
                                String formattedDate = 'N/A';
                                try {
                                  if (game['date'] is Timestamp) {
                                    final timestamp = game['date'] as Timestamp;
                                    final date = timestamp.toDate();
                                    formattedDate = _dateFormat.format(date);
                                  } else if (game['date'] is String) {
                                    // If it's already a string, use it directly
                                    formattedDate = game['date'] as String;
                                  }
                                } catch (e) {
                                  print('Error formatting date: $e');
                                }

                                // Extract players data safely
                                List<dynamic> players = [];
                                try {
                                  if (game['players'] is List) {
                                    players = game['players'] as List<dynamic>;
                                  }
                                } catch (e) {
                                  print('Error extracting players: $e');
                                }

                                // If no players found, create a placeholder
                                if (players.isEmpty) {
                                  players = [
                                    {'name': 'No player data', 'totalScore': 0}
                                  ];
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 16.0), // Gap between cards
                                  child: Container(
                                    width: cardWidth,
                                    // Set height based on player count plus space for header
                                    // Use a minimum height of 125 and dynamic height based on player count
                                    height: max(
                                        125.0, 90.0 + (players.length * 35.0)),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12.0),
                                      border: Border.all(
                                        color: AppColors.ringPrimary,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                          12.0), // Reduce padding
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Game date at the top
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom:
                                                    8.0), // Reduced bottom padding
                                            child: Text(
                                              formattedDate,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.normal,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),

                                          // Frames grid with player names
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                    2.0), // Reduced padding even more
                                                child:
                                                    _buildFramesGrid(players),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// Build frames grid for players
  Widget _buildFramesGrid(List<dynamic> players) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // Decrease name column width to 15% to give more space to frames
        final nameColumnWidth = availableWidth * 0.15;
        // Allocate width for frames (80%) and total score column (5%)
        final framesWidth = availableWidth * 0.80;
        final totColumnWidth = availableWidth * 0.05;
        // Calculate frame width from available frames space
        final frameWidth = (framesWidth / 10) - 1; // Account for spacing
        // Calculate a proper frame height that won't overflow
        final frameHeight = frameWidth * 0.9; // Slightly shorter than width

        // Create a row of frame numbers at the top
        final frameHeaders = Row(
          children: [
            // Empty space above player names
            SizedBox(width: nameColumnWidth),
            // Frame numbers
            SizedBox(
              width: framesWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(10, (frameIndex) {
                  return SizedBox(
                    width: frameWidth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: const BoxDecoration(
                        color: AppColors.ringPrimary,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
                        ),
                      ),
                      child: Text(
                        '${frameIndex + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Total score header
            Container(
              width: totColumnWidth,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.ringPrimary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(3),
                  topRight: Radius.circular(3),
                ),
              ),
              child: const Text(
                'T',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );

        // Create player rows with name and frames
        final playerRows = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(players.length, (playerIndex) {
            final player = players[playerIndex];

            // Safely extract player name - default to User ID if available
            String playerName = 'Unknown';
            if (player is Map) {
              playerName = player['firstName'] as String? ??
                  player['userId'] as String? ??
                  'Player ${playerIndex + 1}';
            }

            // Safely extract score with fallback
            final totalScore = player is Map ? (player['totalScore'] ?? 0) : 0;

            // Process the throwsPerFrame to convert to compatible frames format
            final Map<String, dynamic> throwsPerFrame = {};
            if (player is Map && player['throwsPerFrame'] is Map) {
              throwsPerFrame
                  .addAll(player['throwsPerFrame'] as Map<String, dynamic>);
            }

            final List<List<dynamic>> frames = [];

            // Process throwsPerFrame into visual format
            for (int i = 1; i <= 10; i++) {
              final frameKey = i.toString();
              if (throwsPerFrame.containsKey(frameKey) &&
                  throwsPerFrame[frameKey] is List) {
                List<dynamic> throwValues =
                    throwsPerFrame[frameKey] as List<dynamic>;
                List<dynamic> formattedThrows = [];

                // Convert numeric throws to string representation
                for (int j = 0; j < throwValues.length; j++) {
                  final throwValue = throwValues[j];
                  if (throwValue is int) {
                    if (throwValue == 10 && (j == 0 || i == 10)) {
                      // Strike
                      formattedThrows.add('X');
                    } else if (j == 1 &&
                        throwValues[0] is int &&
                        throwValues[0] + throwValue == 10) {
                      // Spare
                      formattedThrows.add('/');
                    } else if (throwValue == 0) {
                      // Miss
                      formattedThrows.add('-');
                    } else {
                      // Regular pins
                      formattedThrows.add(throwValue.toString());
                    }
                  } else {
                    // If the throwValue is not an int, just convert to string
                    formattedThrows.add(throwValue.toString());
                  }
                }

                frames.add(formattedThrows);
              } else {
                frames.add([]);
              }
            }

            // Display the full name without manual shortening
            String displayName = playerName;

            return Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 1.0), // Minimal vertical padding
              child: Row(
                children: [
                  // Player name column
                  SizedBox(
                    width: nameColumnWidth,
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),

                  // Player frames
                  SizedBox(
                    width: framesWidth,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(10, (frameIndex) {
                        // Get the frame data
                        List<dynamic> frame = frames.length > frameIndex
                            ? frames[frameIndex]
                            : [];

                        // For the 10th frame which may have 3 throws
                        bool isTenthFrame = frameIndex == 9;
                        bool isStrike = frame.isNotEmpty && frame[0] == 'X';
                        bool hasThirdThrow = isTenthFrame && frame.length > 2;

                        return SizedBox(
                          width: frameWidth,
                          child: SizedBox(
                            height: frameHeight, // Use calculated height
                            child: Container(
                              margin: const EdgeInsets.all(
                                  0.5), // Very small margin
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(2), // Smaller radius
                                border: Border.all(
                                  color: AppColors.ringPrimary,
                                  width: 0.5,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // First throw - centered in the box
                                  Positioned.fill(
                                    child: Center(
                                      child: Text(
                                        frame.isNotEmpty ? frame[0] : '',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.normal,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Second throw - top right corner
                                  if ((frame.length > 1 && !isStrike) ||
                                      (isTenthFrame && frame.length > 1))
                                    Positioned(
                                      top: 1,
                                      right: 1,
                                      child: Container(
                                        width: frameWidth * 0.3,
                                        height: frameWidth * 0.3,
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                        child: Center(
                                          child: Text(
                                            frame[1],
                                            style: const TextStyle(
                                              fontSize: 7,
                                              fontWeight: FontWeight.normal,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Third throw (10th frame only)
                                  if (hasThirdThrow)
                                    Positioned(
                                      bottom: 1,
                                      right: 1,
                                      child: Container(
                                        width: frameWidth * 0.3,
                                        height: frameWidth * 0.3,
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                        child: Center(
                                          child: Text(
                                            frame[2],
                                            style: const TextStyle(
                                              fontSize: 7,
                                              fontWeight: FontWeight.normal,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Score after frames
                  Container(
                    width: totColumnWidth,
                    height: frameHeight, // Match height of frame
                    padding: EdgeInsets.zero,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$totalScore',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        );

        // Combine the frame headers and player rows
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            frameHeaders,
            const SizedBox(height: 2),
            Expanded(child: playerRows),
          ],
        );
      },
    );
  }
}
