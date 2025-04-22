import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';
import 'user_service.dart';

class GameHistoryService {
  // Singleton pattern
  static final GameHistoryService _instance = GameHistoryService._internal();
  factory GameHistoryService() => _instance;
  GameHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final UserService _userService = UserService();

  // Date formatters
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  final DateFormat _timeFormatter = DateFormat('HH:mm');

  /// Retrieves detailed game history for the current user
  /// Includes pagination with specified batch size
  Future<List<Map<String, dynamic>>> getGameHistory({
    DocumentSnapshot? lastDocument,
    int batchSize = 5,
  }) async {
    try {
      // Get current user's deRingID and firstName
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        print('getGameHistory: Missing deRingID or firstName');
        return [];
      }

      print('getGameHistory: Fetching games for user $deRingID ($firstName)');

      // Create initial query, sorted by date descending (newest first)
      Query query =
          _firestore.collection('games').orderBy('date', descending: true);

      // Apply pagination if lastDocument is provided
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      // Limit the number of results
      query = query.limit(batchSize);

      // Execute the query
      final QuerySnapshot querySnapshot = await query.get();

      print('getGameHistory: Found ${querySnapshot.docs.length} total games');

      // Filter games where the current user is a participant
      final List<Map<String, dynamic>> userGames = [];

      for (final doc in querySnapshot.docs) {
        final gameData = doc.data() as Map<String, dynamic>;
        final List<dynamic> players = gameData['players'] ?? [];

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
          // Format date and time
          String formattedDate = 'N/A';
          String formattedTime = 'N/A';

          if (gameData['date'] is Timestamp) {
            final timestamp = gameData['date'] as Timestamp;
            final date = timestamp.toDate();
            formattedDate = _dateFormatter.format(date);
            formattedTime = _timeFormatter.format(date);
          }

          // Calculate duration from the duration field (in seconds)
          String duration = 'N/A';
          if (gameData['duration'] != null) {
            // Use the duration field directly (already in seconds)
            final int durationSeconds = gameData['duration'] is int
                ? gameData['duration']
                : int.tryParse(gameData['duration'].toString()) ?? 0;

            // Calculate hours and minutes
            final int hours = durationSeconds ~/ 3600;
            final int minutes = (durationSeconds % 3600) ~/ 60;

            // Format as hours:minutes
            if (hours > 0) {
              duration = '$hours:${minutes.toString().padLeft(2, '0')}';
            } else {
              duration = '$minutes min';
            }
          } else if (gameData['startTime'] is Timestamp &&
              gameData['finishedAt'] is Timestamp) {
            // Fallback to calculating from timestamps if available
            final startTime = (gameData['startTime'] as Timestamp).toDate();
            final endTime = (gameData['finishedAt'] as Timestamp).toDate();

            final difference = endTime.difference(startTime);
            final hours = difference.inHours;
            final minutes = difference.inMinutes % 60;

            if (hours > 0) {
              duration = '$hours:${minutes.toString().padLeft(2, '0')}';
            } else {
              duration = '$minutes min';
            }
          }

          // Determine winner (player with highest score)
          Map<String, dynamic>? winner;
          int highestScore = -1;
          bool isTie = false;

          // Process each player
          List<Map<String, dynamic>> processedPlayers = [];

          for (final player in players) {
            if (player is Map) {
              final int score = player['totalScore'] ?? 0;

              // Check if this player has the highest score
              if (score > highestScore) {
                highestScore = score;
                winner = player as Map<String, dynamic>;
                isTie = false;
              } else if (score == highestScore && highestScore > 0) {
                isTie = true;
              }

              // Add processed player data
              processedPlayers.add({
                'firstName': player['firstName'] ?? 'Unknown',
                'totalScore': score,
                'isWinner':
                    false, // Will be updated after all players are processed
                'frames': player['throwsPerFrame'] ?? {},
              });
            }
          }

          // Mark winners
          if (!isTie && winner != null) {
            for (final player in processedPlayers) {
              if (player['totalScore'] == highestScore) {
                player['isWinner'] = true;
              }
            }
          }

          // Add the game to user's game history
          userGames.add({
            'id': doc.id,
            'date': formattedDate,
            'time': formattedTime,
            'location': gameData['location'] ??
                'Bowling DeRing', // Use actual location from Firebase
            'duration': duration,
            'players': processedPlayers,
            'rawDate': gameData['date'], // Keep original timestamp for sorting
            'lastDocument': doc, // Store document for pagination
          });
        }
      }

      print(
          'getGameHistory: Found ${userGames.length} games for user $deRingID ($firstName)');
      return userGames;
    } catch (e) {
      print('Error fetching game history: $e');
      return [];
    }
  }
}
