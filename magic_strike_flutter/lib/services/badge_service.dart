import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/badge_data.dart';

/// Service class to handle badge-related operations
class BadgeService {
  // Singleton pattern
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get Firebase UID from DeRing ID
  ///
  /// This helper method translates a DeRing ID (e.g., DR00006) to the corresponding Firebase UID
  /// which is needed for Firestore operations on user documents
  Future<String?> _getFirebaseUidFromDeRingId(String deRingId) async {
    try {
      print('🔍 DEBUG: Looking up Firebase UID for deRingID: $deRingId');

      // Query Firestore for the user with this deRingID
      final QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('deRingID', isEqualTo: deRingId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('❌ DEBUG: No user found with deRingID: $deRingId');
        return null;
      }

      // Get the document ID, which is the Firebase UID
      final String firebaseUid = querySnapshot.docs.first.id;
      print(
          '✅ DEBUG: Found Firebase UID: $firebaseUid for deRingID: $deRingId');

      return firebaseUid;
    } catch (e) {
      print('❌ DEBUG: Error looking up Firebase UID for deRingID: $e');
      return null;
    }
  }

  /// Award a badge to a user
  ///
  /// Parameters:
  /// - userId: The user's ID to award the badge to. If null, will use current user.
  /// - badgeId: The ID of the badge to award (must exist in badgeMetadata)
  ///
  /// Returns true if badge was awarded, false if already owned or error occurred
  Future<bool> awardBadge(String badgeId, {String? userId}) async {
    try {
      // DEBUG: Log award attempt
      print(
          '🏆 DEBUG: Attempting to award badge: $badgeId to user: ${userId ?? 'current user'}');

      // Validate badge ID
      final badgeMetadataItem = badgeMetadata.firstWhere(
        (badge) => badge['id'] == badgeId,
        orElse: () => {},
      );

      if (badgeMetadataItem.isEmpty) {
        print('❌ DEBUG: Invalid badge ID: $badgeId');
        return false;
      }

      // Get user ID (either provided or current user)
      String? uid;

      if (userId != null) {
        // Check if the userId is a deRingID (typically starts with DR)
        // Convert it to firebase UID if needed
        if (userId.toUpperCase().startsWith('DR')) {
          uid = await _getFirebaseUidFromDeRingId(userId);
          print('🔄 DEBUG: Converted deRingID $userId to Firebase UID: $uid');
        } else {
          // Assume it's already a Firebase UID
          uid = userId;
        }
      } else {
        // Use current logged in user
        uid = _auth.currentUser?.uid;
      }

      if (uid == null || uid.isEmpty) {
        print('❌ DEBUG: Could not determine Firebase UID for user');
        return false;
      }

      // Get the user document
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        print('❌ DEBUG: User document not found for ID: $uid');
        return false;
      }

      // Check if user already has this badge
      final userData = userDoc.data() as Map<String, dynamic>;
      print('📊 DEBUG: Current user badges: ${userData['badges'] ?? 'none'}');

      // Handle different types of 'badges' field - could be null, List, or Map
      final dynamic userBadgesRaw = userData['badges'];

      // Initialize an empty map for user badges
      Map<String, dynamic> userBadges = {};

      // Check if badges exist and process based on type
      if (userBadgesRaw != null) {
        if (userBadgesRaw is List) {
          // If badges is a List, convert to a Map using badge IDs as keys
          print('⚠️ DEBUG: Converting badges from List to Map format');
          for (var badge in userBadgesRaw) {
            if (badge is Map && badge.containsKey('id')) {
              userBadges[badge['id']] = {
                'earnedAt': badge['earnedAt'] ?? FieldValue.serverTimestamp()
              };
            }
          }
        } else if (userBadgesRaw is Map) {
          // If badges is a Map, use it directly
          userBadges = Map<String, dynamic>.from(userBadgesRaw);
        }
      }

      // If badge already exists, don't award it again
      if (userBadges.containsKey(badgeId)) {
        print('⚠️ DEBUG: User already has badge: $badgeId');
        return false;
      }

      // Award the badge by updating the user document
      print('✅ DEBUG: Awarding badge: $badgeId to user: $uid');

      // Get badge metadata to include with the badge
      final String displayName =
          badgeMetadataItem['displayName'] ?? 'Unknown Badge';
      final String description = badgeMetadataItem['description'] ?? '';

      await _firestore.collection('users').doc(uid).set({
        'badges': {
          badgeId: {
            'earnedAt': FieldValue.serverTimestamp(),
            'displayName': displayName,
            'description': description,
          }
        }
      }, SetOptions(merge: true));

      print('🎉 DEBUG: Badge awarded successfully: $badgeId to user: $uid');
      return true;
    } catch (e) {
      print('❌ DEBUG: Error awarding badge: $e');
      return false;
    }
  }

  /// Get all badges for a user
  Future<Map<String, dynamic>> getUserBadges({String? userId}) async {
    try {
      // DEBUG: Log fetch attempt
      print('🔍 DEBUG: Fetching badges for user: ${userId ?? 'current user'}');

      // Get user ID (either provided or current user)
      String? uid;

      if (userId != null) {
        // Check if the userId is a deRingID (typically starts with DR)
        if (userId.toUpperCase().startsWith('DR')) {
          uid = await _getFirebaseUidFromDeRingId(userId);
          print('🔄 DEBUG: Converted deRingID $userId to Firebase UID: $uid');
        } else {
          // Assume it's already a Firebase UID
          uid = userId;
        }
      } else {
        // Use current logged in user
        uid = _auth.currentUser?.uid;
      }

      if (uid == null || uid.isEmpty) {
        print('❌ DEBUG: Could not determine Firebase UID for user');
        return {};
      }

      // Get user document
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        print(
            '❌ DEBUG: User document not found for ID: $uid during badge fetch');
        return {};
      }

      // Extract badges
      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['badges'] == null) {
        print('📊 DEBUG: No badges found for user: $uid');
        return {};
      }

      // Handle different badge storage formats (List or Map)
      final dynamic badgesRaw = userData['badges'];
      Map<String, dynamic> badges = {};

      if (badgesRaw is List) {
        // Convert list format to map format
        print(
            '⚠️ DEBUG: Converting badges from List to Map format for processing');
        for (var badge in badgesRaw) {
          if (badge is Map && badge.containsKey('id')) {
            badges[badge['id']] = badge;
          }
        }
      } else if (badgesRaw is Map) {
        // Use map format directly
        badges = Map<String, dynamic>.from(badgesRaw);
      }

      print('📊 DEBUG: Found ${badges.length} badges for user: $uid');
      if (badges.isNotEmpty) {
        print('🔢 DEBUG: Badge IDs: ${badges.keys.join(', ')}');
      }

      return badges;
    } catch (e) {
      print('❌ DEBUG: Error getting user badges: $e');
      return {};
    }
  }

  /// Check if user has a specific badge
  Future<bool> userHasBadge(String badgeId, {String? userId}) async {
    try {
      final badges = await getUserBadges(userId: userId);
      return badges.containsKey(badgeId);
    } catch (e) {
      print('Error checking if user has badge: $e');
      return false;
    }
  }

  /// Check for achievements after a game and award badges accordingly
  ///
  /// This function evaluates gameplay performance and awards appropriate badges
  ///
  /// Parameters:
  /// - gameData: Map containing game statistics
  /// - userId: Optional user ID (uses current user if not provided)
  ///
  /// Returns a list of awarded badge IDs
  Future<List<String>> checkForAchievements({
    required Map<String, dynamic> gameData,
    String? userId,
  }) async {
    try {
      List<String> awardedBadges = [];

      // Get user ID (either provided or current user)
      String? uid;

      if (userId != null) {
        // Check if the userId is a deRingID (typically starts with DR)
        if (userId.toUpperCase().startsWith('DR')) {
          uid = await _getFirebaseUidFromDeRingId(userId);
          print('🔄 DEBUG: Converted deRingID $userId to Firebase UID: $uid');
        } else {
          // Assume it's already a Firebase UID
          uid = userId;
        }
      } else {
        // Use current logged in user
        uid = _auth.currentUser?.uid;
      }

      if (uid == null || uid.isEmpty) {
        print('❌ DEBUG: Could not determine Firebase UID for user');
        return [];
      }

      // Extract game stats (with default values if not provided)
      final bool isFirstGame = gameData['isFirstGame'] ?? false;
      final int consecutiveStrikes = gameData['consecutiveStrikes'] ?? 0;
      final int totalStrikes = gameData['totalStrikes'] ?? 0;
      final int spares = gameData['spares'] ?? 0;
      final int gutterBalls = gameData['gutterBalls'] ?? 0;
      final int score = gameData['score'] ?? 0;
      final int playerCount = gameData['playerCount'] ?? 1;
      final DateTime gameTime = gameData['gameTime'] ?? DateTime.now();
      final bool isDisco = gameData['isDisco'] ?? false;
      final bool wonByComeback = gameData['wonByComeback'] ?? false;

      // Check if user got at least one strike (for First Strike achievement)
      if (totalStrikes > 0) {
        print(
            '🎯 DEBUG: Player got at least one strike, checking for first_game badge');
        final bool awarded = await awardBadge('first_game', userId: uid);
        if (awarded) {
          awardedBadges.add('first_game');
          print('🎯 DEBUG: Awarded first_game badge for getting a strike!');
        }
      }
      // Only check for first game if no strikes were made (backward compatibility)
      else if (isFirstGame) {
        final bool awarded = await awardBadge('first_game', userId: uid);
        if (awarded) awardedBadges.add('first_game');
      }

      // Check for strike master achievement (3+ consecutive strikes)
      if (consecutiveStrikes >= 3) {
        final bool awarded = await awardBadge('strike_master', userId: uid);
        if (awarded) awardedBadges.add('strike_master');
      }

      // Check for perfect game achievement (score of 300)
      if (score == 300) {
        final bool awarded = await awardBadge('perfect_game', userId: uid);
        if (awarded) awardedBadges.add('perfect_game');
      }

      // Check for spare collector achievement (5+ spares)
      if (spares >= 5) {
        final bool awarded = await awardBadge('spare_collector', userId: uid);
        if (awarded) awardedBadges.add('spare_collector');
      }

      // Check for night owl achievement (game after 10 PM)
      if (gameTime.hour >= 22) {
        final bool awarded = await awardBadge('night_owl', userId: uid);
        if (awarded) awardedBadges.add('night_owl');
      }

      // Check for social bowler achievement (4+ players)
      if (playerCount >= 4) {
        final bool awarded = await awardBadge('social_bowler', userId: uid);
        if (awarded) awardedBadges.add('social_bowler');
      }

      // Check for comeback king achievement
      if (wonByComeback) {
        final bool awarded = await awardBadge('comeback_king', userId: uid);
        if (awarded) awardedBadges.add('comeback_king');
      }

      // Check for disco dancer achievement
      if (isDisco) {
        final bool awarded = await awardBadge('disco_dancer', userId: uid);
        if (awarded) awardedBadges.add('disco_dancer');
      }

      return awardedBadges;
    } catch (e) {
      print('Error checking for achievements: $e');
      return [];
    }
  }

  /// Simple function to test achievement awarding with mock data
  /// This is for demonstration purposes only
  Future<List<String>> testAchievementsWithMockData({String? userId}) async {
    // Create mock game data
    final Map<String, dynamic> mockGameData = {
      'isFirstGame': true,
      'consecutiveStrikes': 3,
      'totalStrikes': 5,
      'spares': 2,
      'gutterBalls': 0,
      'score': 220,
      'playerCount': 4,
      'gameTime':
          DateTime.now().subtract(const Duration(hours: 2)), // Current time -2h
      'isDisco': false,
      'wonByComeback': true,
    };

    // Run achievements check with mock data
    return await checkForAchievements(
      gameData: mockGameData,
      userId: userId,
    );
  }

  /// Migrate user badge data from list format to map format
  ///
  /// This method should be called when the app starts or when a user logs in
  /// It ensures that badge data is stored in the correct format
  Future<void> migrateBadgesFormat({String? userId}) async {
    try {
      print(
          '🔄 DEBUG: Attempting to migrate badge format for user: ${userId ?? 'current user'}');

      // Get user ID (either provided or current user)
      String? uid;

      if (userId != null) {
        // Check if the userId is a deRingID (typically starts with DR)
        if (userId.toUpperCase().startsWith('DR')) {
          uid = await _getFirebaseUidFromDeRingId(userId);
          print('🔄 DEBUG: Converted deRingID $userId to Firebase UID: $uid');
        } else {
          // Assume it's already a Firebase UID
          uid = userId;
        }
      } else {
        // Use current logged in user
        uid = _auth.currentUser?.uid;
      }

      if (uid == null || uid.isEmpty) {
        print('❌ DEBUG: Could not determine Firebase UID for user');
        return;
      }

      // Get the user document
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        print('❌ DEBUG: User document not found for ID: $uid');
        return;
      }

      // Check badge format
      final userData = userDoc.data() as Map<String, dynamic>;
      final dynamic badgesRaw = userData['badges'];

      // If badges is null, no migration needed
      if (badgesRaw == null) {
        print('✅ DEBUG: No migration needed for user $uid - badges is null');
        return;
      }

      // Variable to track if we need to update the document
      bool needsUpdate = false;

      // Initialize the map to store badges
      Map<String, dynamic> badgesMap = {};

      // Handle different badge storage formats
      if (badgesRaw is List) {
        // If badges is a list, convert to map
        print('🔄 DEBUG: Found badges in list format, migrating to map format');
        needsUpdate = true;

        for (var badge in badgesRaw) {
          if (badge is Map && badge.containsKey('id')) {
            String badgeId = badge['id'] as String;

            // Find badge metadata
            final badgeMetadataItem = badgeMetadata.firstWhere(
              (b) => b['id'] == badgeId,
              orElse: () => {
                'displayName': 'Unknown Badge',
                'description': '',
              },
            );

            badgesMap[badgeId] = {
              'earnedAt': badge['earnedAt'] ?? FieldValue.serverTimestamp(),
              'displayName':
                  badgeMetadataItem['displayName'] ?? 'Unknown Badge',
              'description': badgeMetadataItem['description'] ?? '',
            };
          }
        }
      } else if (badgesRaw is Map) {
        // If badges is already a map, check if we need to add displayName and description
        badgesMap = Map<String, dynamic>.from(badgesRaw);

        // Check if any badge is missing displayName or description
        for (var badgeId in badgesMap.keys) {
          var badge = badgesMap[badgeId];

          if (badge is Map &&
              (!badge.containsKey('displayName') ||
                  !badge.containsKey('description'))) {
            // Find badge metadata
            final badgeMetadataItem = badgeMetadata.firstWhere(
              (b) => b['id'] == badgeId,
              orElse: () => {
                'displayName': 'Unknown Badge',
                'description': '',
              },
            );

            // Add missing fields
            if (!badge.containsKey('displayName')) {
              badge['displayName'] =
                  badgeMetadataItem['displayName'] ?? 'Unknown Badge';
              needsUpdate = true;
            }

            if (!badge.containsKey('description')) {
              badge['description'] = badgeMetadataItem['description'] ?? '';
              needsUpdate = true;
            }
          }
        }
      }

      // Update the user document with the new format if needed
      if (needsUpdate) {
        await _firestore
            .collection('users')
            .doc(uid)
            .update({'badges': badgesMap});
      }
    } catch (e) {
      print('❌ DEBUG: Error migrating badge format: $e');
    }
  }
}
