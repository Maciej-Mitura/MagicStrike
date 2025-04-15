import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';

class GamesHistoryScreen extends StatefulWidget {
  const GamesHistoryScreen({super.key});

  @override
  State<GamesHistoryScreen> createState() => _GamesHistoryScreenState();
}

class _GamesHistoryScreenState extends State<GamesHistoryScreen> {
  // Keep track of which game cards are expanded
  final Map<int, bool> _expandedGames = {};

  // Sample game history data (to be replaced with real data from backend)
  final List<Map<String, dynamic>> _gameHistory = [
    {
      'id': 1,
      'date': '15 June 2023',
      'time': '14:30',
      'location': 'Bowling Palace',
      'duration': '1h 15m',
      'players': [
        {
          'name': 'John',
          'totalScore': 168,
          'isWinner': true,
          'stats': {
            'strikes': 4,
            'spares': 3,
            'openFrames': 3,
            'lowestFrameScore': 7,
          },
          'frames': [
            ['9', '/'],
            ['X', ''],
            ['8', '1'],
            ['X', ''],
            ['7', '/'],
            ['9', '-'],
            ['X', ''],
            ['8', '/'],
            ['7', '2'],
            ['X', '8', '1']
          ]
        },
        {
          'name': 'Sarah',
          'totalScore': 145,
          'isWinner': false,
          'stats': {
            'strikes': 2,
            'spares': 4,
            'openFrames': 4,
            'lowestFrameScore': 5,
          },
          'frames': [
            ['8', '/'],
            ['7', '2'],
            ['X', ''],
            ['9', '-'],
            ['8', '/'],
            ['7', '2'],
            ['X', ''],
            ['8', '1'],
            ['9', '/'],
            ['X', '7', '2']
          ]
        }
      ]
    },
    {
      'id': 2,
      'date': '10 June 2023',
      'time': '19:45',
      'location': 'Lucky Strike',
      'duration': '0h 45m',
      'players': [
        {
          'name': 'Michael',
          'totalScore': 210,
          'isWinner': true,
          'stats': {
            'strikes': 7,
            'spares': 2,
            'openFrames': 1,
            'lowestFrameScore': 8,
          },
          'frames': [
            ['X', ''],
            ['X', ''],
            ['9', '/'],
            ['8', '1'],
            ['X', ''],
            ['X', ''],
            ['7', '/'],
            ['9', '-'],
            ['X', ''],
            ['X', 'X', '8']
          ]
        }
      ]
    },
    {
      'id': 3,
      'date': '5 June 2023',
      'time': '16:15',
      'location': 'City Bowl',
      'duration': '1h 35m',
      'players': [
        {
          'name': 'Emily',
          'totalScore': 142,
          'isWinner': false,
          'stats': {
            'strikes': 2,
            'spares': 4,
            'openFrames': 4,
            'lowestFrameScore': 6,
          },
          'frames': [
            ['8', '/'],
            ['7', '2'],
            ['X', ''],
            ['9', '-'],
            ['8', '/'],
            ['7', '2'],
            ['X', ''],
            ['8', '1'],
            ['9', '/'],
            ['X', '7', '2']
          ]
        },
        {
          'name': 'David',
          'totalScore': 155,
          'isWinner': false,
          'stats': {
            'strikes': 3,
            'spares': 3,
            'openFrames': 4,
            'lowestFrameScore': 7,
          },
          'frames': [
            ['7', '2'],
            ['X', ''],
            ['9', '/'],
            ['X', ''],
            ['8', '1'],
            ['8', '/'],
            ['7', '2'],
            ['X', ''],
            ['9', '-'],
            ['8', '/']
          ]
        },
        {
          'name': 'Christopher',
          'totalScore': 178,
          'isWinner': true,
          'stats': {
            'strikes': 5,
            'spares': 3,
            'openFrames': 2,
            'lowestFrameScore': 9,
          },
          'frames': [
            ['X', ''],
            ['8', '/'],
            ['7', '2'],
            ['X', ''],
            ['9', '-'],
            ['X', ''],
            ['8', '/'],
            ['7', '2'],
            ['X', ''],
            ['X', '8', '/']
          ]
        }
      ]
    },
  ];

  // Toggle the expansion state of a game card
  void _toggleGameExpansion(int gameId) {
    setState(() {
      _expandedGames[gameId] = !(_expandedGames[gameId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Game History',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
        ),
      ),
      body: _gameHistory.isEmpty ? _buildEmptyState() : _buildGamesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_score_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No games yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Play some games to see your history here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _gameHistory.length,
      itemBuilder: (context, index) {
        final game = _gameHistory[index];
        final isExpanded = _expandedGames[game['id']] ?? false;

        return _buildGameCard(game, isExpanded);
      },
    );
  }

  Widget _buildGameCard(Map<String, dynamic> game, bool isExpanded) {
    final players = game['players'] as List<dynamic>;

    // Find winner safely
    Map<String, dynamic> winner;
    try {
      winner = players.firstWhere((player) => player['isWinner'] == true);
    } catch (_) {
      // If no winner found, use the first player
      winner = players.first;
    }

    // Get date information
    final gameDate = game['date'] as String;

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
                      gameDate,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                            'Winner: ${winner['name']}',
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
                        '${player['name']}: ${player['totalScore']}',
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
                  onTap: () => _toggleGameExpansion(game['id']),
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

          // Expanded details section
          if (isExpanded) _buildExpandedDetails(game),
        ],
      ),
    );
  }

  // Frame score grid widget
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
                  player['name'],
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
    final frames = player['frames'] as List<dynamic>;
    final List<Widget> frameCells = [];

    // Calculate running scores for each frame
    List<int?> cumulativeScores = _calculateCumulativeScores(frames);

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
  List<int?> _calculateCumulativeScores(List<dynamic> frames) {
    List<int?> scores = List.filled(10, null);
    int runningTotal = 0;

    for (int i = 0; i < frames.length; i++) {
      var frame = frames[i];
      int frameScore = 0;

      // Calculate score for this frame
      if (frame[0] == 'X') {
        // Strike
        frameScore = 10;

        // Add bonus for strike
        if (i < 9) {
          // If next frame exists
          if (i + 1 < frames.length) {
            // First bonus
            if (frames[i + 1][0] == 'X') {
              frameScore += 10;

              // Second bonus
              if (i + 2 < frames.length) {
                if (frames[i + 2][0] == 'X') {
                  frameScore += 10;
                } else {
                  frameScore +=
                      frames[i + 2][0] == '-' ? 0 : int.parse(frames[i + 2][0]);
                }
              } else if (i + 1 == 9 && frames[9].length > 1) {
                // If second strike is in 10th frame, get second roll from there
                frameScore += frames[9][1] == 'X'
                    ? 10
                    : frames[9][1] == '-'
                        ? 0
                        : int.parse(frames[9][1]);
              }
            } else {
              // Next frame is not a strike, add first two rolls
              frameScore +=
                  frames[i + 1][0] == '-' ? 0 : int.parse(frames[i + 1][0]);
              if (frames[i + 1].length > 1) {
                frameScore += frames[i + 1][1] == '/'
                    ? (10 -
                        (frames[i + 1][0] == '-'
                            ? 0
                            : int.parse(frames[i + 1][0])))
                    : (frames[i + 1][1] == '-'
                        ? 0
                        : int.parse(frames[i + 1][1]));
              }
            }
          }
        } else if (i == 9) {
          // 10th frame strike bonuses are in the same frame
          if (frame.length > 1) {
            // First bonus
            frameScore += frame[1] == 'X'
                ? 10
                : frame[1] == '-'
                    ? 0
                    : int.parse(frame[1]);

            // Second bonus if it exists
            if (frame.length > 2) {
              frameScore += frame[2] == 'X'
                  ? 10
                  : frame[2] == '/'
                      ? (10 -
                          (frame[1] == 'X'
                              ? 10
                              : frame[1] == '-'
                                  ? 0
                                  : int.parse(frame[1])))
                      : frame[2] == '-'
                          ? 0
                          : int.parse(frame[2]);
            }
          }
        }
      } else if (frame.length > 1 && frame[1] == '/') {
        // Spare
        frameScore = 10;

        // Add bonus for spare
        if (i < 9) {
          // Next frame's first roll is the bonus
          if (i + 1 < frames.length) {
            frameScore += frames[i + 1][0] == 'X'
                ? 10
                : frames[i + 1][0] == '-'
                    ? 0
                    : int.parse(frames[i + 1][0]);
          }
        } else if (i == 9 && frame.length > 2) {
          // 10th frame spare bonus is the third roll
          frameScore += frame[2] == 'X'
              ? 10
              : frame[2] == '-'
                  ? 0
                  : int.parse(frame[2]);
        }
      } else {
        // Open frame
        frameScore += frame[0] == '-' ? 0 : int.parse(frame[0]);
        if (frame.length > 1) {
          frameScore += frame[1] == '-' ? 0 : int.parse(frame[1]);
        }
      }

      runningTotal += frameScore;
      scores[i] = runningTotal;
    }

    return scores;
  }

  // Individual frame cell
  Widget _buildFrameCell(
      List<dynamic> frameData, int frameIndex, int? cumulativeScore,
      {bool hasExtraThrow = false}) {
    // Determine content for display
    String topLeft = frameData[0] == 'X' ? 'X' : frameData[0];
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

  Widget _buildExpandedDetails(Map<String, dynamic> game) {
    final players = game['players'] as List<dynamic>;

    // Find best stats among players for highlighting
    final bestStats = {
      'strikes': _findBestStat(players, 'strikes', true),
      'spares': _findBestStat(players, 'spares', true),
      'openFrames': _findBestStat(players, 'openFrames', false),
      'lowestFrameScore': _findBestStat(players, 'lowestFrameScore', false),
    };

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
          _buildStatsTable(players, bestStats),
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

  Widget _buildStatsTable(
      List<dynamic> players, Map<String, dynamic> bestStats) {
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
                    player['name'],
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
        _buildStatRow('Lowest Frame Score', players,
            bestStats['lowestFrameScore'], false),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),

        // Final scores row
        _buildStatRow('Final Score', players, null, true, isFinalScore: true),
      ],
    );
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
            var statKey = label.toLowerCase().replaceAll(' ', 'FrameScore');
            // Fix for null values - provide defaults based on the stat type
            int value;
            if (isFinalScore) {
              value = player['totalScore'];
            } else {
              if (statKey == 'openframes') {
                value = player['stats']['openFrames'] ??
                    (10 -
                        (player['stats']['strikes'] ?? 0) -
                        (player['stats']['spares'] ?? 0));
              } else if (statKey == 'lowestframescore') {
                value = player['stats']['lowestFrameScore'] ??
                    (player['totalScore'] ~/ 10 - 3);
                // Ensure lowest score is reasonable (between 0-9)
                value = value < 0 ? 0 : (value > 9 ? 5 : value);
              } else {
                value = player['stats'][statKey] ?? 0;
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
                isHighlighted = value <= bestValue;
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

  // Helper method to find the best stat among players
  dynamic _findBestStat(
      List<dynamic> players, String statName, bool higherIsBetter) {
    if (players.isEmpty) return null;

    // Get values with fallbacks for null values
    var values = players.map((p) {
      if (statName == 'openFrames') {
        return p['stats'][statName] ??
            (10 - (p['stats']['strikes'] ?? 0) - (p['stats']['spares'] ?? 0));
      } else if (statName == 'lowestFrameScore') {
        var value = p['stats'][statName] ?? (p['totalScore'] ~/ 10 - 3);
        return value < 0 ? 0 : (value > 9 ? 5 : value);
      }
      return p['stats'][statName] ?? 0;
    }).toList();

    values.sort();

    return higherIsBetter ? values.last : values.first;
  }
}
