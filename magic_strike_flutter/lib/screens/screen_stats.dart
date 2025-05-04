import 'package:flutter/material.dart';

import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/services/stats_service.dart';
import 'package:magic_strike_flutter/services/leaderboard_service.dart';
import 'package:magic_strike_flutter/services/user_service.dart';
import 'package:magic_strike_flutter/widgets/leaderboard_item.dart';
import 'package:magic_strike_flutter/widgets/strikes_leaderboard_item.dart';
import 'package:magic_strike_flutter/widgets/average_leaderboard_item.dart';
import 'package:magic_strike_flutter/widgets/dering_leaderboard_item.dart';
import 'package:magic_strike_flutter/widgets/strike_streak_leaderboard_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  // Animation controller for progress indicators
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Service for retrieving stats
  final StatsService _statsService = StatsService();
  final LeaderboardService _leaderboardService = LeaderboardService();
  final UserService _userService = UserService();

  // State variables for stats
  bool _isLoading = true;
  bool _hasError = false;
  int _averageScore = 0;
  int _bestScore = 0;
  int _gamesPlayed = 0;
  int _cleanPercentage = 0;
  int _longestStrikeStreak = 0;
  List<int> _recentScores = [];
  String? _currentUserId;

  // Leaderboard data
  List<Map<String, dynamic>> _scoreLeaderboardData = [];
  List<Map<String, dynamic>> _strikesLeaderboardData = [];
  List<Map<String, dynamic>> _averageLeaderboardData = [];
  List<Map<String, dynamic>> _deringLeaderboardData = [];
  List<Map<String, dynamic>> _strikeStreakLeaderboardData = [];
  bool _isLoadingScoreLeaderboard = true;
  bool _isLoadingStrikesLeaderboard = true;
  bool _isLoadingAverageLeaderboard = true;
  bool _isLoadingDeringLeaderboard = true;
  bool _isLoadingStrikeStreakLeaderboard = true;
  StreamSubscription? _scoreLeaderboardSubscription;
  StreamSubscription? _strikesLeaderboardSubscription;
  StreamSubscription? _averageLeaderboardSubscription;
  StreamSubscription? _deringLeaderboardSubscription;
  StreamSubscription? _strikeStreakLeaderboardSubscription;

  // Map to store the current stats values
  Map<String, double> _currentFirstBallStats = {
    'strikes': 0,
    'leaves': 0,
  };

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Start animation when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
      _setupLeaderboardListeners();
    });
  }

  // Method to initialize data and trigger animations
  Future<void> _initializeData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Get the current user's ID
      final userData = await _userService.getCurrentUserData();
      final String? deRingID = userData['deRingID'];

      // Fetch all stats in parallel for better performance
      final averageScoreFuture = _statsService.calculateAverageScore();
      final bestScoreFuture = _statsService.getBestScore();
      final gamesPlayedFuture = _statsService.getGamesPlayed();
      final recentScoresFuture = _statsService.getRecentScores(10);
      final firstBallStatsFuture = _statsService.getFirstBallStats();
      final cleanPercentageFuture = _statsService.calculateCleanPercentage();
      final strikeStreakFuture = _statsService.getLongestStrikeStreak();

      // Wait for all stats to be fetched
      final averageScore = await averageScoreFuture;
      final bestScore = await bestScoreFuture;
      final gamesPlayed = await gamesPlayedFuture;
      final recentScores = await recentScoresFuture;
      final firstBallStats = await firstBallStatsFuture;
      final cleanPercentage = await cleanPercentageFuture;
      final longestStrikeStreak = await strikeStreakFuture;

      if (mounted) {
        setState(() {
          _averageScore = averageScore;
          _bestScore = bestScore;
          _gamesPlayed = gamesPlayed;
          _cleanPercentage = cleanPercentage;
          _recentScores = recentScores;
          _currentFirstBallStats = firstBallStats;
          _longestStrikeStreak = longestStrikeStreak;
          _currentUserId = deRingID;
          _isLoading = false;
        });

        // Start animation after data is loaded
        _animationController.reset();
        _animationController.forward();
      }
    } catch (e) {
      print('Error loading stats: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  // Set up real-time listener for leaderboard updates
  void _setupLeaderboardListeners() {
    _leaderboardService.initLeaderboardListener();

    // Score leaderboard subscription
    _scoreLeaderboardSubscription =
        _leaderboardService.scoreLeaderboardStream.listen((leaderboardData) {
      if (mounted) {
        setState(() {
          _scoreLeaderboardData = leaderboardData;
          _isLoadingScoreLeaderboard = false;
        });
      }
    }, onError: (error) {
      print('Error from score leaderboard stream: $error');
      if (mounted) {
        setState(() {
          _isLoadingScoreLeaderboard = false;
        });
      }
    });

    // Strikes leaderboard subscription
    _strikesLeaderboardSubscription =
        _leaderboardService.strikesLeaderboardStream.listen((leaderboardData) {
      if (mounted) {
        setState(() {
          _strikesLeaderboardData = leaderboardData;
          _isLoadingStrikesLeaderboard = false;
        });
      }
    }, onError: (error) {
      print('Error from strikes leaderboard stream: $error');
      if (mounted) {
        setState(() {
          _isLoadingStrikesLeaderboard = false;
        });
      }
    });

    // Average score leaderboard subscription
    _averageLeaderboardSubscription =
        _leaderboardService.averageLeaderboardStream.listen((leaderboardData) {
      if (mounted) {
        setState(() {
          _averageLeaderboardData = leaderboardData;
          _isLoadingAverageLeaderboard = false;
        });
      }
    }, onError: (error) {
      print('Error from average leaderboard stream: $error');
      if (mounted) {
        setState(() {
          _isLoadingAverageLeaderboard = false;
        });
      }
    });

    // Strike Streak leaderboard subscription
    _strikeStreakLeaderboardSubscription = _leaderboardService
        .strikeStreakLeaderboardStream
        .listen((leaderboardData) {
      if (mounted) {
        setState(() {
          _strikeStreakLeaderboardData = leaderboardData;
          _isLoadingStrikeStreakLeaderboard = false;
        });
      }
    }, onError: (error) {
      print('Error from strike streak leaderboard stream: $error');
      if (mounted) {
        setState(() {
          _isLoadingStrikeStreakLeaderboard = false;
        });
      }
    });

    // DeRing score leaderboard subscription
    _deringLeaderboardSubscription =
        _leaderboardService.deringLeaderboardStream.listen((leaderboardData) {
      if (mounted) {
        setState(() {
          _deringLeaderboardData = leaderboardData;
          _isLoadingDeringLeaderboard = false;
        });
      }
    }, onError: (error) {
      print('Error from DeRing leaderboard stream: $error');
      if (mounted) {
        setState(() {
          _isLoadingDeringLeaderboard = false;
        });
      }
    });

    // Initial load
    _loadLeaderboardData();
  }

  // Method to load leaderboard data
  Future<void> _loadLeaderboardData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingScoreLeaderboard = true;
      _isLoadingStrikesLeaderboard = true;
      _isLoadingAverageLeaderboard = true;
      _isLoadingStrikeStreakLeaderboard = true;
      _isLoadingDeringLeaderboard = true;

      // Clear previous data to ensure fresh results
      _scoreLeaderboardData = [];
      _strikesLeaderboardData = [];
      _averageLeaderboardData = [];
      _strikeStreakLeaderboardData = [];
      _deringLeaderboardData = [];
    });

    try {
      // Load all leaderboards in parallel
      final scoreLeaderboardFuture =
          _leaderboardService.getTopScoresThisMonth();
      final strikesLeaderboardFuture =
          _leaderboardService.getTopStrikesPercentageThisMonth();
      final averageLeaderboardFuture =
          _leaderboardService.getTopAverageScoreThisMonth();
      final strikeStreakLeaderboardFuture =
          _leaderboardService.getTopStrikeStreakThisMonth();
      final deringLeaderboardFuture =
          _leaderboardService.getTopDeRingScoreThisMonth();

      // Wait for all futures to complete
      final List<dynamic> results = await Future.wait([
        scoreLeaderboardFuture,
        strikesLeaderboardFuture,
        averageLeaderboardFuture,
        strikeStreakLeaderboardFuture,
        deringLeaderboardFuture,
      ]);

      if (mounted) {
        setState(() {
          _scoreLeaderboardData = results[0];
          _strikesLeaderboardData = results[1];
          _averageLeaderboardData = results[2];
          _strikeStreakLeaderboardData = results[3];
          _deringLeaderboardData = results[4];
          _isLoadingScoreLeaderboard = false;
          _isLoadingStrikesLeaderboard = false;
          _isLoadingAverageLeaderboard = false;
          _isLoadingStrikeStreakLeaderboard = false;
          _isLoadingDeringLeaderboard = false;
        });
      }
    } catch (e) {
      print('Error loading leaderboards: $e');
      if (mounted) {
        setState(() {
          _isLoadingScoreLeaderboard = false;
          _isLoadingStrikesLeaderboard = false;
          _isLoadingAverageLeaderboard = false;
          _isLoadingStrikeStreakLeaderboard = false;
          _isLoadingDeringLeaderboard = false;
        });
      }
    }
  }

  // Method to handle the refresh button tap
  Future<void> _refreshStats() async {
    // Create a unique key to force widget rebuilds
    final uniqueKey = DateTime.now().microsecondsSinceEpoch.toString();

    // Clear existing leaderboard data to ensure fresh data including profile pictures
    setState(() {
      _isLoading = true;
      _isLoadingScoreLeaderboard = true;
      _isLoadingStrikesLeaderboard = true;
      _isLoadingAverageLeaderboard = true;
      _isLoadingStrikeStreakLeaderboard = true;
      _isLoadingDeringLeaderboard = true;
      _scoreLeaderboardData = [];
      _strikesLeaderboardData = [];
      _averageLeaderboardData = [];
      _strikeStreakLeaderboardData = [];
      _deringLeaderboardData = [];
    });

    // Clear network image cache to ensure new profile pictures are loaded
    await _clearImageCache();

    // Now reload all stats and leaderboard data
    await _initializeData();
    await _loadLeaderboardDataForced();
  }

  // Load leaderboard data with forced refresh
  Future<void> _loadLeaderboardDataForced() async {
    if (!mounted) return;

    setState(() {
      _isLoadingScoreLeaderboard = true;
      _isLoadingStrikesLeaderboard = true;
      _isLoadingAverageLeaderboard = true;
      _isLoadingStrikeStreakLeaderboard = true;
      _isLoadingDeringLeaderboard = true;

      // Clear previous data to ensure fresh results
      _scoreLeaderboardData = [];
      _strikesLeaderboardData = [];
      _averageLeaderboardData = [];
      _strikeStreakLeaderboardData = [];
      _deringLeaderboardData = [];
    });

    try {
      // Force Firestore to refresh its connection
      await FirebaseFirestore.instance.terminate();
      await FirebaseFirestore.instance.waitForPendingWrites();

      // Load all leaderboards in parallel
      final scoreLeaderboardFuture =
          _leaderboardService.getTopScoresThisMonth();
      final strikesLeaderboardFuture =
          _leaderboardService.getTopStrikesPercentageThisMonth();
      final averageLeaderboardFuture =
          _leaderboardService.getTopAverageScoreThisMonth();
      final strikeStreakLeaderboardFuture =
          _leaderboardService.getTopStrikeStreakThisMonth();
      final deringLeaderboardFuture =
          _leaderboardService.getTopDeRingScoreThisMonth();

      // Wait for all futures to complete
      final List<dynamic> results = await Future.wait([
        scoreLeaderboardFuture,
        strikesLeaderboardFuture,
        averageLeaderboardFuture,
        strikeStreakLeaderboardFuture,
        deringLeaderboardFuture,
      ]);

      if (mounted) {
        setState(() {
          _scoreLeaderboardData = results[0];
          _strikesLeaderboardData = results[1];
          _averageLeaderboardData = results[2];
          _strikeStreakLeaderboardData = results[3];
          _deringLeaderboardData = results[4];
          _isLoadingScoreLeaderboard = false;
          _isLoadingStrikesLeaderboard = false;
          _isLoadingAverageLeaderboard = false;
          _isLoadingStrikeStreakLeaderboard = false;
          _isLoadingDeringLeaderboard = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading leaderboards: $e');
      if (mounted) {
        setState(() {
          _isLoadingScoreLeaderboard = false;
          _isLoadingStrikesLeaderboard = false;
          _isLoadingAverageLeaderboard = false;
          _isLoadingStrikeStreakLeaderboard = false;
          _isLoadingDeringLeaderboard = false;
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to clear image cache
  Future<void> _clearImageCache() async {
    try {
      // Using PaintingBinding to clear image cache
      print('Clearing image cache...');
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Wait a brief moment to ensure cache clearing completes
      await Future.delayed(const Duration(milliseconds: 300));

      // Force a garbage collection cycle by creating pressure
      List<Widget> temp = [];
      for (int i = 0; i < 1000; i++) {
        temp.add(Container(width: 1, height: 1));
      }
      temp.clear();
    } catch (e) {
      print('Error clearing image cache: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scoreLeaderboardSubscription?.cancel();
    _strikesLeaderboardSubscription?.cancel();
    _averageLeaderboardSubscription?.cancel();
    _strikeStreakLeaderboardSubscription?.cancel();
    _deringLeaderboardSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Stats data from the state
    final statsData = {
      'average': _averageScore,
      'best': _bestScore,
      'cleanPercentage': _cleanPercentage,
      'gamesPlayed': _gamesPlayed,
      'strikeStreak': _longestStrikeStreak,
    };

    // Use recent scores or empty list if none available
    // ignore: unused_local_variable
    final List<int> gameScores = _recentScores.isNotEmpty
        ? _recentScores
        : [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; // Default empty scores

    // First ball stats from state
    final firstBallStats = _currentFirstBallStats;

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.white,
      body: _isLoading
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
                        'Error loading statistics',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _refreshStats,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ringPrimary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshStats,
                  color: AppColors.ringPrimary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics()),
                    children: [
                      // Overview Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overview',
                            style: TextStyle(
                              fontSize:
                                  32, // Increased to 32 as per Figma design
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Horizontally scrollable stats boxes
                          SizedBox(
                            height: 120, // Fixed height for the stat boxes
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children: [
                                // Games Played Box
                                _buildStatBox(
                                  title: 'Games',
                                  value: statsData['gamesPlayed'].toString(),
                                ),

                                // Average Score Box
                                _buildStatBox(
                                  title: 'Avg',
                                  value: statsData['average'].toString(),
                                ),

                                // Best Score Box
                                _buildStatBox(
                                  title: 'Best',
                                  value: statsData['best'].toString(),
                                ),

                                // Strike/Spare Percentage Box
                                _buildStatBox(
                                  title: 'Strike/Spare',
                                  value: '${statsData['cleanPercentage']}%',
                                ),

                                // Strike Streak Box
                                _buildStatBox(
                                  title: 'Strike Streak',
                                  value: statsData['strikeStreak'].toString(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                          height: 48), // Increased gap between sections

                      // Score Graph Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row with Score and Last 10 games
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Score',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const Text(
                                'Last 10 games',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Score Graph
                          _buildScoreGraph(),
                        ],
                      ),

                      const SizedBox(height: 48), // Gap between sections

                      // First Ball Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row with First ball and Refresh button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'First ball',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              GestureDetector(
                                onTap: _refreshStats,
                                child: const Text(
                                  'Refresh',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Horizontally scrollable circular progress indicators
                          SizedBox(
                            height:
                                180, // Fixed height for the progress indicators
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children: [
                                // Strikes percentage
                                _buildCircularProgressIndicator(
                                  label: 'Strikes',
                                  percentage:
                                      firstBallStats['strikes']!.toDouble(),
                                  animation: _animation,
                                ),

                                // Leaves percentage
                                _buildCircularProgressIndicator(
                                  label: 'Leaves',
                                  percentage:
                                      firstBallStats['leaves']!.toDouble(),
                                  animation: _animation,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48), // Gap between sections

                      // Leaderboard Section - Both Score and Strikes %
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row with Leaderboard and This month
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Leaderboard',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const Text(
                                'This month',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Combined leaderboard container
                          _buildCombinedLeaderboard(),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  // Helper method to build a stat box
  Widget _buildStatBox({required String title, required String value}) {
    return Container(
      width: title.length > 5 ? 140 : 120, // Wider for longer titles
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: AppColors.ringBackground3rd,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title at the top
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const Spacer(), // Push value to the bottom
            // Value with larger font
            Text(
              value,
              style: const TextStyle(
                fontSize: 30, // Increased font size for better visibility
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build a circular progress indicator
  Widget _buildCircularProgressIndicator({
    required String label,
    required double percentage,
    required Animation<double> animation,
  }) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated circular progress indicator
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: animation.value * (percentage / 100),
                      strokeWidth: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.ringPrimary),
                    ),
                  ),
                  // Animated percentage text
                  Text(
                    '${(animation.value * percentage).toInt()}%',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          // Label below the progress indicator
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build the score graph
  Widget _buildScoreGraph() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16.0),
                child: Text(
                  "Score History",
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Make the graph responsive to screen size
                  final width = constraints.maxWidth;
                  final height = width * 0.65; // Maintain aspect ratio

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CustomPaint(
                      size: Size(width, height),
                      painter: ScoreGraphPainter(scores: _recentScores),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper method to build the combined leaderboard
  Widget _buildCombinedLeaderboard() {
    if (_isLoadingScoreLeaderboard ||
        _isLoadingStrikesLeaderboard ||
        _isLoadingAverageLeaderboard ||
        _isLoadingStrikeStreakLeaderboard ||
        _isLoadingDeringLeaderboard) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show empty state if all leaderboards are empty
    if (_scoreLeaderboardData.isEmpty &&
        _strikesLeaderboardData.isEmpty &&
        _averageLeaderboardData.isEmpty &&
        _strikeStreakLeaderboardData.isEmpty &&
        _deringLeaderboardData.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Be the first up here!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Play games to see your ranking',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // Single container for all leaderboards
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(12.0),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Best Score Section
          if (_scoreLeaderboardData.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                "Best Score",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_scoreLeaderboardData.length, (index) {
              final player = _scoreLeaderboardData[index];
              final bool isCurrentUser = player['userId'] == _currentUserId;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: LeaderboardItem(
                  userId: player['userId'],
                  firstName: player['firstName'],
                  lastName: player['lastName'] ?? '',
                  score: player['score'],
                  profileUrl: player['profileUrl'] ?? '',
                  rank: index + 1,
                  isCurrentUser: isCurrentUser,
                ),
              );
            }),
          ],

          // Add divider between sections if there's content above and below
          if (_scoreLeaderboardData.isNotEmpty &&
              (_strikesLeaderboardData.isNotEmpty ||
                  _averageLeaderboardData.isNotEmpty ||
                  _strikeStreakLeaderboardData.isNotEmpty ||
                  _deringLeaderboardData.isNotEmpty)) ...[
            const SizedBox(height: 24),
            Divider(color: Colors.grey.shade300, thickness: 1.5),
            const SizedBox(height: 16),
          ],

          // Game Average Section
          if (_averageLeaderboardData.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                "Game Average",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_averageLeaderboardData.length, (index) {
              final player = _averageLeaderboardData[index];
              final bool isCurrentUser = player['userId'] == _currentUserId;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: AverageLeaderboardItem(
                  userId: player['userId'],
                  firstName: player['firstName'],
                  lastName: player['lastName'] ?? '',
                  average: player['average'],
                  profileUrl: player['profileUrl'] ?? '',
                  rank: index + 1,
                  isCurrentUser: isCurrentUser,
                ),
              );
            }),
          ],

          // Add divider between sections if there's content above and below
          if ((_scoreLeaderboardData.isNotEmpty ||
                  _averageLeaderboardData.isNotEmpty) &&
              (_strikesLeaderboardData.isNotEmpty ||
                  _strikeStreakLeaderboardData.isNotEmpty ||
                  _deringLeaderboardData.isNotEmpty)) ...[
            const SizedBox(height: 24),
            Divider(color: Colors.grey.shade300, thickness: 1.5),
            const SizedBox(height: 16),
          ],

          // Strikes % Section
          if (_strikesLeaderboardData.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                "Strikes %",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_strikesLeaderboardData.length, (index) {
              final player = _strikesLeaderboardData[index];
              final bool isCurrentUser = player['userId'] == _currentUserId;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: StrikesLeaderboardItem(
                  userId: player['userId'],
                  firstName: player['firstName'],
                  lastName: player['lastName'] ?? '',
                  percentage: player['percentage'],
                  profileUrl: player['profileUrl'] ?? '',
                  rank: index + 1,
                  isCurrentUser: isCurrentUser,
                ),
              );
            }),
          ],

          // Add divider between Strikes % and Strike Streak sections if needed
          if ((_scoreLeaderboardData.isNotEmpty ||
                  _averageLeaderboardData.isNotEmpty ||
                  _strikesLeaderboardData.isNotEmpty) &&
              (_strikeStreakLeaderboardData.isNotEmpty ||
                  _deringLeaderboardData.isNotEmpty)) ...[
            const SizedBox(height: 24),
            Divider(color: Colors.grey.shade300, thickness: 1.5),
            const SizedBox(height: 16),
          ],

          // Strike Streak Section
          if (_strikeStreakLeaderboardData.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                "Strike Streak",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_strikeStreakLeaderboardData.length, (index) {
              final player = _strikeStreakLeaderboardData[index];
              final bool isCurrentUser = player['userId'] == _currentUserId;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: StrikeStreakLeaderboardItem(
                  userId: player['userId'],
                  firstName: player['firstName'],
                  lastName: player['lastName'] ?? '',
                  strikeStreak: player['strikeStreak'],
                  profileUrl: player['profileUrl'] ?? '',
                  rank: index + 1,
                  isCurrentUser: isCurrentUser,
                ),
              );
            }),
          ],

          // Add divider before DeRing section if needed
          if ((_scoreLeaderboardData.isNotEmpty ||
                  _averageLeaderboardData.isNotEmpty ||
                  _strikesLeaderboardData.isNotEmpty ||
                  _strikeStreakLeaderboardData.isNotEmpty) &&
              _deringLeaderboardData.isNotEmpty) ...[
            const SizedBox(height: 24),
            Divider(color: Colors.grey.shade300, thickness: 1.5),
            const SizedBox(height: 16),
          ],

          // DeRing Score Section
          if (_deringLeaderboardData.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                "DeRing Score",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_deringLeaderboardData.length, (index) {
              final player = _deringLeaderboardData[index];
              final bool isCurrentUser = player['userId'] == _currentUserId;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: DeRingLeaderboardItem(
                  userId: player['userId'],
                  firstName: player['firstName'],
                  lastName: player['lastName'] ?? '',
                  deringScore: player['deringScore'],
                  profileUrl: player['profileUrl'] ?? '',
                  rank: index + 1,
                  isCurrentUser: isCurrentUser,
                ),
              );
            }),
          ],

          // Empty states for each section if data is missing but other sections have data
          if (_scoreLeaderboardData.isEmpty &&
              (_strikesLeaderboardData.isNotEmpty ||
                  _averageLeaderboardData.isNotEmpty ||
                  _strikeStreakLeaderboardData.isNotEmpty ||
                  _deringLeaderboardData.isNotEmpty)) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                "Best Score",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildEmptySection(
                Icons.emoji_events_outlined, 'No score data yet'),
            const SizedBox(height: 24),
            Divider(color: Colors.grey.shade300, thickness: 1.5),
            const SizedBox(height: 16),
          ],

          if (_averageLeaderboardData.isEmpty &&
              (_scoreLeaderboardData.isNotEmpty ||
                  _strikesLeaderboardData.isNotEmpty ||
                  _strikeStreakLeaderboardData.isNotEmpty ||
                  _deringLeaderboardData.isNotEmpty)) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                "Game Average",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildEmptySection(Icons.trending_up, 'No average data yet'),
            const SizedBox(height: 24),
            Divider(color: Colors.grey.shade300, thickness: 1.5),
            const SizedBox(height: 16),
          ],

          if (_strikesLeaderboardData.isEmpty &&
              (_scoreLeaderboardData.isNotEmpty ||
                  _averageLeaderboardData.isNotEmpty ||
                  _strikeStreakLeaderboardData.isNotEmpty ||
                  _deringLeaderboardData.isNotEmpty)) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                "Strikes %",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildEmptySection(Icons.sports_cricket, 'No strike data yet'),
            const SizedBox(height: 24),
            Divider(color: Colors.grey.shade300, thickness: 1.5),
            const SizedBox(height: 16),
          ],

          if (_strikeStreakLeaderboardData.isEmpty &&
              (_scoreLeaderboardData.isNotEmpty ||
                  _averageLeaderboardData.isNotEmpty ||
                  _strikesLeaderboardData.isNotEmpty ||
                  _deringLeaderboardData.isNotEmpty)) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                "Strike Streak",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildEmptySection(Icons.bolt, 'No strike streak data yet'),
            const SizedBox(height: 24),
            Divider(color: Colors.grey.shade300, thickness: 1.5),
            const SizedBox(height: 16),
          ],

          if (_deringLeaderboardData.isEmpty &&
              (_scoreLeaderboardData.isNotEmpty ||
                  _averageLeaderboardData.isNotEmpty ||
                  _strikesLeaderboardData.isNotEmpty ||
                  _strikeStreakLeaderboardData.isNotEmpty)) ...[
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                "DeRing Score",
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildEmptySection(Icons.looks, 'No DeRing score data yet'),
          ],
        ],
      ),
    );
  }

  // Helper method to build empty section placeholder
  Widget _buildEmptySection(IconData icon, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 36,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for the score graph
class ScoreGraphPainter extends CustomPainter {
  final List<int> scores;

  ScoreGraphPainter({required this.scores});

  @override
  void paint(Canvas canvas, Size size) {
    // Get the scores to display (only non-zero scores)
    final List<int> actualScores = _getDisplayScores();

    // Always use fixed scale from 0 to 300
    final int yAxisMax = 300;
    final int yAxisStep = 50;
    final int yAxisDivisions = yAxisMax ~/ yAxisStep;

    // Left and right margins within the graph area
    final double leftMargin = 10; // Reduced left margin (no left Y-axis)
    final double rightMargin = 35; // For right labels
    final double topMargin = 20; // For top padding
    final double bottomMargin = 40; // Increased for X-axis title
    final double graphWidth = size.width - leftMargin - rightMargin;
    final double graphHeight = size.height - topMargin - bottomMargin;

    // Paints
    final axisPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;

    final graphPaint = Paint()
      ..color = AppColors.ringPrimary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = AppColors.ringPrimary
      ..strokeWidth = 5
      ..style = PaintingStyle.fill;

    final pointOuterPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw Y-axis only on the right side
    canvas.drawLine(
      Offset(leftMargin + graphWidth, topMargin),
      Offset(leftMargin + graphWidth, topMargin + graphHeight),
      axisPaint,
    );

    // Draw X-axis
    canvas.drawLine(
      Offset(leftMargin, topMargin + graphHeight),
      Offset(leftMargin + graphWidth, topMargin + graphHeight),
      axisPaint,
    );

    // Draw horizontal grid lines and Y-axis labels (right side only)
    final yAxisTextStyle = const TextStyle(
      color: Colors.black,
      fontSize: 10,
    );

    for (int i = 0; i <= yAxisDivisions; i++) {
      final y = topMargin + (graphHeight - (i * graphHeight / yAxisDivisions));
      final score = i * yAxisStep;

      // Draw grid line
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(leftMargin + graphWidth, y),
        gridPaint,
      );

      // Right label only
      final textSpan = TextSpan(
        text: score.toString(),
        style: yAxisTextStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(leftMargin + graphWidth + 8, y - textPainter.height / 2));
    }

    // Always display 10 x-axis positions
    final int totalXPositions = 10;
    final double xStep = graphWidth / (totalXPositions - 1);

    // Draw grid lines and X-axis labels for all 10 potential games
    for (int i = 0; i < totalXPositions; i++) {
      final x = leftMargin + (i * xStep);

      // Draw vertical grid line
      canvas.drawLine(
        Offset(x, topMargin),
        Offset(x, topMargin + graphHeight),
        gridPaint,
      );

      // Draw X-axis label (just the number) for all positions
      final textSpan = TextSpan(
        text: (i + 1).toString(),
        style: yAxisTextStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, topMargin + graphHeight + 5),
      );
    }

    // Draw X-axis title "Games"
    final xAxisTitleSpan = TextSpan(
      text: "Games",
      style: const TextStyle(
        color: Colors.black,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
    final xAxisTitlePainter = TextPainter(
      text: xAxisTitleSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    xAxisTitlePainter.layout();
    xAxisTitlePainter.paint(
      canvas,
      Offset(
        (size.width - xAxisTitlePainter.width) / 2,
        size.height - xAxisTitlePainter.height - 5,
      ),
    );

    if (actualScores.isEmpty) {
      _drawNoDataMessage(canvas, size);
      return;
    }

    // Place the actual scores in the most recent positions (right side of graph)
    // For example, if there are 3 scores and 10 positions, place them at positions 8, 9, 10
    final int startPosition = totalXPositions - actualScores.length;

    // Draw the path connecting only the actual score points
    if (actualScores.length > 1) {
      final path = Path();
      bool firstPoint = true;

      for (int i = 0; i < actualScores.length; i++) {
        final graphPosition = startPosition + i;
        final x = leftMargin + (graphPosition * xStep);
        final score = actualScores[i];
        final y = topMargin + graphHeight - (score * graphHeight / yAxisMax);

        if (firstPoint) {
          path.moveTo(x, y);
          firstPoint = false;
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, graphPaint);
    }

    // Draw points for all actual scores
    for (int i = 0; i < actualScores.length; i++) {
      final graphPosition = startPosition + i;
      final x = leftMargin + (graphPosition * xStep);
      final score = actualScores[i];
      final y = topMargin + graphHeight - (score * graphHeight / yAxisMax);

      // Draw point
      canvas.drawCircle(Offset(x, y), 5, pointPaint);
      canvas.drawCircle(Offset(x, y), 6, pointOuterPaint);

      // Draw score label above the point
      final textSpan = TextSpan(
        text: score.toString(),
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height - 6),
      );
    }
  }

  // Get exactly 10 scores for display, with newest scores at the end
  List<int> _getDisplayScores() {
    if (scores.isEmpty) {
      return []; // Return empty list instead of filling with zeros
    }

    List<int> result = List<int>.from(scores);

    // Filter out any zero scores
    result = result.where((score) => score > 0).toList();

    // If we have more than 10 scores, just keep the 10 most recent
    if (result.length > 10) {
      result = result.sublist(result.length - 10);
    }

    return result;
  }

  // Draw a message when no data is available
  void _drawNoDataMessage(Canvas canvas, Size size) {
    const message = 'No score data available';
    final textSpan = TextSpan(
      text: message,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is ScoreGraphPainter) {
      // Only repaint if scores have changed
      if (scores.length != oldDelegate.scores.length) return true;

      for (int i = 0; i < scores.length; i++) {
        if (scores[i] != oldDelegate.scores[i]) return true;
      }
      return false;
    }
    return true;
  }
}
