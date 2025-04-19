import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';
import 'package:magic_strike_flutter/services/game_history_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GamesHistoryScreen extends StatefulWidget {
  const GamesHistoryScreen({super.key});

  @override
  State<GamesHistoryScreen> createState() => _GamesHistoryScreenState();
}

class _GamesHistoryScreenState extends State<GamesHistoryScreen> {
  // Keep track of which game cards are expanded
  final Map<String, bool> _expandedGames = <String, bool>{};

  // Game history data
  List<Map<String, dynamic>> _gameHistory = [];
  DocumentSnapshot? _lastLoadedDocument;

  // State variables
  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoadingMore = false;
  bool _hasMoreGames = true;

  // Service
  final GameHistoryService _gameHistoryService = GameHistoryService();

  @override
  void initState() {
    super.initState();
    _fetchGameHistory();
  }

  /// Fetch initial game history data
  Future<void> _fetchGameHistory() async {
    // Don't proceed if the widget is no longer in the tree
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final games = await _gameHistoryService.getGameHistory();

      // Check if still mounted after async operation
      if (!mounted) return;

      setState(() {
        _gameHistory = games;
        _isLoading = false;

        // Check if we should enable "load more" functionality
        if (games.isNotEmpty) {
          _lastLoadedDocument = games.last['lastDocument'];
          _hasMoreGames = games.length >=
              5; // If we got a full batch, assume there are more
        } else {
          _hasMoreGames = false;
        }
      });
    } catch (e) {
      print('Error in GamesHistoryScreen: $e');

      // Check if still mounted after async operation
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// Load more games (pagination)
  Future<void> _loadMoreGames() async {
    // Don't do anything if we're already loading or there are no more games
    if (_isLoadingMore || !_hasMoreGames || _lastLoadedDocument == null) {
      return;
    }

    // Don't proceed if the widget is no longer in the tree
    if (!mounted) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      final moreGames = await _gameHistoryService.getGameHistory(
        lastDocument: _lastLoadedDocument,
      );

      // Check if still mounted after async operation
      if (!mounted) return;

      setState(() {
        // Add new games to the existing list
        _gameHistory.addAll(moreGames);
        _isLoadingMore = false;

        // Update pagination state
        if (moreGames.isNotEmpty) {
          _lastLoadedDocument = moreGames.last['lastDocument'];
          _hasMoreGames = moreGames.length >=
              5; // If we got a full batch, assume there are more
        } else {
          _hasMoreGames = false;
        }
      });
    } catch (e) {
      print('Error loading more games: $e');

      // Check if still mounted after async operation
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  /// Refresh the game history
  Future<void> _refreshGameHistory() async {
    // Don't proceed if the widget is no longer in the tree
    if (!mounted) return;

    setState(() {
      _lastLoadedDocument = null;
      _hasMoreGames = true;
    });

    await _fetchGameHistory();
  }

  // Toggle the expansion state of a game card
  void _toggleGameExpansion(String gameId) {
    setState(() {
      final String id = gameId.toString(); // Ensure the ID is a String
      _expandedGames[id] = !(_expandedGames[id] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Fixed custom app bar that matches home screen height
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(
                left: 24.0, right: 24.0, top: 50.0, bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Game History',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Transform.translate(
                        offset: const Offset(0, 2),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.grey[600],
                                      strokeWidth: 2.0,
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: _refreshGameHistory,
                                    behavior: HitTestBehavior.opaque,
                                    child: Icon(
                                      Icons.refresh,
                                      color: Colors.grey[600],
                                      size: 24,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                    ? _buildErrorState()
                    : _gameHistory.isEmpty
                        ? _buildEmptyState()
                        : _buildGamesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState() {
    return Center(
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
            'Error loading games',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refreshGameHistory,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ringPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_score,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No games found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Play some games to see them here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList() {
    return RefreshIndicator(
      onRefresh: _refreshGameHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _gameHistory.length +
            (_hasMoreGames ? 1 : 0), // Add one for the "Show More" button
        itemBuilder: (context, index) {
          // If we've reached the end and have more games, show the load more button
          if (index == _gameHistory.length && _hasMoreGames) {
            return _buildLoadMoreButton();
          }

          // Otherwise, show a game card
          final game = _gameHistory[index];
          final String gameId =
              game['id'].toString(); // Ensure the ID is a String
          final isExpanded = _expandedGames[gameId] ?? false;

          return _buildGameCard(game, isExpanded);
        },
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _loadMoreGames,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ringPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32.0, vertical: 12.0),
                ),
                child: const Text(
                  'Show More',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game, bool isExpanded) {
    final players = game['players'] as List<dynamic>;
    final String gameId = game['id'].toString(); // Ensure the ID is a String

    // Find winner safely
    Map<String, dynamic>? winner;
    try {
      winner = players.firstWhere((player) => player['isWinner'] == true)
          as Map<String, dynamic>;
    } catch (_) {
      // If no winner found, use null
      winner = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: isExpanded
            ? Border(
                top: BorderSide(
                    color: AppColors.ringBackground3rd.withAlpha(128),
                    width: 1.5),
                left: BorderSide(
                    color: AppColors.ringBackground3rd.withAlpha(128),
                    width: 1.5),
                right: BorderSide(
                    color: AppColors.ringBackground3rd.withAlpha(128),
                    width: 1.5),
              )
            : Border.all(
                color: AppColors.ringBackground3rd.withAlpha(128),
                width: 1.5,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Game card header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12.0),
                topRight: const Radius.circular(12.0),
                bottomLeft: Radius.circular(isExpanded ? 0 : 12.0),
                bottomRight: Radius.circular(isExpanded ? 0 : 12.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and winner info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      game['date'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (winner != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ringPrimary.withAlpha(26),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.emoji_events,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Winner: ${winner['firstName'].toString().length > 10 ? '${winner['firstName'].toString().substring(0, 10)}...' : winner['firstName']}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ringPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Players and their scores
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: players.map<Widget>((player) {
                    final isWinner = player['isWinner'] == true;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 6.0,
                      ),
                      decoration: BoxDecoration(
                        color: isWinner
                            ? AppColors.ringPrimary.withAlpha(26)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16.0),
                        border: isWinner
                            ? Border.all(
                                color: AppColors.ringPrimary.withAlpha(77))
                            : null,
                      ),
                      child: Text(
                        '${player['firstName']}: ${player['totalScore']}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isWinner ? FontWeight.bold : FontWeight.normal,
                          color:
                              isWinner ? AppColors.ringPrimary : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Frame scoreboard grid
                _buildFrameScoreGrid(players),

                // See details button
                GestureDetector(
                  onTap: () => _toggleGameExpansion(gameId),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isExpanded ? 'Hide details' : 'See details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ringPrimary,
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.ringPrimary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Game details when expanded
          if (isExpanded) _buildExpandedDetails(game),
        ],
      ),
    );
  }

  // Build frame score grid for all players
  Widget _buildFrameScoreGrid(List<dynamic> players) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var player in players)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0, top: 8.0),
                child: Text(
                  player['firstName'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.ringBackground3rd.withAlpha(128),
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Row(
                  children: _buildFrameCells(player),
                ),
              ),
              const SizedBox(height: 8.0),
            ],
          ),
      ],
    );
  }

  // Build all frame cells for a player with running scores
  List<Widget> _buildFrameCells(Map<String, dynamic> player) {
    final frames = _processPlayerFrames(player);
    final List<Widget> frameCells = [];

    // Calculate running scores
    final List<int?> cumulativeScores = _calculateCumulativeScores(player);

    // Build cells for each frame
    for (var i = 0; i < frames.length; i++) {
      // For the 10th frame, check if it needs extra space
      if (i == 9) {
        // Check if 10th frame has a third throw (strike or spare)
        bool hasThirdThrow = frames[i].length > 2;
        frameCells.add(
          Expanded(
            flex: hasThirdThrow
                ? 3
                : 2, // Give more space if there's a third throw
            child: _buildFrameCell(frames[i], i, cumulativeScores[i],
                hasExtraThrow: hasThirdThrow),
          ),
        );
      } else {
        // Regular frame
        frameCells.add(
          Expanded(
            child: _buildFrameCell(frames[i], i, cumulativeScores[i]),
          ),
        );
      }
    }

    return frameCells;
  }

  // Calculate cumulative scores for all frames
  List<int?> _calculateCumulativeScores(Map<String, dynamic> player) {
    List<int?> scores = List.filled(10, null);
    final totalScore = player['totalScore'] as int? ?? 0;
    final frames = _processPlayerFrames(player);

    // Simple equal distribution of scores across frames as a fallback
    // This is a simplified approach since we don't have the actual frame-by-frame scores
    int runningTotal = 0;
    int scorePerFrame = (totalScore / 10).ceil();

    for (int i = 0; i < frames.length; i++) {
      // Add estimated score for this frame
      if (frames[i].isNotEmpty) {
        runningTotal += scorePerFrame;
        // Ensure last frame adds up to total
        if (i == 9) {
          runningTotal = totalScore;
        }
        scores[i] = runningTotal;
      }
    }

    return scores;
  }

  // Individual frame cell
  Widget _buildFrameCell(
      List<String> frameData, int frameIndex, int? cumulativeScore,
      {bool hasExtraThrow = false}) {
    // Determine content for display
    String topLeft = frameData.isNotEmpty ? frameData[0] : '';
    String topRight = frameData.length > 1 ? frameData[1] : '';
    String extraThrow =
        (hasExtraThrow && frameData.length > 2) ? frameData[2] : '';

    // Handle display for 10th frame with extra throw
    Container mainContent;

    if (frameIndex == 9 && hasExtraThrow) {
      // Special 10th frame layout with three throws
      mainContent = Container(
        height: 50, // Increased height
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: AppColors.ringBackground3rd.withAlpha(128),
              width: 1.0,
            ),
          ),
        ),
        child: Column(
          children: [
            // Middle row with throws
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          topLeft,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      color: AppColors.ringBackground3rd.withAlpha(77),
                    ),
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          topRight,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      color: AppColors.ringBackground3rd.withAlpha(77),
                    ),
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          extraThrow,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom row with cumulative score
            Container(
              height: 22, // Increased height
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.ringBackground3rd.withAlpha(77),
                    width: 1,
                  ),
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3.0),
                  child: Text(
                    cumulativeScore != null ? '$cumulativeScore' : '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Standard frame layout
      mainContent = Container(
        height: 50, // Increased height
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: AppColors.ringBackground3rd.withAlpha(128),
              width: 1.0,
            ),
          ),
        ),
        child: Column(
          children: [
            // Middle row with throws
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        topLeft,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    color: AppColors.ringBackground3rd.withAlpha(77),
                  ),
                  Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        topRight,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom row with cumulative score
            Container(
              height: 22, // Increased height
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.ringBackground3rd.withAlpha(77),
                    width: 1,
                  ),
                ),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3.0),
                  child: Text(
                    cumulativeScore != null ? '$cumulativeScore' : '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return mainContent;
  }

  // Build expanded details for a game
  Widget _buildExpandedDetails(Map<String, dynamic> game) {
    final players = game['players'] as List<dynamic>;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12.0),
          bottomRight: Radius.circular(12.0),
        ),
        border: Border(
          bottom: BorderSide(
              color: AppColors.ringBackground3rd.withAlpha(128), width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Game metadata section
          Row(
            children: [
              _buildInfoItem(Icons.calendar_today, 'Date & Time',
                  '${game['date']} at ${game['time']}'),
              const SizedBox(width: 16),
              _buildInfoItem(Icons.location_on, 'Location', game['location']),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoItem(Icons.timer, 'Duration', game['duration']),
              const SizedBox(width: 16),
              _buildInfoItem(Icons.people, 'Players', '${players.length}'),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Statistics table
          _buildStatsTable(players),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTable(List<dynamic> players) {
    // Find best stats among players for highlighting
    final bestStats = _findBestStats(players);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Game Statistics',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Table header with player names
        Row(
          children: [
            const SizedBox(width: 140), // Space for stat labels
            ...players.map((player) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    player['firstName'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),

        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),

        // Stats rows
        _buildStatRow('Strikes', players, bestStats['strikes'], true),
        _buildStatRow('Spares', players, bestStats['spares'], true),
        _buildStatRow('Open Frames', players, bestStats['openFrames'], false),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),

        // Final scores row
        _buildStatRow('Final Score', players, null, true, isFinalScore: true),
      ],
    );
  }

  // Helper method to find the best stats among players
  Map<String, int> _findBestStats(List<dynamic> players) {
    Map<String, int> bestStats = {
      'strikes': 0,
      'spares': 0,
      'openFrames': 999,
    };

    for (var player in players) {
      final stats = _calculatePlayerStats(player);

      if (stats['strikes']! > bestStats['strikes']!) {
        bestStats['strikes'] = stats['strikes']!;
      }

      if (stats['spares']! > bestStats['spares']!) {
        bestStats['spares'] = stats['spares']!;
      }

      if (stats['openFrames']! < bestStats['openFrames']! &&
          stats['openFrames']! > 0) {
        bestStats['openFrames'] = stats['openFrames']!;
      }
    }

    return bestStats;
  }

  Widget _buildStatRow(String label, List<dynamic> players, dynamic bestValue,
      bool higherIsBetter,
      {bool isFinalScore = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // Stat label
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                fontWeight: isFinalScore ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),

          // Player values
          ...players.map((player) {
            // Get player's value for this stat
            int value;
            if (isFinalScore) {
              value = player['totalScore'] ?? 0;
            } else {
              final stats = _calculatePlayerStats(player);
              if (label == 'Strikes') {
                value = stats['strikes'] ?? 0;
              } else if (label == 'Spares') {
                value = stats['spares'] ?? 0;
              } else if (label == 'Open Frames') {
                value = stats['openFrames'] ?? 0;
              } else {
                value = 0;
              }
            }

            // Determine if this value is the best
            bool isHighlighted = false;
            if (isFinalScore) {
              isHighlighted = player['isWinner'] == true;
            } else if (bestValue != null) {
              if (higherIsBetter) {
                isHighlighted = value >= bestValue;
              } else {
                isHighlighted = value <= bestValue && value > 0;
              }
            }

            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? AppColors.ringBackground3rd.withAlpha(51)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isHighlighted ? FontWeight.bold : FontWeight.normal,
                    color:
                        isHighlighted ? AppColors.ringPrimary : Colors.black87,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Process player frames from throwsPerFrame
  List<List<String>> _processPlayerFrames(Map<String, dynamic> player) {
    final Map<String, dynamic> throwsPerFrame =
        player['frames'] is Map ? player['frames'] as Map<String, dynamic> : {};

    final List<List<String>> formattedFrames = [];

    // Convert each frame's throws to formatted display values
    for (int i = 1; i <= 10; i++) {
      final frameKey = i.toString();
      if (throwsPerFrame.containsKey(frameKey) &&
          throwsPerFrame[frameKey] is List) {
        List<dynamic> throws = throwsPerFrame[frameKey] as List<dynamic>;
        List<String> formattedThrows = [];

        // Process each throw in the frame
        for (int j = 0; j < throws.length; j++) {
          var throwValue = throws[j];

          if (throwValue is int) {
            // Convert numeric values to display format
            if (throwValue == 10 && (j == 0 || i == 10)) {
              formattedThrows.add('X'); // Strike
            } else if (j == 1 &&
                throws[0] is int &&
                (throws[0] as int) + throwValue == 10) {
              formattedThrows.add('/'); // Spare
            } else if (throwValue == 0) {
              formattedThrows.add('-'); // Miss
            } else {
              formattedThrows.add(throwValue.toString()); // Regular
            }
          } else if (throwValue is String) {
            formattedThrows.add(throwValue); // Already formatted string
          } else {
            formattedThrows.add('-'); // Unknown
          }
        }

        formattedFrames.add(formattedThrows);
      } else {
        formattedFrames.add([]); // Empty frame
      }
    }

    return formattedFrames;
  }

  // Calculate player statistics from frames
  Map<String, int> _calculatePlayerStats(Map<String, dynamic> player) {
    final Map<String, dynamic> throwsPerFrame =
        player['frames'] is Map ? player['frames'] as Map<String, dynamic> : {};

    int strikes = 0;
    int spares = 0;
    int openFrames = 0;

    // Count strikes, spares, and open frames
    for (int i = 1; i <= 10; i++) {
      final frameKey = i.toString();
      if (throwsPerFrame.containsKey(frameKey) &&
          throwsPerFrame[frameKey] is List) {
        List<dynamic> throws = throwsPerFrame[frameKey] as List<dynamic>;

        if (throws.isNotEmpty) {
          // Check for strike
          if (throws[0] is int && throws[0] == 10) {
            strikes++;
          }
          // Check for spare
          else if (throws.length >= 2 &&
              throws[0] is int &&
              throws[1] is int &&
              throws[0] + throws[1] == 10) {
            spares++;
          }
          // Open frame
          else if (throws.length >= 2) {
            openFrames++;
          }
        }
      }
    }

    return {
      'strikes': strikes,
      'spares': spares,
      'openFrames': openFrames,
    };
  }
}
