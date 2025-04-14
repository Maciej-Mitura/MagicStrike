import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';

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

  // Map to store the current stats values
  Map<String, double> _currentFirstBallStats = {
    'strikes': 0,
    'leaves': 0,
    'splits': 0,
  };

  // Default values for when no backend data is available
  final Map<String, double> _defaultFirstBallStats = {
    'strikes': 50.0,
    'leaves': 35.0,
    'splits': 15.0,
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
  void _initializeData() {
    // Fetch data from backend or use defaults
    final firstBallData = fetchFirstBallStats();
    updateFirstBallStats(firstBallData);
  }

  // Method to fetch first ball stats - would connect to backend in real app
  Map<String, double> fetchFirstBallStats() {
    // This is where you would connect to your backend
    // For example:
    // try {
    //   final userDoc = await FirebaseFirestore.instance
    //     .collection('users')
    //     .doc(currentUserId)
    //     .get();
    //
    //   if (userDoc.exists) {
    //     final data = userDoc.data();
    //     return {
    //       'strikes': calculateStrikePercentage(data),
    //       'leaves': calculateLeavesPercentage(data),
    //       'splits': calculateSplitsPercentage(data),
    //     };
    //   }
    // } catch (e) {
    //   print('Error fetching data: $e');
    // }

    // If backend data retrieval fails or is not implemented yet,
    // return the default values
    return _defaultFirstBallStats;
  }

  // Method to update first ball stats with new data from backend
  void updateFirstBallStats(Map<String, double> newStats) {
    setState(() {
      _currentFirstBallStats = newStats;
    });

    // Reset and restart the animation
    _animationController.reset();
    _animationController.forward();
  }

  // Method to handle the refresh button tap
  void _refreshFirstBallStats() {
    // This calls the fetchFirstBallStats method which will
    // either return backend data or default values
    final freshData = fetchFirstBallStats();
    updateFirstBallStats(freshData);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder stats data (to be replaced with backend data later)
    final statsData = {
      'average': 165,
      'best': 245,
      'cleanPercentage': 30,
      'gamesPlayed': 28,
    };

    // Placeholder game scores for the graph (last 10 games)
    final List<int> gameScores = [
      145,
      237,
      182,
      92,
      268,
      153,
      197,
      120,
      255,
      178
    ];

    // Use the current stats values from the state
    final firstBallStats = _currentFirstBallStats;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
        physics: const BouncingScrollPhysics(),
        children: [
          // Overview Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overview',
                style: TextStyle(
                  fontSize: 32, // Increased to 32 as per Figma design
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

                    // Clean Game Percentage Box
                    _buildStatBox(
                      title: 'Clean%',
                      value: '${statsData['cleanPercentage']}%',
                    ),

                    // Games Played Box
                    _buildStatBox(
                      title: 'Games',
                      value: statsData['gamesPlayed'].toString(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 48), // Increased gap between sections

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
              Container(
                height: 300, // Fixed height for the graph
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      16.0, 20, 16.0, 40), // Reduced horizontal padding
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
                    onTap: _refreshFirstBallStats,
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
                height: 180, // Fixed height for the progress indicators
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Strikes percentage
                    _buildCircularProgressIndicator(
                      label: 'Strikes',
                      percentage: firstBallStats['strikes']!.toDouble(),
                      animation: _animation,
                    ),

                    // Leaves percentage
                    _buildCircularProgressIndicator(
                      label: 'Leaves',
                      percentage: firstBallStats['leaves']!.toDouble(),
                      animation: _animation,
                    ),

                    // Splits percentage
                    _buildCircularProgressIndicator(
                      label: 'Splits',
                      percentage: firstBallStats['splits']!.toDouble(),
                      animation: _animation,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to build a stat box
  Widget _buildStatBox({required String title, required String value}) {
    return Container(
      width: 120,
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
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
