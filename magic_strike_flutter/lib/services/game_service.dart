import 'dart:async';

import 'package:magic_strike_flutter/models/game_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'badge_service.dart';

/// Service class for live game management
/// This will be replaced with actual API calls in the future
class GameService {
  // Singleton pattern
  static final GameService _instance = GameService._internal();
  factory GameService() => _instance;
  GameService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BadgeService _badgeService = BadgeService();

  // In-memory cache of active games
  final Map<String, LiveGame> _activeGames = {};

  // Stream controllers for each game
  final Map<String, StreamController<LiveGame>> _gameControllers = {};

  // Viewer tracking
  final Map<String, Set<String>> _gameViewers = {};

  // Mock socket for demo purposes
  Timer? _mockUpdateTimer;

  /// Get a game by ID
  /// Returns null if the game doesn't exist
  LiveGame? getGame(String gameId) {
    return _activeGames[gameId];
  }

  /// Join a game by ID
  /// Returns a stream of game updates
  Stream<LiveGame> joinGame(String gameId, String viewerId) {
    // Check if the game exists in our demo IDs
    if (!_isDemoGameId(gameId)) {
      throw Exception('Game not found');
    }

    // Create the game if it doesn't exist
    if (!_activeGames.containsKey(gameId)) {
      _createDemoGame(gameId);
    }

    // Create a stream controller if it doesn't exist
    if (!_gameControllers.containsKey(gameId)) {
      _gameControllers[gameId] = StreamController<LiveGame>.broadcast();
    }

    // Add the viewer to the game
    _gameViewers.putIfAbsent(gameId, () => {});
    _gameViewers[gameId]!.add(viewerId);

    // Update viewer count
    final game = _activeGames[gameId]!;
    game.viewerCount = _gameViewers[gameId]!.length;
    _notifyGameUpdate(gameId);

    // Start mock updates if needed
    _startMockUpdates();

    return _gameControllers[gameId]!.stream;
  }

  /// Leave a game
  void leaveGame(String gameId, String viewerId) {
    // Remove the viewer from the game
    if (_gameViewers.containsKey(gameId)) {
      _gameViewers[gameId]!.remove(viewerId);

      // Update viewer count
      if (_activeGames.containsKey(gameId)) {
        final game = _activeGames[gameId]!;
        game.viewerCount = _gameViewers[gameId]!.length;
        _notifyGameUpdate(gameId);
      }

      // If no viewers, clean up
      if (_gameViewers[gameId]!.isEmpty) {
        _cleanupGame(gameId);
      }
    }

    // If no active games, stop mock updates
    if (_activeGames.isEmpty) {
      _stopMockUpdates();
    }
  }

  /// Update a throw for a player
  /// This will be called by the backend in the future
  void updateThrow(String gameId, String playerId, int frameIndex,
      int throwIndex, String display) {
    if (!_activeGames.containsKey(gameId)) return;

    final game = _activeGames[gameId]!;
    game.updateThrow(playerId, frameIndex, throwIndex, display);
    _notifyGameUpdate(gameId);
  }

  /// Clean up resources for a game
  void _cleanupGame(String gameId) {
    _activeGames.remove(gameId);
    _gameViewers.remove(gameId);

    // Close the stream controller
    if (_gameControllers.containsKey(gameId)) {
      _gameControllers[gameId]!.close();
      _gameControllers.remove(gameId);
    }
  }

  /// Notify listeners of a game update
  void _notifyGameUpdate(String gameId) {
    if (!_activeGames.containsKey(gameId) ||
        !_gameControllers.containsKey(gameId)) {
      return;
    }

    _gameControllers[gameId]!.add(_activeGames[gameId]!);
  }

  /// Start mock updates for demo purposes
  void _startMockUpdates() {
    if (_mockUpdateTimer != null) return;

    // Simulate events every few seconds
    _mockUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Skip if no active games
      if (_activeGames.isEmpty) return;

      // Randomly select a game to update
      final gameIds = _activeGames.keys.toList();
      final gameId =
          gameIds[DateTime.now().millisecondsSinceEpoch % gameIds.length];
      final game = _activeGames[gameId]!;

      // Skip completed games
      if (game.status != 'live') return;

      // Randomly decide what to update
      final updateType = DateTime.now().second % 3;

      switch (updateType) {
        case 0:
          // Update a throw
          _mockUpdateThrow(gameId);
          break;
        case 1:
          // Random viewer join/leave
          _mockViewerChange(gameId);
          break;
        case 2:
          // Progress to next frame (if applicable)
          _mockAdvanceFrame(gameId);
          break;
      }
    });
  }

  /// Stop mock updates
  void _stopMockUpdates() {
    _mockUpdateTimer?.cancel();
    _mockUpdateTimer = null;
  }

  /// Mock a throw update
  void _mockUpdateThrow(String gameId) {
    final game = _activeGames[gameId]!;
    if (game.players.isEmpty) return;

    // Current frame to update is the game's current frame
    final frameIndex = game.currentFrame - 1;
    if (frameIndex < 0 || frameIndex >= 10) return;

    // Find a player who needs a throw in this frame
    int playerToUpdate = -1;
    int throwIndex = 0;

    // Scan players to find one who needs a throw in the current frame
    for (int i = 0; i < game.players.length; i++) {
      final player = game.players[i];

      // If player doesn't have this frame yet, they need a throw
      if (frameIndex >= player.frames.length) {
        playerToUpdate = i;
        throwIndex = 0;
        break;
      }

      // If frame exists but is not complete, find which throw they need
      if (!player.frames[frameIndex].isComplete) {
        playerToUpdate = i;
        throwIndex = player.frames[frameIndex].throws.isEmpty ? 0 : 1;
        break;
      }
    }

    // If no player needs updating, return
    if (playerToUpdate < 0) return;

    final player = game.players[playerToUpdate];

    // Ensure the frame exists
    List<BowlingFrame> frames = List<BowlingFrame>.from(player.frames);
    while (frames.length <= frameIndex) {
      frames.add(BowlingFrame.empty());
    }

    final frame =
        frameIndex < frames.length ? frames[frameIndex] : BowlingFrame.empty();

    // Generate a random throw
    final throwValue = _generateRandomThrow(throwIndex, frame);

    // Update the throw
    updateThrow(gameId, player.id, frameIndex, throwIndex, throwValue);
  }

  /// Generate a random throw value
  String _generateRandomThrow(int throwIndex, BowlingFrame frame) {
    // More realistic bowling probabilities
    final rand = DateTime.now().millisecondsSinceEpoch % 100;

    if (throwIndex == 0) {
      // First throw probabilities:
      // - Strike: 20%
      // - 7-9 pins: 50%
      // - 4-6 pins: 20%
      // - 0-3 pins: 10%

      if (rand < 20) {
        return 'X'; // Strike
      } else if (rand < 70) {
        return (7 + (rand % 3)).toString(); // 7-9 pins
      } else if (rand < 90) {
        return (4 + (rand % 3)).toString(); // 4-6 pins
      } else {
        if (rand % 4 == 0) return '-'; // Gutter (about 2.5%)
        return (1 + (rand % 3)).toString(); // 1-3 pins
      }
    } else {
      // Second throw depends on first throw
      final firstThrow = frame.throws.first;
      if (firstThrow.isStrike) return ''; // Should not happen

      final firstPins = firstThrow.numericValue ?? 0;
      final remainingPins = 10 - firstPins;

      // Second throw probabilities:
      // - Spare: 30% (when possible)
      // - Miss: 15%
      // - Hit some pins: 55%

      if (remainingPins == 0) return '-'; // No pins left

      if (rand < 30 && remainingPins > 0) {
        return '/'; // Spare (30% chance when possible)
      } else if (rand < 45) {
        return '-'; // Miss (15% chance)
      } else {
        // Hit some pins but not all
        final hittablePins = remainingPins - 1;
        final pinsHit = hittablePins > 0 ? 1 + (rand % hittablePins) : 1;
        return pinsHit.toString();
      }
    }
  }

  /// Mock a viewer joining or leaving
  void _mockViewerChange(String gameId) {
    final game = _activeGames[gameId]!;

    // 50/50 chance of join/leave
    final isJoining = DateTime.now().millisecondsSinceEpoch % 2 == 0;

    if (isJoining) {
      // Simulate a new viewer joining
      final viewerId = 'mock-viewer-${DateTime.now().millisecondsSinceEpoch}';
      _gameViewers.putIfAbsent(gameId, () => {});
      _gameViewers[gameId]!.add(viewerId);
      game.viewerCount = _gameViewers[gameId]!.length;
    } else if (game.viewerCount > 0) {
      // Simulate a viewer leaving (but ensure at least one remains)
      if (_gameViewers[gameId]!.length > 1) {
        final viewerId = _gameViewers[gameId]!.first;
        _gameViewers[gameId]!.remove(viewerId);
        game.viewerCount = _gameViewers[gameId]!.length;
      }
    }

    _notifyGameUpdate(gameId);
  }

  /// Mock advancing to the next frame
  void _mockAdvanceFrame(String gameId) {
    final game = _activeGames[gameId]!;

    // Skip if the game is already completed
    if (game.status == 'completed') {
      return;
    }

    // First, see if we can find a player who hasn't completed their current frame
    final currentFrameIndex = game.currentFrame - 1;

    // Check if any player needs a throw in the current frame
    bool anyNeedsThrow = false;

    for (final player in game.players) {
      // If player doesn't have this frame yet, they need a throw
      if (currentFrameIndex >= player.frames.length) {
        anyNeedsThrow = true;
        break;
      }

      // If frame exists but is not complete, they need a throw
      if (!player.frames[currentFrameIndex].isComplete) {
        anyNeedsThrow = true;
        break;
      }
    }

    // If someone needs a throw, simulate it instead of advancing
    if (anyNeedsThrow) {
      _mockUpdateThrow(gameId);
      return;
    }

    // At this point, all players have completed the current frame
    // The game model's _updateCurrentFrame method will handle the frame advancement
    // and status updates automatically in response to the throw updates

    // We just need to notify that the game was updated
    _notifyGameUpdate(gameId);
  }

  /// Check if a game ID is one of our demo games
  bool _isDemoGameId(String gameId) {
    return gameId == 'BOWL123' || gameId == 'STRIKE456' || gameId == 'GAME789';
  }

  /// Create a demo game
  void _createDemoGame(String gameId) {
    try {
      switch (gameId) {
        case 'BOWL123':
          _activeGames[gameId] = LiveGame.createDemoRegularGame();
          break;
        case 'STRIKE456':
          _activeGames[gameId] = LiveGame.createDemoPerfectGame();
          break;
        case 'GAME789':
          _activeGames[gameId] = LiveGame.createDemoMultiPlayerGame();
          break;
        default:
          throw Exception('Unknown demo game ID');
      }
    } catch (e) {
      // Create a simple fallback game if there's an error
      _activeGames[gameId] = _createFallbackGame(gameId);
    }
  }

  // Create a simple fallback game in case of errors
  LiveGame _createFallbackGame(String gameId) {
    return LiveGame(
      id: gameId,
      status: 'live',
      currentFrame: 1,
      viewerCount: 1,
      players: [
        Player(
          id: 'player1',
          name: 'Player 1',
          frames: [BowlingFrame.empty()],
          totalScore: 0,
        ),
      ],
    );
  }

  /// Dispose all resources
  void dispose() {
    _stopMockUpdates();

    // Close all stream controllers
    for (final controller in _gameControllers.values) {
      controller.close();
    }

    _gameControllers.clear();
    _activeGames.clear();
    _gameViewers.clear();
  }

  /// Process game completion and check for achievements
  ///
  /// This function should be called when a game is completed
  /// It calculates statistics and checks for badges
  Future<List<String>> processGameCompletion({
    required Map<String, dynamic> gameData,
    required String userId,
  }) async {
    try {
      // Enrich game data with calculated stats
      final Map<String, dynamic> enrichedGameData =
          await _calculateGameStats(gameData, userId);

      // Check for achievements and award badges
      final List<String> awardedBadges =
          await _badgeService.checkForAchievements(
        gameData: enrichedGameData,
        userId: userId,
      );

      return awardedBadges;
    } catch (e) {
      print('Error processing game completion: $e');
      return [];
    }
  }

  /// Calculate advanced game statistics from raw game data
  /// This enriches the game data with derived statistics needed for achievement checks
  Future<Map<String, dynamic>> _calculateGameStats(
    Map<String, dynamic> gameData,
    String userId,
  ) async {
    try {
      // Get user's existing games to check if this is their first game
      final bool isFirstGame = await _isUsersFirstGame(userId);

      // Get the throws data from the game
      final List<dynamic> throwsData = gameData['throwsPerFrame'] ?? [];

      // Initialize statistics
      int consecutiveStrikes = 0;
      int maxConsecutiveStrikes = 0;
      int totalStrikes = 0;
      int spares = 0;
      int gutterBalls = 0;

      // Calculate statistics from throws data
      // This would normally parse the actual throws data
      // For now, we'll use mock calculations

      // Simulate parsing throws data (in a real implementation, this would analyze the actual game data)
      for (int i = 1; i <= 10; i++) {
        // Mock frame data
        final List<dynamic> frameThrows =
            throwsData.isNotEmpty && throwsData.length >= i
                ? throwsData[i - 1] as List<dynamic>
                : [];

        // Count strikes, spares, and gutters based on the mock data
        if (frameThrows.isNotEmpty) {
          final int firstThrow =
              frameThrows[0] is int ? frameThrows[0] as int : 0;

          // Check for strike
          if (firstThrow == 10) {
            totalStrikes++;
            consecutiveStrikes++;
            if (consecutiveStrikes > maxConsecutiveStrikes) {
              maxConsecutiveStrikes = consecutiveStrikes;
            }
          } else {
            consecutiveStrikes = 0;

            // Check for gutter ball
            if (firstThrow == 0) {
              gutterBalls++;
            }

            // Check for spare if there's a second throw
            if (frameThrows.length > 1) {
              final int secondThrow =
                  frameThrows[1] is int ? frameThrows[1] as int : 0;
              if (firstThrow + secondThrow == 10) {
                spares++;
              }
              if (secondThrow == 0) {
                gutterBalls++;
              }
            }
          }
        }
      }

      // Determine if game was a comeback win
      bool wonByComeback = false;
      if (gameData['playerCount'] != null && gameData['playerCount'] > 1) {
        // Mock logic to determine if user was behind by 30+ points and won
        wonByComeback = gameData['wasComeback'] ?? false;
      }

      // Check if this was a disco bowling game
      bool isDisco = gameData['isDisco'] ?? false;

      // Return enriched game data with calculated statistics
      return {
        ...gameData,
        'isFirstGame': isFirstGame,
        'consecutiveStrikes': maxConsecutiveStrikes,
        'totalStrikes': totalStrikes,
        'spares': spares,
        'gutterBalls': gutterBalls,
        'wonByComeback': wonByComeback,
        'isDisco': isDisco,
      };
    } catch (e) {
      print('Error calculating game stats: $e');
      // Return original game data if there was an error
      return {...gameData, 'isFirstGame': await _isUsersFirstGame(userId)};
    }
  }

  /// Check if this is the user's first game
  Future<bool> _isUsersFirstGame(String userId) async {
    try {
      // Query Firestore for games created by this user
      final QuerySnapshot gamesSnapshot = await _firestore
          .collection('games')
          .where('createdBy', isEqualTo: userId)
          .limit(1)
          .get();

      // This is the user's first game if no previous games were found
      return gamesSnapshot.docs.isEmpty;
    } catch (e) {
      print('Error checking if this is user\'s first game: $e');
      return false;
    }
  }

  /// Method to test achievement awarding with simulated game data
  Future<List<String>> testGameCompletionWithMockData({String? userId}) async {
    final String uid = userId ?? _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      print('No user ID available for testing');
      return [];
    }

    try {
      // Ensure badge data is in the right format before testing
      print('🔄 DEBUG: Migrating badge format before testing');
      await _badgeService.migrateBadgesFormat(userId: uid);

      // Create mock game data
      final Map<String, dynamic> mockGameData = {
        'score': 220,
        'date': DateTime.now(),
        'location': 'Test Bowling Alley',
        'playerCount': 4,
        'isDisco': false,
        'wasComeback': true,
        'throwsPerFrame': [
          [10], // Frame 1: Strike
          [10], // Frame 2: Strike
          [10], // Frame 3: Strike
          [9, 1], // Frame 4: Spare
          [8, 2], // Frame 5: Spare
          [7, 3], // Frame 6: Spare
          [10], // Frame 7: Strike
          [9, 1], // Frame 8: Spare
          [10], // Frame 9: Strike
          [10, 10, 10], // Frame 10: Three strikes
        ],
      };

      // Process the mock game completion
      return await processGameCompletion(
        gameData: mockGameData,
        userId: uid,
      );
    } catch (e) {
      print('❌ DEBUG: Error during test badge check: $e');
      return [];
    }
  }

  // Check for achievements when a game is completed
  Future<void> checkForAchievements(LiveGame game, String userId) async {
    print(
        '🎮 DEBUG: Checking achievements for game ${game.id} by user $userId');
    final BadgeService badgeService = BadgeService();

    try {
      // Get the user's current stats
      final userStats = await getUserStats(userId);
      print('📊 DEBUG: User stats for achievement check: $userStats');

      // Achievement: First Game Completed
      if (userStats['totalGames'] == 1) {
        print('🔍 DEBUG: First game detected, awarding first_game badge');
        await badgeService.awardBadge('first_game', userId: userId);
      }

      // Achievement: Perfect Game (Score 300)
      if (game.players.isNotEmpty && game.players.first.totalScore == 300) {
        print(
            '🔍 DEBUG: Perfect game detected (300), awarding perfect_game badge');
        await badgeService.awardBadge('perfect_game', userId: userId);
      }

      // Achievement: Century Club (Score 100+)
      if (game.players.isNotEmpty && game.players.first.totalScore >= 100) {
        print(
            '🔍 DEBUG: Score 100+ detected (${game.players.first.totalScore}), awarding century_club badge');
        await badgeService.awardBadge('century_club', userId: userId);
      }

      // Achievement: Triple Digit Master (Score 100+ in 5 games)
      if (userStats['gamesAbove100'] >= 5) {
        print(
            '🔍 DEBUG: 5+ games with score 100+ detected, awarding triple_digit_master badge');
        await badgeService.awardBadge('triple_digit_master', userId: userId);
      }

      // Achievement: Bowling Enthusiast (10+ games)
      if (userStats['totalGames'] >= 10) {
        print(
            '🔍 DEBUG: 10+ total games detected, awarding bowling_enthusiast badge');
        await badgeService.awardBadge('bowling_enthusiast', userId: userId);
      }

      // Achievement: Frame Perfect (All strikes in a single frame across all players)
      bool frameHasAllStrikes = false;
      for (int frameIndex = 0; frameIndex < 10; frameIndex++) {
        bool allStrikesInFrame = true;
        for (final player in game.players) {
          if (player.frames.length <= frameIndex ||
              !player.frames[frameIndex].isStrike) {
            allStrikesInFrame = false;
            break;
          }
        }
        if (allStrikesInFrame && game.players.length > 1) {
          frameHasAllStrikes = true;
          break;
        }
      }

      if (frameHasAllStrikes) {
        print(
            '🔍 DEBUG: Frame with all strikes detected, awarding frame_perfect badge');
        await badgeService.awardBadge('frame_perfect', userId: userId);
      }

      print('✅ DEBUG: Achievement check completed for game ${game.id}');
    } catch (e) {
      print('❌ DEBUG: Error checking achievements: $e');
    }
  }

  /// Get user statistics for achievement checks
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    print('📊 DEBUG: Fetching user stats for user $userId');
    try {
      // Default stats in case we can't find user data
      Map<String, dynamic> userStats = {
        'totalGames': 0,
        'gamesAbove100': 0,
        'highScore': 0,
        'averageScore': 0,
        'strikePercentage': 0,
        'sparePercentage': 0,
      };

      // Get user document from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        print('❌ DEBUG: User document not found for $userId');
        return userStats;
      }

      // Get stats from user document
      final userData = userDoc.data() as Map<String, dynamic>;

      // Get stats from userData or use defaults
      userStats['totalGames'] = userData['totalGames'] ?? 0;
      userStats['gamesAbove100'] = userData['gamesAbove100'] ?? 0;
      userStats['highScore'] = userData['highScore'] ?? 0;
      userStats['averageScore'] = userData['averageScore'] ?? 0;
      userStats['strikePercentage'] = userData['strikePercentage'] ?? 0;
      userStats['sparePercentage'] = userData['sparePercentage'] ?? 0;

      print('✅ DEBUG: Successfully retrieved user stats: $userStats');
      return userStats;
    } catch (e) {
      print('❌ DEBUG: Error fetching user stats: $e');
      // Return default stats in case of error
      return {
        'totalGames': 0,
        'gamesAbove100': 0,
        'highScore': 0,
        'averageScore': 0,
        'strikePercentage': 0,
        'sparePercentage': 0,
      };
    }
  }
}
