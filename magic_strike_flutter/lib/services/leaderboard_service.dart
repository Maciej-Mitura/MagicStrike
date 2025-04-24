import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class LeaderboardService {
  // Singleton pattern
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controllers for leaderboard updates
  final StreamController<List<Map<String, dynamic>>>
      _scoreLeaderboardController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>>
      _strikesLeaderboardController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>>
      _averageLeaderboardController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>>
      _deringLeaderboardController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>>
      _strikeStreakLeaderboardController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  // Active listeners to firestore (avoid memory leaks)
  StreamSubscription? _gamesListener;

  // Getters for the leaderboard streams
  Stream<List<Map<String, dynamic>>> get scoreLeaderboardStream =>
      _scoreLeaderboardController.stream;
  Stream<List<Map<String, dynamic>>> get strikesLeaderboardStream =>
      _strikesLeaderboardController.stream;
  Stream<List<Map<String, dynamic>>> get averageLeaderboardStream =>
      _averageLeaderboardController.stream;
  Stream<List<Map<String, dynamic>>> get deringLeaderboardStream =>
      _deringLeaderboardController.stream;
  Stream<List<Map<String, dynamic>>> get strikeStreakLeaderboardStream =>
      _strikeStreakLeaderboardController.stream;

  /// Initializes a real-time listener for leaderboard updates
  void initLeaderboardListener() {
    // Cancel any existing listener
    _gamesListener?.cancel();

    // Calculate the first day of the current month
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final timestamp = Timestamp.fromDate(firstDayOfMonth);

    // Set up a listener for games collection changes
    _gamesListener = _firestore
        .collection('games')
        .where('date', isGreaterThanOrEqualTo: timestamp)
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      // When changes occur, update the leaderboards
      _updateScoreLeaderboardData(snapshot.docs);
      _updateStrikesLeaderboardData(snapshot.docs);
      _updateAverageLeaderboardData(snapshot.docs);
      _updateDeRingLeaderboardData(snapshot.docs);
      _updateStrikeStreakLeaderboardData(snapshot.docs);
    }, onError: (error) {
      print('Error in leaderboard listener: $error');
    });
  }

  /// Updates score leaderboard data based on game documents
  void _updateScoreLeaderboardData(List<QueryDocumentSnapshot> docs) async {
    try {
      // Map to track best score per player
      final Map<String, Map<String, dynamic>> playerBestScores = {};

      // Process all games from this month
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = data['players'] ?? [];

        for (final player in players) {
          if (player is Map &&
              player['userId'] != null &&
              player['firstName'] != null &&
              player['totalScore'] != null) {
            final String userId = player['userId'];
            final int score = player['totalScore'];

            // Check if this is the player's highest score
            if (!playerBestScores.containsKey(userId) ||
                playerBestScores[userId]!['score'] < score) {
              // Create or update player record with profile info and best score
              playerBestScores[userId] = {
                'userId': userId,
                'firstName': player['firstName'],
                'lastName': player['lastName'] ?? '',
                'score': score,
                'profileUrl': player['profileUrl'] ?? '',
              };
            }
          }
        }
      }

      // Convert map to list and sort by score (highest first)
      final List<Map<String, dynamic>> topScores =
          playerBestScores.values.toList();
      topScores.sort((a, b) => b['score'].compareTo(a['score']));

      // Take only the top 5 entries and emit to stream
      final topFiveScores = topScores.take(5).toList();
      _scoreLeaderboardController.add(topFiveScores);
    } catch (e) {
      print('Error updating score leaderboard data: $e');
      _scoreLeaderboardController.add([]);
    }
  }

  /// Updates strikes percentage leaderboard data based on game documents
  void _updateStrikesLeaderboardData(List<QueryDocumentSnapshot> docs) async {
    try {
      // Map to track players and their strikes data
      final Map<String, Map<String, dynamic>> playerStrikesData = {};

      // Process all games from this month
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = data['players'] ?? [];

        for (final player in players) {
          if (player is Map &&
              player['userId'] != null &&
              player['firstName'] != null &&
              player['throwsPerFrame'] != null) {
            final String userId = player['userId'];
            final throwsPerFrame =
                player['throwsPerFrame'] as Map<String, dynamic>;

            // Initialize player record if not exists
            if (!playerStrikesData.containsKey(userId)) {
              playerStrikesData[userId] = {
                'userId': userId,
                'firstName': player['firstName'],
                'lastName': player['lastName'] ?? '',
                'profileUrl': player['profileUrl'] ?? '',
                'totalFrames': 0,
                'strikes': 0,
              };
            }

            // Count strikes for this game
            for (final frameKey in throwsPerFrame.keys) {
              final throws = throwsPerFrame[frameKey] as List<dynamic>;
              if (throws.isNotEmpty) {
                playerStrikesData[userId]!['totalFrames'] =
                    (playerStrikesData[userId]!['totalFrames'] as int) + 1;

                // Check for strike
                if (throws[0] is int && throws[0] == 10) {
                  playerStrikesData[userId]!['strikes'] =
                      (playerStrikesData[userId]!['strikes'] as int) + 1;
                }
              }
            }
          }
        }
      }

      // Calculate strike percentages and filter players with at least 10 frames
      final List<Map<String, dynamic>> strikesData = [];
      playerStrikesData.forEach((userId, data) {
        final int totalFrames = data['totalFrames'];
        final int strikes = data['strikes'];

        // Only include players with sufficient data (at least 10 frames)
        if (totalFrames >= 10) {
          final double percentage = (strikes / totalFrames) * 100;
          strikesData.add({
            ...data,
            'percentage': percentage
                .toInt(), // Simply truncate to int to match StatsService
          });
        }
      });

      // Sort by strike percentage (highest first)
      strikesData.sort((a, b) => b['percentage'].compareTo(a['percentage']));

      // Take only the top 5 entries and emit to stream
      final topFiveStrikers = strikesData.take(5).toList();
      _strikesLeaderboardController.add(topFiveStrikers);
    } catch (e) {
      print('Error updating strikes leaderboard data: $e');
      _strikesLeaderboardController.add([]);
    }
  }

  /// Updates average score leaderboard data based on game documents
  void _updateAverageLeaderboardData(List<QueryDocumentSnapshot> docs) async {
    try {
      // Map to track players and their game data
      final Map<String, Map<String, dynamic>> playerGameData = {};

      // Process all games from this month
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = data['players'] ?? [];

        for (final player in players) {
          if (player is Map &&
              player['userId'] != null &&
              player['firstName'] != null &&
              player['totalScore'] != null) {
            final String userId = player['userId'];
            final int score = player['totalScore'];

            // Initialize player record if not exists
            if (!playerGameData.containsKey(userId)) {
              playerGameData[userId] = {
                'userId': userId,
                'firstName': player['firstName'],
                'lastName': player['lastName'] ?? '',
                'profileUrl': player['profileUrl'] ?? '',
                'totalScore': 0,
                'gameCount': 0,
              };
            }

            // Add to total score and game count
            playerGameData[userId]!['totalScore'] =
                (playerGameData[userId]!['totalScore'] as int) + score;
            playerGameData[userId]!['gameCount'] =
                (playerGameData[userId]!['gameCount'] as int) + 1;
          }
        }
      }

      // Calculate average scores and filter players with at least 3 games
      final List<Map<String, dynamic>> averageData = [];
      playerGameData.forEach((userId, data) {
        final int totalScore = data['totalScore'];
        final int gameCount = data['gameCount'];

        // Only include players with sufficient data (at least 3 games)
        if (gameCount >= 3) {
          final double average = totalScore / gameCount;
          averageData.add({
            ...data,
            'average': average.round(), // Round to nearest integer
          });
        }
      });

      // Sort by average score (highest first)
      averageData.sort((a, b) => b['average'].compareTo(a['average']));

      // Take only the top 5 entries and emit to stream
      final topFiveAverages = averageData.take(5).toList();
      _averageLeaderboardController.add(topFiveAverages);
    } catch (e) {
      print('Error updating average leaderboard data: $e');
      _averageLeaderboardController.add([]);
    }
  }

  /// Updates DeRing score leaderboard data based on game documents
  void _updateDeRingLeaderboardData(List<QueryDocumentSnapshot> docs) async {
    try {
      // Map to track players and all their game data
      final Map<String, Map<String, dynamic>> playerData = {};

      // Process all games from this month
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = data['players'] ?? [];

        for (final player in players) {
          if (player is Map &&
              player['userId'] != null &&
              player['firstName'] != null &&
              player['totalScore'] != null &&
              player['throwsPerFrame'] != null) {
            final String userId = player['userId'];
            final int score = player['totalScore'];
            final throwsPerFrame =
                player['throwsPerFrame'] as Map<String, dynamic>;

            // Initialize player record if not exists
            if (!playerData.containsKey(userId)) {
              playerData[userId] = {
                'userId': userId,
                'firstName': player['firstName'],
                'lastName': player['lastName'] ?? '',
                'profileUrl': player['profileUrl'] ?? '',
                'totalScore': 0,
                'gameCount': 0,
                'totalFrames': 0,
                'strikes': 0,
                'spares': 0,
              };
            }

            // Add to total score and game count
            playerData[userId]!['totalScore'] =
                (playerData[userId]!['totalScore'] as int) + score;
            playerData[userId]!['gameCount'] =
                (playerData[userId]!['gameCount'] as int) + 1;

            // Count strikes and spares for this game
            for (final frameKey in throwsPerFrame.keys) {
              final throws = throwsPerFrame[frameKey] as List<dynamic>;
              if (throws.isNotEmpty) {
                playerData[userId]!['totalFrames'] =
                    (playerData[userId]!['totalFrames'] as int) + 1;

                // Check for strike
                if (throws[0] is int && throws[0] == 10) {
                  playerData[userId]!['strikes'] =
                      (playerData[userId]!['strikes'] as int) + 1;
                }
                // Check for spare (only if not a strike)
                else if (throws.length >= 2 &&
                    throws[0] is int &&
                    throws[1] is int &&
                    throws[0] + throws[1] == 10) {
                  playerData[userId]!['spares'] =
                      (playerData[userId]!['spares'] as int) + 1;
                }
              }
            }
          }
        }
      }

      // Calculate DeRing scores and filter players with at least 3 games
      final List<Map<String, dynamic>> deringData = [];
      playerData.forEach((userId, data) {
        final int totalScore = data['totalScore'];
        final int gameCount = data['gameCount'];
        final int strikes = data['strikes'];
        final int totalFrames = data['totalFrames'];
        final int spares = data['spares'];

        // Only include players with sufficient data (at least 3 games)
        if (gameCount >= 3 && totalFrames >= 10) {
          // Calculate game average
          final double gameAverage = totalScore / gameCount;

          // Calculate strike percentage (0-1 scale)
          final double strikePercentage =
              totalFrames > 0 ? strikes / totalFrames : 0;

          // Calculate average spares per game
          final double sparesPerGame = gameCount > 0 ? spares / gameCount : 0;

          // Calculate DeRing score: (gameAverage * 2) + (strike percentage * 100) + (average spares per game * 100)
          final int deringScore = ((gameAverage * 2) +
                  (strikePercentage * 100) +
                  (sparesPerGame * 100))
              .round();

          deringData.add({
            ...data,
            'deringScore': deringScore,
          });
        }
      });

      // Sort by DeRing score (highest first)
      deringData.sort((a, b) => b['deringScore'].compareTo(a['deringScore']));

      // Take only the top 5 entries and emit to stream
      final topFiveDeRing = deringData.take(5).toList();
      _deringLeaderboardController.add(topFiveDeRing);
    } catch (e) {
      print('Error updating DeRing leaderboard data: $e');
      _deringLeaderboardController.add([]);
    }
  }

  /// Updates strike streak leaderboard data based on game documents
  void _updateStrikeStreakLeaderboardData(
      List<QueryDocumentSnapshot> docs) async {
    try {
      // Map to track players and their best strike streak
      final Map<String, Map<String, dynamic>> playerStreakData = {};

      // Process all games from this month
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = data['players'] ?? [];

        for (final player in players) {
          if (player is Map &&
              player['userId'] != null &&
              player['firstName'] != null &&
              player['throwsPerFrame'] != null) {
            final String userId = player['userId'];
            final throwsPerFrame =
                player['throwsPerFrame'] as Map<String, dynamic>;

            // Initialize player record if not exists
            if (!playerStreakData.containsKey(userId)) {
              playerStreakData[userId] = {
                'userId': userId,
                'firstName': player['firstName'],
                'lastName': player['lastName'] ?? '',
                'profileUrl': player['profileUrl'] ?? '',
                'strikeStreak': 0,
              };
            }

            // Convert to ordered list of frames (by frame number)
            final List<MapEntry<int, List<dynamic>>> orderedFrames = [];
            for (final frameKey in throwsPerFrame.keys) {
              final frameNumber =
                  int.tryParse(frameKey.replaceAll('frame', '')) ?? 0;
              orderedFrames.add(MapEntry(
                  frameNumber, throwsPerFrame[frameKey] as List<dynamic>));
            }

            // Sort frames by frame number
            orderedFrames.sort((a, b) => a.key.compareTo(b.key));

            // Calculate streak in this game
            int currentStreak = 0;
            int gameMaxStreak = 0;

            for (int i = 0; i < orderedFrames.length; i++) {
              final frameEntry = orderedFrames[i];
              final throws = frameEntry.value;
              final frameNumber = frameEntry.key;

              // Check for strike
              if (throws.isNotEmpty && throws[0] is int && throws[0] == 10) {
                currentStreak++;
                if (currentStreak > gameMaxStreak) {
                  gameMaxStreak = currentStreak;
                }

                // Special handling for 10th frame (can have up to 3 strikes)
                if (frameNumber == 10 && throws.length > 1) {
                  // Check for second strike in 10th frame
                  if (throws.length >= 2 &&
                      throws[1] is int &&
                      throws[1] == 10) {
                    currentStreak++;
                    if (currentStreak > gameMaxStreak) {
                      gameMaxStreak = currentStreak;
                    }

                    // Check for third strike in 10th frame
                    if (throws.length >= 3 &&
                        throws[2] is int &&
                        throws[2] == 10) {
                      currentStreak++;
                      if (currentStreak > gameMaxStreak) {
                        gameMaxStreak = currentStreak;
                      }
                    }
                  }
                }
              } else {
                currentStreak = 0; // Reset streak
              }
            }

            // Update player's best streak if this game had a better one
            if (gameMaxStreak > playerStreakData[userId]!['strikeStreak']) {
              playerStreakData[userId]!['strikeStreak'] = gameMaxStreak;
            }
          }
        }
      }

      // Filter players with at least one strike streak
      final List<Map<String, dynamic>> streakData = playerStreakData.values
          .where((data) => data['strikeStreak'] > 0)
          .toList();

      // Sort by strike streak (highest first)
      streakData.sort((a, b) => b['strikeStreak'].compareTo(a['strikeStreak']));

      // Take only the top 5 entries and emit to stream
      final topFiveStreaks = streakData.take(5).toList();
      _strikeStreakLeaderboardController.add(topFiveStreaks);
    } catch (e) {
      print('Error updating strike streak leaderboard data: $e');
      _strikeStreakLeaderboardController.add([]);
    }
  }

  /// Retrieves the top scores for the current month
  Future<List<Map<String, dynamic>>> getTopScoresThisMonth(
      {int limit = 5}) async {
    try {
      // Calculate the first day of the current month
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final timestamp = Timestamp.fromDate(firstDayOfMonth);

      print(
          'Getting top scores for this month (since ${firstDayOfMonth.toIso8601String()})');

      // Query all games from the current month with server-side data (bypass cache)
      final QuerySnapshot querySnapshot = await _firestore
          .collection('games')
          .where('date', isGreaterThanOrEqualTo: timestamp)
          .orderBy('date', descending: true)
          .get(const GetOptions(source: Source.server)); // Force server fetch

      print('Found ${querySnapshot.docs.length} games this month');

      // Map to track best score per player
      final Map<String, Map<String, dynamic>> playerBestScores = {};

      // Process all games from this month
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = data['players'] ?? [];

        for (final player in players) {
          if (player is Map &&
              player['userId'] != null &&
              player['firstName'] != null &&
              player['totalScore'] != null) {
            final String userId = player['userId'];
            final int score = player['totalScore'];

            // Check if this is the player's highest score
            if (!playerBestScores.containsKey(userId) ||
                playerBestScores[userId]!['score'] < score) {
              // Create or update player record with profile info and best score
              playerBestScores[userId] = {
                'userId': userId,
                'firstName': player['firstName'],
                'lastName': player['lastName'] ?? '',
                'score': score,
                'profileUrl': player['profileUrl'] ?? '',
              };
            }
          }
        }
      }

      // Convert map to list and sort by score (highest first)
      final List<Map<String, dynamic>> topScores =
          playerBestScores.values.toList();
      topScores.sort((a, b) => b['score'].compareTo(a['score']));

      // Return only the top 'limit' entries
      return topScores.take(limit).toList();
    } catch (e) {
      print('Error fetching top scores: $e');
      return [];
    }
  }

  /// Retrieves the top strikes percentage players for the current month
  Future<List<Map<String, dynamic>>> getTopStrikesPercentageThisMonth(
      {int limit = 5}) async {
    try {
      // Calculate the first day of the current month
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final timestamp = Timestamp.fromDate(firstDayOfMonth);

      print(
          'Getting top strikers for this month (since ${firstDayOfMonth.toIso8601String()})');

      // Query all games from the current month with server-side data (bypass cache)
      final QuerySnapshot querySnapshot = await _firestore
          .collection('games')
          .where('date', isGreaterThanOrEqualTo: timestamp)
          .orderBy('date', descending: true)
          .get(const GetOptions(source: Source.server)); // Force server fetch

      print(
          'Found ${querySnapshot.docs.length} games this month for strikes analysis');

      // Map to track players and their strikes data
      final Map<String, Map<String, dynamic>> playerStrikesData = {};

      // Process all games from this month
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = data['players'] ?? [];

        for (final player in players) {
          if (player is Map &&
              player['userId'] != null &&
              player['firstName'] != null &&
              player['throwsPerFrame'] != null) {
            final String userId = player['userId'];
            final throwsPerFrame =
                player['throwsPerFrame'] as Map<String, dynamic>;

            // Initialize player record if not exists
            if (!playerStrikesData.containsKey(userId)) {
              playerStrikesData[userId] = {
                'userId': userId,
                'firstName': player['firstName'],
                'lastName': player['lastName'] ?? '',
                'profileUrl': player['profileUrl'] ?? '',
                'totalFrames': 0,
                'strikes': 0,
              };
            }

            // Count strikes for this game
            for (final frameKey in throwsPerFrame.keys) {
              final throws = throwsPerFrame[frameKey] as List<dynamic>;
              if (throws.isNotEmpty) {
                playerStrikesData[userId]!['totalFrames'] =
                    (playerStrikesData[userId]!['totalFrames'] as int) + 1;

                // Check for strike
                if (throws[0] is int && throws[0] == 10) {
                  playerStrikesData[userId]!['strikes'] =
                      (playerStrikesData[userId]!['strikes'] as int) + 1;
                }
              }
            }
          }
        }
      }

      // Calculate strike percentages and filter players with at least 10 frames
      final List<Map<String, dynamic>> strikesData = [];
      playerStrikesData.forEach((userId, data) {
        final int totalFrames = data['totalFrames'];
        final int strikes = data['strikes'];

        // Only include players with sufficient data (at least 10 frames)
        if (totalFrames >= 10) {
          // Use the exact same calculation method as in StatsService
          final double percentage = (strikes / totalFrames) * 100;
          strikesData.add({
            ...data,
            'percentage': percentage
                .toInt(), // Simply truncate to int to match StatsService
          });
        }
      });

      // Sort by strike percentage (highest first)
      strikesData.sort((a, b) => b['percentage'].compareTo(a['percentage']));

      // Take only the top 'limit' entries
      return strikesData.take(limit).toList();
    } catch (e) {
      print('Error fetching top strikers: $e');
      return [];
    }
  }

  /// Retrieves the top average score players for the current month
  Future<List<Map<String, dynamic>>> getTopAverageScoreThisMonth(
      {int limit = 5}) async {
    try {
      // Calculate the first day of the current month
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final timestamp = Timestamp.fromDate(firstDayOfMonth);

      print(
          'Getting top average scores for this month (since ${firstDayOfMonth.toIso8601String()})');

      // Query all games from the current month with server-side data (bypass cache)
      final QuerySnapshot querySnapshot = await _firestore
          .collection('games')
          .where('date', isGreaterThanOrEqualTo: timestamp)
          .orderBy('date', descending: true)
          .get(const GetOptions(source: Source.server)); // Force server fetch

      print(
          'Found ${querySnapshot.docs.length} games this month for average score analysis');

      // Map to track players and their game data
      final Map<String, Map<String, dynamic>> playerGameData = {};

      // Process all games from this month
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = data['players'] ?? [];

        for (final player in players) {
          if (player is Map &&
              player['userId'] != null &&
              player['firstName'] != null &&
              player['totalScore'] != null) {
            final String userId = player['userId'];
            final int score = player['totalScore'];

            // Initialize player record if not exists
            if (!playerGameData.containsKey(userId)) {
              playerGameData[userId] = {
                'userId': userId,
                'firstName': player['firstName'],
                'lastName': player['lastName'] ?? '',
                'profileUrl': player['profileUrl'] ?? '',
                'totalScore': 0,
                'gameCount': 0,
              };
            }

            // Add to total score and game count
            playerGameData[userId]!['totalScore'] =
                (playerGameData[userId]!['totalScore'] as int) + score;
            playerGameData[userId]!['gameCount'] =
                (playerGameData[userId]!['gameCount'] as int) + 1;
          }
        }
      }

      // Calculate average scores and filter players with at least 3 games
      final List<Map<String, dynamic>> averageData = [];
      playerGameData.forEach((userId, data) {
        final int totalScore = data['totalScore'];
        final int gameCount = data['gameCount'];

        // Only include players with sufficient data (at least 3 games)
        if (gameCount >= 3) {
          final double average = totalScore / gameCount;
          averageData.add({
            ...data,
            'average': average.round(), // Round to nearest integer
          });
        }
      });

      // Sort by average score (highest first)
      averageData.sort((a, b) => b['average'].compareTo(a['average']));

      // Take only the top 'limit' entries
      return averageData.take(limit).toList();
    } catch (e) {
      print('Error fetching top average scores: $e');
      return [];
    }
  }

  /// Retrieves the top DeRing score players for the current month
  Future<List<Map<String, dynamic>>> getTopDeRingScoreThisMonth(
      {int limit = 5}) async {
    try {
      // Calculate the first day of the current month
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final timestamp = Timestamp.fromDate(firstDayOfMonth);

      print(
          'Getting top DeRing scores for this month (since ${firstDayOfMonth.toIso8601String()})');

      // Query all games from the current month with server-side data (bypass cache)
      final QuerySnapshot querySnapshot = await _firestore
          .collection('games')
          .where('date', isGreaterThanOrEqualTo: timestamp)
          .orderBy('date', descending: true)
          .get(const GetOptions(source: Source.server)); // Force server fetch

      print(
          'Found ${querySnapshot.docs.length} games this month for DeRing score analysis');

      // Map to track players and their game data
      final Map<String, Map<String, dynamic>> playerData = {};

      // Process all games from this month
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = data['players'] ?? [];

        for (final player in players) {
          if (player is Map &&
              player['userId'] != null &&
              player['firstName'] != null &&
              player['totalScore'] != null &&
              player['throwsPerFrame'] != null) {
            final String userId = player['userId'];
            final int score = player['totalScore'];
            final throwsPerFrame =
                player['throwsPerFrame'] as Map<String, dynamic>;

            // Initialize player record if not exists
            if (!playerData.containsKey(userId)) {
              playerData[userId] = {
                'userId': userId,
                'firstName': player['firstName'],
                'lastName': player['lastName'] ?? '',
                'profileUrl': player['profileUrl'] ?? '',
                'totalScore': 0,
                'gameCount': 0,
                'totalFrames': 0,
                'strikes': 0,
                'spares': 0,
              };
            }

            // Add to total score and game count
            playerData[userId]!['totalScore'] =
                (playerData[userId]!['totalScore'] as int) + score;
            playerData[userId]!['gameCount'] =
                (playerData[userId]!['gameCount'] as int) + 1;

            // Count strikes and spares for this game
            for (final frameKey in throwsPerFrame.keys) {
              final throws = throwsPerFrame[frameKey] as List<dynamic>;
              if (throws.isNotEmpty) {
                playerData[userId]!['totalFrames'] =
                    (playerData[userId]!['totalFrames'] as int) + 1;

                // Check for strike
                if (throws[0] is int && throws[0] == 10) {
                  playerData[userId]!['strikes'] =
                      (playerData[userId]!['strikes'] as int) + 1;
                }
                // Check for spare (only if not a strike)
                else if (throws.length >= 2 &&
                    throws[0] is int &&
                    throws[1] is int &&
                    throws[0] + throws[1] == 10) {
                  playerData[userId]!['spares'] =
                      (playerData[userId]!['spares'] as int) + 1;
                }
              }
            }
          }
        }
      }

      // Calculate DeRing scores and filter players with at least 3 games
      final List<Map<String, dynamic>> deringData = [];
      playerData.forEach((userId, data) {
        final int totalScore = data['totalScore'];
        final int gameCount = data['gameCount'];
        final int strikes = data['strikes'];
        final int totalFrames = data['totalFrames'];
        final int spares = data['spares'];

        // Only include players with sufficient data (at least 3 games)
        if (gameCount >= 3 && totalFrames >= 10) {
          // Calculate game average
          final double gameAverage = totalScore / gameCount;

          // Calculate strike percentage (0-1 scale)
          final double strikePercentage =
              totalFrames > 0 ? strikes / totalFrames : 0;

          // Calculate average spares per game
          final double sparesPerGame = gameCount > 0 ? spares / gameCount : 0;

          // Calculate DeRing score: (gameAverage * 2) + (strike percentage * 100) + (average spares per game * 100)
          final int deringScore = ((gameAverage * 2) +
                  (strikePercentage * 100) +
                  (sparesPerGame * 100))
              .round();

          deringData.add({
            ...data,
            'deringScore': deringScore,
          });
        }
      });

      // Sort by DeRing score (highest first)
      deringData.sort((a, b) => b['deringScore'].compareTo(a['deringScore']));

      // Return only the top 'limit' entries
      return deringData.take(limit).toList();
    } catch (e) {
      print('Error fetching top DeRing scores: $e');
      return [];
    }
  }

  /// Retrieves the top strike streak players for the current month
  Future<List<Map<String, dynamic>>> getTopStrikeStreakThisMonth(
      {int limit = 5}) async {
    try {
      // Calculate the first day of the current month
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final timestamp = Timestamp.fromDate(firstDayOfMonth);

      print(
          'Getting top strike streak for this month (since ${firstDayOfMonth.toIso8601String()})');

      // Query all games from the current month with server-side data (bypass cache)
      final QuerySnapshot querySnapshot = await _firestore
          .collection('games')
          .where('date', isGreaterThanOrEqualTo: timestamp)
          .orderBy('date', descending: true)
          .get(const GetOptions(source: Source.server)); // Force server fetch

      print(
          'Found ${querySnapshot.docs.length} games this month for strike streak analysis');

      // Map to track players and their best strike streak
      final Map<String, Map<String, dynamic>> playerStreakData = {};

      // Process all games from this month
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = data['players'] ?? [];

        for (final player in players) {
          if (player is Map &&
              player['userId'] != null &&
              player['firstName'] != null &&
              player['throwsPerFrame'] != null) {
            final String userId = player['userId'];
            final throwsPerFrame =
                player['throwsPerFrame'] as Map<String, dynamic>;

            // Initialize player record if not exists
            if (!playerStreakData.containsKey(userId)) {
              playerStreakData[userId] = {
                'userId': userId,
                'firstName': player['firstName'],
                'lastName': player['lastName'] ?? '',
                'profileUrl': player['profileUrl'] ?? '',
                'strikeStreak': 0,
              };
            }

            // Convert to ordered list of frames (by frame number)
            final List<MapEntry<int, List<dynamic>>> orderedFrames = [];
            for (final frameKey in throwsPerFrame.keys) {
              final frameNumber =
                  int.tryParse(frameKey.replaceAll('frame', '')) ?? 0;
              orderedFrames.add(MapEntry(
                  frameNumber, throwsPerFrame[frameKey] as List<dynamic>));
            }

            // Sort frames by frame number
            orderedFrames.sort((a, b) => a.key.compareTo(b.key));

            // Calculate streak in this game
            int currentStreak = 0;
            int gameMaxStreak = 0;

            for (int i = 0; i < orderedFrames.length; i++) {
              final frameEntry = orderedFrames[i];
              final throws = frameEntry.value;
              final frameNumber = frameEntry.key;

              // Check for strike
              if (throws.isNotEmpty && throws[0] is int && throws[0] == 10) {
                currentStreak++;
                if (currentStreak > gameMaxStreak) {
                  gameMaxStreak = currentStreak;
                }

                // Special handling for 10th frame (can have up to 3 strikes)
                if (frameNumber == 10 && throws.length > 1) {
                  // Check for second strike in 10th frame
                  if (throws.length >= 2 &&
                      throws[1] is int &&
                      throws[1] == 10) {
                    currentStreak++;
                    if (currentStreak > gameMaxStreak) {
                      gameMaxStreak = currentStreak;
                    }

                    // Check for third strike in 10th frame
                    if (throws.length >= 3 &&
                        throws[2] is int &&
                        throws[2] == 10) {
                      currentStreak++;
                      if (currentStreak > gameMaxStreak) {
                        gameMaxStreak = currentStreak;
                      }
                    }
                  }
                }
              } else {
                currentStreak = 0; // Reset streak
              }
            }

            // Update player's best streak if this game had a better one
            if (gameMaxStreak > playerStreakData[userId]!['strikeStreak']) {
              playerStreakData[userId]!['strikeStreak'] = gameMaxStreak;
            }
          }
        }
      }

      // Filter players with at least one strike streak
      final List<Map<String, dynamic>> streakData = playerStreakData.values
          .where((data) => data['strikeStreak'] > 0)
          .toList();

      // Sort by strike streak (highest first)
      streakData.sort((a, b) => b['strikeStreak'].compareTo(a['strikeStreak']));

      // Return only the top 'limit' entries
      return streakData.take(limit).toList();
    } catch (e) {
      print('Error fetching top strike streaks: $e');
      return [];
    }
  }

  // Clean up resources when no longer needed
  void dispose() {
    _gamesListener?.cancel();
    _scoreLeaderboardController.close();
    _strikesLeaderboardController.close();
    _averageLeaderboardController.close();
    _deringLeaderboardController.close();
    _strikeStreakLeaderboardController.close();
  }
}
