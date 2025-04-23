import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/services/stats_service.dart';

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

  // State variables for stats
  bool _isLoading = true;
  bool _hasError = false;
  int _averageScore = 0;
  int _bestScore = 0;
  int _gamesPlayed = 0;
  int _cleanPercentage = 0;
  List<int> _recentScores = [];

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
      // Fetch all stats in parallel for better performance
      final averageScoreFuture = _statsService.calculateAverageScore();
      final bestScoreFuture = _statsService.getBestScore();
      final gamesPlayedFuture = _statsService.getGamesPlayed();
      final recentScoresFuture = _statsService.getRecentScores(10);
      final firstBallStatsFuture = _statsService.getFirstBallStats();
      final cleanPercentageFuture = _statsService.calculateCleanPercentage();

      // Wait for all stats to be fetched
      final averageScore = await averageScoreFuture;
      final bestScore = await bestScoreFuture;
      final gamesPlayed = await gamesPlayedFuture;
      final recentScores = await recentScoresFuture;
      final firstBallStats = await firstBallStatsFuture;
      final cleanPercentage = await cleanPercentageFuture;

      if (mounted) {
        setState(() {
          _averageScore = averageScore;
          _bestScore = bestScore;
          _gamesPlayed = gamesPlayed;
          _cleanPercentage = cleanPercentage;
          _recentScores = recentScores;
          _currentFirstBallStats = firstBallStats;
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

  // Method to handle the refresh button tap
  Future<void> _refreshStats() async {
    await _initializeData();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
}

// Custom painter for the score graph
class ScoreGraphPainter extends CustomPainter {
  final List<int> scores;

  ScoreGraphPainter({required this.scores});

  @override
  void paint(Canvas canvas, Size size) {
    // Ensure we always have 10 scores to display
    final List<int> displayScores = _getDisplayScores();

    if (displayScores.every((score) => score == 0)) {
      _drawNoDataMessage(canvas, size);
      return;
    }

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

    // Always use 10 games for X-axis
    final int gameCount = displayScores.length;
    final double xStep = graphWidth / (gameCount - 1);

    // Draw grid lines and X-axis labels for all games
    for (int i = 0; i < gameCount; i++) {
      final x = leftMargin + (i * xStep);

      // Draw vertical grid line
      canvas.drawLine(
        Offset(x, topMargin),
        Offset(x, topMargin + graphHeight),
        gridPaint,
      );

      // Draw X-axis label (just the number) for all games
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

    // Draw the path connecting ALL points, including zeros
    final path = Path();

    for (int i = 0; i < displayScores.length; i++) {
      final x = leftMargin + (i * xStep);
      final score = displayScores[i];
      final y = topMargin + graphHeight - (score * graphHeight / yAxisMax);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, graphPaint);

    // Draw points for all games, including zeros
    for (int i = 0; i < displayScores.length; i++) {
      final x = leftMargin + (i * xStep);
      final score = displayScores[i];
      final y = topMargin + graphHeight - (score * graphHeight / yAxisMax);

      // Draw point (even for zero scores)
      canvas.drawCircle(Offset(x, y), 5, pointPaint);
      canvas.drawCircle(Offset(x, y), 6, pointOuterPaint);

      // Draw score label above the point (only for non-zero scores)
      if (score > 0) {
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
  }

  // Get exactly 10 scores for display, with newest scores at the end
  List<int> _getDisplayScores() {
    if (scores.isEmpty) {
      return List.filled(10, 0);
    }

    List<int> result = List<int>.from(scores);

    // If we have fewer than 10 scores, pad with zeros at the beginning
    if (result.length < 10) {
      final leadingZeros = List.filled(10 - result.length, 0);
      result = [...leadingZeros, ...result];
    }

    // If we have more than
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
