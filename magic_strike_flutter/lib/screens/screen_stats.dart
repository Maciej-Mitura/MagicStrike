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
    final List<int> gameScores = _recentScores.isNotEmpty
        ? _recentScores
        : [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; // Default empty scores

    // First ball stats from state
    final firstBallStats = _currentFirstBallStats;

    return Scaffold(
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
                    physics: const AlwaysScrollableScrollPhysics(),
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
                              Text(
                                'Last ${gameScores.length} games',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Score Graph
                          Container(
                            height: 300, // Fixed height for the graph
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16.0, 20, 16.0,
                                  40), // Reduced horizontal padding
                              child: _buildScoreGraph(gameScores),
                            ),
                          ),
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
  Widget _buildScoreGraph(List<int> scores) {
    return CustomPaint(
      size: const Size(double.infinity, double.infinity),
      painter: ScoreGraphPainter(scores: scores),
    );
  }
}

// Custom painter for the score graph
class ScoreGraphPainter extends CustomPainter {
  final List<int> scores;

  ScoreGraphPainter({required this.scores});

  @override
  void paint(Canvas canvas, Size size) {
    // Define constants
    const int maxYAxis = 300; // Maximum bowling score
    const int yAxisStep = 50; // Step size for Y-axis
    const int yAxisDivisions = maxYAxis ~/
        yAxisStep; // Will be 6 divisions (0, 50, 100, 150, 200, 250, 300)

    // Left and right margins within the graph area
    final double leftMargin = 10; // Reduced left margin
    final double rightMargin = 35; // Slightly reduced right margin
    final double graphWidth = size.width - leftMargin - rightMargin;

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

    // Draw Y-axis on the right side of the graph area
    canvas.drawLine(
      Offset(leftMargin + graphWidth, 0),
      Offset(leftMargin + graphWidth, size.height),
      axisPaint,
    );

    // Draw X-axis
    canvas.drawLine(
      Offset(leftMargin, size.height),
      Offset(leftMargin + graphWidth, size.height),
      axisPaint,
    );

    // Draw horizontal grid lines and Y-axis labels
    final yAxisTextStyle = const TextStyle(
      color: Colors.black,
      fontSize: 10,
    );

    for (int i = 0; i <= yAxisDivisions; i++) {
      final y = size.height - (i * size.height / yAxisDivisions);
      final score = i * yAxisStep; // Fixed increments of 50

      // Draw grid line
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(leftMargin + graphWidth, y),
        gridPaint,
      );

      // Draw Y-axis label outside the graph area
      final textSpan = TextSpan(
        text: score.toString(),
        style: yAxisTextStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();

      // Position the label to the right of the graph
      textPainter.paint(canvas,
          Offset(leftMargin + graphWidth + 10, y - textPainter.height / 2));
    }

    // Draw vertical grid lines and X-axis labels
    final xAxisTextStyle = const TextStyle(
      color: Colors.black,
      fontSize: 10,
    );

    for (int i = 0; i < scores.length; i++) {
      final x = leftMargin + (i * graphWidth / (scores.length - 1));

      // Draw grid line
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );

      // Draw X-axis label (game number)
      final textSpan = TextSpan(
        text: (i + 1).toString(),
        style: xAxisTextStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height + 10),
      );
    }

    // Draw the score graph line
    final path = Path();

    for (int i = 0; i < scores.length; i++) {
      final x = leftMargin + (i * graphWidth / (scores.length - 1));
      // Calculate y position based on fixed scale (0-300)
      final y = size.height - (scores[i] * size.height / maxYAxis);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      // Draw points at each data point
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }

    canvas.drawPath(path, graphPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
