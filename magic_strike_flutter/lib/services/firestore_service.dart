import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_service.dart';

class FirestoreService {
  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final UserService _userService = UserService();

  /// Retrieves the latest 5 games from Firestore for the current user
  Future<List<Map<String, dynamic>>> getLatestGames() async {
    try {
      // Get current user's deRingID and firstName
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        print('getLatestGames: Missing deRingID or firstName');
        return [];
      }

      print('getLatestGames: Fetching games for user $deRingID ($firstName)');

      // Query games, sorted by date
      final QuerySnapshot querySnapshot = await _firestore
          .collection('games')
          .orderBy('date', descending: true)
          .limit(5)
          .get();

      print('getLatestGames: Found ${querySnapshot.docs.length} total games');

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
          'getLatestGames: Found ${userGames.length} games for user $deRingID ($firstName)');
      return userGames;
    } catch (e) {
      print('Error fetching latest games: $e');
      return [];
    }
  }

  /// Save a new game to Firestore
  Future<String?> saveGame({
    required String location,
    required List<Map<String, dynamic>> players,
    DateTime? date,
  }) async {
    try {
      // Get current user's deRingID and firstName
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        print('saveGame: Missing deRingID or firstName');
        return null;
      }

      // Save game document to Firestore
      final docRef = await _firestore.collection('games').add({
        'location': location,
        'date': date ?? FieldValue.serverTimestamp(),
        'players': players,
        'createdBy': deRingID,
        'creatorName': firstName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Game saved with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error saving game: $e');
      return null;
    }
  }

  /// Update an existing game
  Future<bool> updateGame({
    required String gameId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection('games').doc(gameId).update(data);
      return true;
    } catch (e) {
      print('Error updating game: $e');
      return false;
    }
  }
}
