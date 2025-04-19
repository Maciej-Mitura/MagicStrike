import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  // Singleton pattern
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Store user data in memory for easy access
  String? _currentUserDeRingID;
  String? _currentUserFirstName;

  // Getters for the stored values
  String? get currentUserDeRingID => _currentUserDeRingID;
  String? get currentUserFirstName => _currentUserFirstName;

  /// Initialize user data after login or registration
  /// Checks if user exists in Firestore, if not creates a new user document
  Future<Map<String, String>> initializeUserData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user is currently logged in');
      }

      final String uid = currentUser.uid;
      print('Initializing user data for UID: $uid');

      // Extract first name from display name
      String? firstName;
      if (currentUser.displayName != null) {
        // Use the first part as firstName if display name contains spaces
        firstName = currentUser.displayName!.split(' ').first;
      } else {
        // Fallback to email prefix if no display name
        firstName = currentUser.email?.split('@').first;
      }

      // Check if user document exists
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        // User exists, get deRingID and firstName
        final userData = userDoc.data();
        String? deRingID = userData?['deRingID'] as String?;
        String? storedFirstName = userData?['firstName'] as String?;

        // If deRingID doesn't exist, create one
        if (deRingID == null) {
          deRingID = await _generateNewDeRingID();
          await _firestore.collection('users').doc(uid).update({
            'deRingID': deRingID,
          });
        }

        // If firstName doesn't exist or has changed, update it
        if (storedFirstName == null ||
            (firstName != null && storedFirstName != firstName)) {
          await _firestore.collection('users').doc(uid).update({
            'firstName': firstName,
          });
          storedFirstName = firstName;
        }

        // Store values in memory
        _currentUserDeRingID = deRingID;
        _currentUserFirstName = storedFirstName ?? '';

        return {
          'deRingID': deRingID,
          'firstName': storedFirstName ?? '',
        };
      } else {
        // User doesn't exist, create new document with new deRingID
        final newDeRingID = await _generateNewDeRingID();

        // Create a new user document
        await _firestore.collection('users').doc(uid).set({
          'deRingID': newDeRingID,
          'firstName': firstName,
          'email': currentUser.email,
          'displayName': currentUser.displayName,
          'createdAt': FieldValue.serverTimestamp(),
          // Additional user fields with empty initial values
          'clubOrTeam': '', // User's bowling club or team
          'dateOfBirth': '', // User's date of birth
          'gender': '', // User's gender
          'lastName': '', // User's last name
          'side': '', // User's bowling side (e.g., right/left)
          'style': '', // User's bowling style
        });

        // Store values in memory
        _currentUserDeRingID = newDeRingID;
        _currentUserFirstName = firstName ?? '';

        return {
          'deRingID': newDeRingID,
          'firstName': firstName ?? '',
        };
      }
    } catch (e) {
      print('Error initializing user data: $e');
      throw Exception('Failed to initialize user data: $e');
    }
  }

  /// Generate a new deRingID based on the highest existing ID
  Future<String> _generateNewDeRingID() async {
    try {
      // Get all user documents
      final QuerySnapshot userSnapshot =
          await _firestore.collection('users').get();

      // Find highest deRingID
      int highestNumber = 0;

      for (final doc in userSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final deRingID = data['deRingID'] as String?;

        if (deRingID != null && deRingID.startsWith('DR')) {
          try {
            final numberPart = deRingID.substring(2); // Remove "DR" prefix
            final number = int.parse(numberPart);

            if (number > highestNumber) {
              highestNumber = number;
            }
          } catch (e) {
            // Ignore parsing errors
            print('Error parsing deRingID: $deRingID');
          }
        }
      }

      // Increment the highest number
      final newNumber = highestNumber + 1;

      // Format with leading zeros (e.g., DR00002)
      final formattedNumber = newNumber.toString().padLeft(5, '0');
      final newDeRingID = 'DR$formattedNumber';

      print('Generated new deRingID: $newDeRingID');
      return newDeRingID;
    } catch (e) {
      print('Error generating new deRingID: $e');
      // Fallback to a timestamp-based ID if something fails
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'DR$timestamp';
    }
  }

  /// Get user data (deRingID and firstName) for the current user (from cache or Firestore)
  Future<Map<String, String?>> getCurrentUserData() async {
    try {
      // Return cached values if available
      if (_currentUserDeRingID != null && _currentUserFirstName != null) {
        return {
          'deRingID': _currentUserDeRingID,
          'firstName': _currentUserFirstName,
        };
      }

      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {
          'deRingID': null,
          'firstName': null,
        };
      }

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final deRingID = userData?['deRingID'] as String?;
        final firstName = userData?['firstName'] as String?;

        // Cache the values
        _currentUserDeRingID = deRingID;
        _currentUserFirstName = firstName;

        return {
          'deRingID': deRingID,
          'firstName': firstName,
        };
      }

      return {
        'deRingID': null,
        'firstName': null,
      };
    } catch (e) {
      print('Error getting current user data: $e');
      return {
        'deRingID': null,
        'firstName': null,
      };
    }
  }

  /// Clear cached user data on logout
  void clearUserData() {
    _currentUserDeRingID = null;
    _currentUserFirstName = null;
  }

  /// Update the cached firstName value
  void updateCachedFirstName(String firstName) {
    _currentUserFirstName = firstName;
  }

  /// Update all games with the new firstName for the current user
  /// This ensures all historical games show the correct user information
  Future<void> updateGamesWithNewName(String newFirstName) async {
    try {
      final String? deRingID = _currentUserDeRingID;
      final String? oldFirstName = _currentUserFirstName;

      if (deRingID == null || oldFirstName == null) {
        print('Cannot update games: Missing deRingID or firstName');
        return;
      }

      print(
          'Updating games for user $deRingID: $oldFirstName -> $newFirstName');

      // Query all games
      final QuerySnapshot gamesSnapshot =
          await _firestore.collection('games').get();

      int updatedGamesCount = 0;

      // Batch to handle multiple updates efficiently
      final WriteBatch batch = _firestore.batch();

      // Iterate through all games
      for (final doc in gamesSnapshot.docs) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        bool gameNeedsUpdate = false;

        // Update creatorName if this user created the game
        if (data['createdBy'] == deRingID) {
          data['creatorName'] = newFirstName;
          gameNeedsUpdate = true;
          print('Updated creator name in game ${doc.id}');
        }

        // Update player information in the players array
        if (data['players'] != null && data['players'] is List) {
          final List<dynamic> players = List.from(data['players']);

          for (int i = 0; i < players.length; i++) {
            if (players[i] is Map && players[i]['userId'] == deRingID) {
              // Create a new map with updated firstName
              Map<String, dynamic> updatedPlayer =
                  Map<String, dynamic>.from(players[i]);
              updatedPlayer['firstName'] = newFirstName;

              // Replace the player in the list
              players[i] = updatedPlayer;
              gameNeedsUpdate = true;
              print('Updated player name in game ${doc.id}');
            }
          }

          if (gameNeedsUpdate) {
            data['players'] = players;
          }
        }

        // If any changes were made, add this document to the batch
        if (gameNeedsUpdate) {
          batch.update(doc.reference, data);
          updatedGamesCount++;
        }
      }

      // Commit all updates
      if (updatedGamesCount > 0) {
        await batch.commit();
        print(
            'Updated $updatedGamesCount games with new firstName: $newFirstName');
      } else {
        print('No games needed to be updated');
      }
    } catch (e) {
      print('Error updating games with new name: $e');
    }
  }
}
