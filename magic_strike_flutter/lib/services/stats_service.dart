import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_service.dart';

class StatsService {
  // Singleton pattern
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final UserService _userService = UserService();

  /// Retrieves games for the current user for statistics calculations
  /// Limits to the 100 most recent games for performance
  Future<List<Map<String, dynamic>>> getUserGames() async {
    try {
      // Get current user's deRingID and firstName
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        print('getUserGames: Missing deRingID or firstName');
        return [];
      }

      print('getUserGames: Fetching games for user $deRingID ($firstName)');

      // Query all games, sorted by date
      final QuerySnapshot querySnapshot = await _firestore
          .collection('games')
          .orderBy('date', descending: true)
          .limit(100)
          .get();

      print('getUserGames: Found ${querySnapshot.docs.length} total games');

      // Filter games where the current user is a participant
      final List<Map<String, dynamic>> userGames = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = data['players'] ?? [];

        // Check if current user is a participant by matching both deRingID and firstName
        bool isParticipant = false;
        for (final player in players) {
          if (player is Map &&
              player['userId'] == deRingID &&
              player['firstName'] == firstName) {
            isParticipant = true;
            break;
          }
        }

        if (isParticipant) {
          userGames.add({
            'id': doc.id,
            ...data,
          });
        }
      }

      print(
          'getUserGames: Found ${userGames.length} games for user $deRingID ($firstName)');
      return userGames;
    } catch (e) {
      print('Error fetching user games: $e');
      return [];
    }
  }

  /// Calculates the user's average score based on their games
  Future<int> calculateAverageScore() async {
    try {
      final games = await getUserGames();
      if (games.isEmpty) {
        return 0;
      }

      // Get current user's deRingID and firstName
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        return 0;
      }

      int totalScore = 0;
      int gamesCount = 0;

      for (final game in games) {
        final players = game['players'] as List<dynamic>;
        for (final player in players) {
          if (player is Map &&
              player['userId'] == deRingID &&
              player['firstName'] == firstName &&
              player['totalScore'] != null) {
            totalScore += (player['totalScore'] as int);
            gamesCount++;
          }
        }
      }

      if (gamesCount == 0) {
        return 0;
      }

      return totalScore ~/ gamesCount;
    } catch (e) {
      print('Error calculating average score: $e');
      return 0;
    }
  }

  /// Gets the user's highest score from all their games
  Future<int> getBestScore() async {
    try {
      final games = await getUserGames();
      if (games.isEmpty) {
        return 0;
      }

      // Get current user's deRingID and firstName
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        return 0;
      }

      int bestScore = 0;

      for (final game in games) {
        final players = game['players'] as List<dynamic>;
        for (final player in players) {
          if (player is Map &&
              player['userId'] == deRingID &&
              player['firstName'] == firstName &&
              player['totalScore'] != null) {
            final score = player['totalScore'] as int;
            if (score > bestScore) {
              bestScore = score;
            }
          }
        }
      }

      return bestScore;
    } catch (e) {
      print('Error calculating best score: $e');
      return 0;
    }
  }

  /// Gets the scores from the user's most recent games
  Future<List<int>> getRecentScores(int limit) async {
    try {
      final games = await getUserGames();
      if (games.isEmpty) {
        return [];
      }

      // Get current user's deRingID and firstName
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        return [];
      }

      // Create a list to store scores with game dates
      final List<Map<String, dynamic>> scoresWithDates = [];

      for (final game in games) {
        final players = game['players'] as List<dynamic>;
        final gameDate = game['date'] as Timestamp;

        for (final player in players) {
          if (player is Map &&
              player['userId'] == deRingID &&
              player['firstName'] == firstName &&
              player['totalScore'] != null) {
            scoresWithDates.add({
              'score': player['totalScore'] as int,
              'date': gameDate,
            });
          }
        }
      }

      // Sort by date (newest first)
      scoresWithDates.sort(
          (a, b) => (b['date'] as Timestamp).compareTo(a['date'] as Timestamp));

      // Take only the most recent scores up to the limit
      final List<int> recentScores = [];
      for (int i = 0; i < scoresWithDates.length && i < limit; i++) {
        recentScores.add(scoresWithDates[i]['score'] as int);
      }

      // Reverse to show oldest to newest (left to right on graph)
      return recentScores.reversed.toList();
    } catch (e) {
      print('Error retrieving recent scores: $e');
      return [];
    }
  }

  /// Calculate first ball statistics (strikes, spares, etc.)
  Future<Map<String, double>> getFirstBallStats() async {
    try {
      final games = await getUserGames();
      if (games.isEmpty) {
        // Return default values if no games
        return {
          'strikes': 0.0,
          'leaves': 0.0,
        };
      }

      // Get current user's deRingID and firstName
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        return {
          'strikes': 0.0,
          'leaves': 0.0,
        };
      }

      int totalFrames = 0;
      int strikes = 0;
      int leaves = 0;

      for (final game in games) {
        final players = game['players'] as List<dynamic>;
        for (final player in players) {
          if (player is Map &&
              player['userId'] == deRingID &&
              player['firstName'] == firstName &&
              player['throwsPerFrame'] != null) {
            final throwsPerFrame =
                player['throwsPerFrame'] as Map<String, dynamic>;

            // Process each frame
            for (final frameKey in throwsPerFrame.keys) {
              final throws = throwsPerFrame[frameKey] as List<dynamic>;
              if (throws.isNotEmpty) {
                totalFrames++;

                // Check for strike
                if (throws[0] is int && throws[0] == 10) {
                  strikes++;
                }
                // Check for leaves - when pins are still standing after both throws
                else if (throws.length >= 2 &&
                    throws[0] is int &&
                    throws[1] is int &&
                    throws[0] + throws[1] < 10) {
                  leaves++;
                }
              }
            }
          }
        }
      }

      // Calculate percentages
      // If no frames were recorded, return default values
      if (totalFrames == 0) {
        return {
          'strikes': 0.0,
          'leaves': 0.0,
        };
      }

      return {
        'strikes': (strikes / totalFrames) * 100,
        'leaves': (leaves / totalFrames) * 100,
      };
    } catch (e) {
      print('Error calculating first ball stats: $e');
      return {
        'strikes': 0.0,
        'leaves': 0.0,
      };
    }
  }

  /// Calculate clean percentage (frames with strikes or spares)
  Future<int> calculateCleanPercentage() async {
    try {
      final games = await getUserGames();
      if (games.isEmpty) {
        return 0;
      }

      // Get current user's deRingID and firstName
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        return 0;
      }

      int totalFrames = 0;
      int cleanFrames = 0; // frames with strikes or spares

      for (final game in games) {
        final players = game['players'] as List<dynamic>;
        for (final player in players) {
          if (player is Map &&
              player['userId'] == deRingID &&
              player['firstName'] == firstName &&
              player['throwsPerFrame'] != null) {
            final throwsPerFrame =
                player['throwsPerFrame'] as Map<String, dynamic>;

            // Process each frame
            for (final frameKey in throwsPerFrame.keys) {
              final throws = throwsPerFrame[frameKey] as List<dynamic>;
              totalFrames++;

              // Check for strike
              if (throws.isNotEmpty && throws[0] is int && throws[0] == 10) {
                cleanFrames++;
              }
              // Check for spare
              else if (throws.length >= 2 &&
                  throws[0] is int &&
                  throws[1] is int &&
                  throws[0] + throws[1] == 10) {
                cleanFrames++;
              }
            }
          }
        }
      }

      if (totalFrames == 0) {
        return 0;
      }

      // Calculate percentage and round to nearest integer
      return ((cleanFrames / totalFrames) * 100).round();
    } catch (e) {
      print('Error calculating clean percentage: $e');
      return 0;
    }
  }

  /// Calculate total number of games played
  Future<int> getGamesPlayed() async {
    try {
      final games = await getUserGames();
      return games.length;
    } catch (e) {
      print('Error calculating games played: $e');
      return 0;
    }
  }
}
