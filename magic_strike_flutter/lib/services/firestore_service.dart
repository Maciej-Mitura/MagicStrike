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

  /// Add a player to a game
  Future<bool> addPlayerToGameRoom(String roomID, String playerName) async {
    try {
      // Get current user's data
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        print('addPlayerToGameRoom: Missing deRingID or firstName');
        return false;
      }

      // Find the game document with this roomId
      final QuerySnapshot gamesQuery = await _firestore
          .collection('games')
          .where('roomId', isEqualTo: roomID)
          .limit(1)
          .get();

      if (gamesQuery.docs.isEmpty) {
        print('Game not found with roomId: $roomID');
        return false;
      }

      final gameDoc = gamesQuery.docs.first;
      final gameData = gameDoc.data() as Map<String, dynamic>;

      // Check if game has already started (status is 'in_progress')
      final String gameStatus = gameData['status'] ?? 'waiting';
      if (gameStatus == 'in_progress') {
        print('Cannot join game: Game has already started');
        throw Exception('Game has already started. Cannot join now.');
      }

      // Get the current players array
      final List<dynamic> gamePlayers = List.from(gameData['players'] ?? []);

      // Check if the room has reached its maximum player count
      final int maxPlayers = gameData['maxPlayers'] ?? 1;
      if (gamePlayers.length >= maxPlayers) {
        print('Cannot join game: Room is full');
        throw Exception('Room is full. Cannot join this game.');
      }

      // Check if player already exists in the game
      bool playerExistsInGame = false;
      for (final player in gamePlayers) {
        if (player['userId'] == deRingID) {
          playerExistsInGame = true;
          break;
        }
      }

      // If player is already in the game, don't add them again
      if (playerExistsInGame) {
        print('Player $firstName is already in the game');
        return true;
      }

      // Create empty throwsPerFrame structure for the new player
      final throwsPerFrame = {
        '1': [],
        '2': [],
        '3': [],
        '4': [],
        '5': [],
        '6': [],
        '7': [],
        '8': [],
        '9': [],
        '10': []
      };

      // Create the player object
      final newPlayer = {
        'firstName': firstName,
        'userId': deRingID,
        'throwsPerFrame': throwsPerFrame,
        'totalScore': 0
      };

      // Add the new player
      gamePlayers.add(newPlayer);

      // Update the game document
      await gameDoc.reference.update({'players': gamePlayers});

      print('Added player $firstName to game with roomId: $roomID');
      return true;
    } catch (e) {
      print('Error adding player to game: $e');
      rethrow; // Re-throw the exception to handle it in the UI
    }
  }

  /// Remove a player from a game when they leave
  Future<bool> removePlayerFromGame(String roomID) async {
    try {
      // Get current user's data
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        print('removePlayerFromGame: Missing deRingID or firstName');
        return false;
      }

      // Find the game document with this roomId
      final QuerySnapshot gamesQuery = await _firestore
          .collection('games')
          .where('roomId', isEqualTo: roomID)
          .limit(1)
          .get();

      if (gamesQuery.docs.isEmpty) {
        print('Game not found with roomId: $roomID');
        return false;
      }

      final gameDoc = gamesQuery.docs.first;
      final gameData = gameDoc.data() as Map<String, dynamic>;

      // Get the current players array
      final List<dynamic> gamePlayers = List.from(gameData['players'] ?? []);

      // Check if this player exists in the game
      int playerIndex = -1;
      for (int i = 0; i < gamePlayers.length; i++) {
        if (gamePlayers[i]['userId'] == deRingID) {
          playerIndex = i;
          break;
        }
      }

      if (playerIndex == -1) {
        // Player not found in the game
        print('Player $firstName not found in game with roomId: $roomID');
        return false;
      }

      // Don't allow the creator (first player) to leave
      if (playerIndex == 0) {
        print('Game creator cannot leave the game');
        return false;
      }

      // Check if the game has already started
      final String gameStatus = gameData['status'] ?? 'waiting';
      if (gameStatus == 'in_progress') {
        // If the game is in progress, mark the player as inactive but don't remove
        gamePlayers[playerIndex]['isActive'] = false;
        print(
            'Marked player $firstName as inactive in game with roomId: $roomID');
      } else {
        // If the game hasn't started yet, remove the player
        gamePlayers.removeAt(playerIndex);
        print('Removed player $firstName from game with roomId: $roomID');
      }

      // Update the game document
      await gameDoc.reference.update({'players': gamePlayers});

      return true;
    } catch (e) {
      print('Error removing player from game: $e');
      return false;
    }
  }

  /// Spectate a game without joining as a player
  Future<Map<String, dynamic>?> spectateGame(String roomID) async {
    try {
      // Get current user's data (for tracking purposes only)
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        print('spectateGame: Missing deRingID or firstName');
        return null;
      }

      // Find the game document with this roomId
      final QuerySnapshot gamesQuery = await _firestore
          .collection('games')
          .where('roomId', isEqualTo: roomID)
          .limit(1)
          .get();

      if (gamesQuery.docs.isEmpty) {
        print('Game not found with roomId: $roomID');
        return null;
      }

      final gameDoc = gamesQuery.docs.first;
      final gameData = gameDoc.data() as Map<String, dynamic>;

      // Check if game exists and is active (status is 'waiting' or 'in_progress')
      final String gameStatus = gameData['status'] ?? 'waiting';
      if (gameStatus == 'completed') {
        print('Cannot spectate: Game has already completed');
        throw Exception('This game has already completed. Cannot spectate.');
      }

      // Add the spectator to the spectators array if it doesn't exist
      List<dynamic> spectators = List.from(gameData['spectators'] ?? []);

      // Check if the spectator already exists
      bool spectatorExists = false;
      for (final spectator in spectators) {
        if (spectator['userId'] == deRingID) {
          spectatorExists = true;
          break;
        }
      }

      // Add the spectator if they're not already in the list
      if (!spectatorExists) {
        spectators.add({
          'userId': deRingID,
          'firstName': firstName,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        // Update spectators array in Firestore (don't await - let it happen in background)
        gameDoc.reference.update({'spectators': spectators});

        print('Added spectator $firstName to game with roomId: $roomID');
      }

      // Return the game data for display
      return {
        'id': gameDoc.id,
        'roomId': roomID,
        'status': gameStatus,
        'players': gameData['players'] ?? [],
        'spectators': spectators,
        'maxPlayers': gameData['maxPlayers'] ?? 1,
        'currentFrame': gameData['currentFrame'] ?? 1,
        'currentPlayerIndex': gameData['currentPlayerIndex'] ?? 0,
        'currentThrow': gameData['currentThrow'] ?? 1,
      };
    } catch (e) {
      print('Error spectating game: $e');
      rethrow; // Re-throw the exception to handle it in the UI
    }
  }

  /// Remove a spectator from a game
  Future<bool> removeSpectatorFromGame(String roomID) async {
    try {
      // Get current user's data
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];
      final String? firstName = userData['firstName'];

      if (deRingID == null || firstName == null) {
        print('removeSpectatorFromGame: Missing deRingID or firstName');
        return false;
      }

      // Find the game document with this roomId
      final QuerySnapshot gamesQuery = await _firestore
          .collection('games')
          .where('roomId', isEqualTo: roomID)
          .limit(1)
          .get();

      if (gamesQuery.docs.isEmpty) {
        print('Game not found with roomId: $roomID');
        return false;
      }

      final gameDoc = gamesQuery.docs.first;
      final gameData = gameDoc.data() as Map<String, dynamic>;

      // Get the current spectators array
      final List<dynamic> spectators = List.from(gameData['spectators'] ?? []);

      // Check if this spectator exists in the game
      int spectatorIndex = -1;
      for (int i = 0; i < spectators.length; i++) {
        if (spectators[i]['userId'] == deRingID) {
          spectatorIndex = i;
          break;
        }
      }

      if (spectatorIndex == -1) {
        // Spectator not found in the game
        print('Spectator $firstName not found in game with roomId: $roomID');
        return false;
      }

      // Remove the spectator
      spectators.removeAt(spectatorIndex);
      print('Removed spectator $firstName from game with roomId: $roomID');

      // Update the game document
      await gameDoc.reference.update({'spectators': spectators});

      return true;
    } catch (e) {
      print('Error removing spectator from game: $e');
      return false;
    }
  }
}
