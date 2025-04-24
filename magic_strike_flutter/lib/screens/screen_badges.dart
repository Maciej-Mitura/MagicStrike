import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../constants/app_colors.dart';
import '../constants/badge_data.dart';
import '../services/badge_service.dart';

class BadgeScreen extends StatefulWidget {
  const BadgeScreen({super.key});

  @override
  State<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends State<BadgeScreen> {
  final BadgeService _badgeService = BadgeService();

  Map<String, dynamic> _userBadges = {};
  bool _isLoading = true;

  // Track which badge is currently expanded
  String? _expandedBadgeId;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // First migrate badge data format to ensure compatibility
    await _badgeService.migrateBadgesFormat();
    // Then load badges
    await _loadUserBadges();
  }

  Future<void> _loadUserBadges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final badges = await _badgeService.getUserBadges();
      setState(() {
        _userBadges = badges;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading user badges: $e');
    }
  }

  // Toggle expanded state for a badge
  void _toggleExpandBadge(String badgeId) {
    setState(() {
      if (_expandedBadgeId == badgeId) {
        // If this badge is already expanded, collapse it
        _expandedBadgeId = null;
      } else {
        // Otherwise, expand this one (and collapse any other)
        _expandedBadgeId = badgeId;
      }
    });
  }

  // Helper method to remove emoji from display name
  String _getDisplayName(String fullName) {
    // If name has an emoji (typically followed by a space), remove it
    if (fullName.contains(' ')) {
      List<String> parts = fullName.split(' ');
      if (parts.isNotEmpty && parts[0].length <= 2) {
        // Emoji is typically 1-2 chars
        // Return everything after the emoji and space
        return parts.sublist(1).join(' ');
      }
    }
    return fullName; // Return original if no emoji found
  }

  // Helper method to extract emoji from display name
  String _getEmoji(String fullName) {
    // If name has an emoji (typically first part before space), extract it
    if (fullName.contains(' ')) {
      List<String> parts = fullName.split(' ');
      if (parts.isNotEmpty && parts[0].length <= 2) {
        // Emoji is typically 1-2 chars
        return parts[0];
      }
    }
    return '🏆'; // Default emoji if none found
  }

  @override
  Widget build(BuildContext context) {
    // Sort badges - earned ones first, then locked ones
    final List<Map<String, dynamic>> sortedBadges = List.from(badgeMetadata);
    sortedBadges.sort((a, b) {
      final bool aEarned = _userBadges.containsKey(a['id']);
      final bool bEarned = _userBadges.containsKey(b['id']);

      // If one is earned and the other isn't, put earned one first
      if (aEarned && !bEarned) return -1;
      if (!aEarned && bEarned) return 1;

      // Otherwise keep original order
      return 0;
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Achievements'),
        backgroundColor: AppColors.ringPrimary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    if (_userBadges.isEmpty && badgeMetadata.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.emoji_events_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No achievements yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Play games to earn badges',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        // Use a regular Column instead of GridView to insert description boxes
                        child:
                            _buildAchievementsGrid(sortedBadges, constraints),
                      ),

                    // Add some bottom padding
                    const SizedBox(height: 20),
                  ],
                ),
              );
            }),
    );
  }

  // Build the achievements grid with inline description boxes
  Widget _buildAchievementsGrid(
      List<Map<String, dynamic>> sortedBadges, BoxConstraints constraints) {
    // Calculate items per row (2 for now)
    const int itemsPerRow = 2;
    // Calculate number of rows needed
    final int rowCount = (sortedBadges.length / itemsPerRow).ceil();

    return Column(
      children: List.generate(rowCount, (rowIndex) {
        // Create a list to hold widgets for this row and potential description
        List<Widget> rowItems = [];

        // Add the achievement cards for this row
        rowItems.add(
          Row(
            children: List.generate(itemsPerRow, (colIndex) {
              final int index = rowIndex * itemsPerRow + colIndex;
              if (index >= sortedBadges.length) {
                // Return empty container for padding
                return Expanded(child: Container());
              }

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child:
                      _buildAchievementCard(sortedBadges[index], constraints),
                ),
              );
            }),
          ),
        );

        // Check if any achievement in this row is expanded
        for (int colIndex = 0; colIndex < itemsPerRow; colIndex++) {
          final int index = rowIndex * itemsPerRow + colIndex;
          if (index < sortedBadges.length) {
            final String badgeId = sortedBadges[index]['id'] as String;
            if (_expandedBadgeId == badgeId) {
              // Add description box after this row
              rowItems.add(
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  child: _buildExpandedDescription(),
                ),
              );
              break; // Only add one description box per row
            }
          }
        }

        return Column(children: rowItems);
      }),
    );
  }

  // Build individual achievement card
  Widget _buildAchievementCard(
      Map<String, dynamic> metadata, BoxConstraints constraints) {
    final String badgeId = metadata['id'] as String;

    // Check if user has earned this badge
    final bool isEarned = _userBadges.containsKey(badgeId);
    final Map<String, dynamic>? badgeData =
        isEarned ? _userBadges[badgeId] : null;

    final bool isExpanded = _expandedBadgeId == badgeId;
    final Color badgeColor = metadata['color'] as Color? ?? Colors.grey;
    final String displayName = metadata['displayName'] ?? 'Unknown Badge';

    // Extract emoji and clean display name
    final String badgeEmoji = _getEmoji(displayName);
    final String cleanDisplayName = _getDisplayName(displayName);

    return Card(
      elevation: 0,
      color: isEarned
          ? (isExpanded
              ? badgeColor.withOpacity(0.2)
              : badgeColor.withOpacity(0.1))
          : Colors.grey[200], // Grey for locked achievements
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _toggleExpandBadge(badgeId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge icon - just the emoji
              // Use slightly faded look for locked achievements
              Text(
                badgeEmoji,
                style: TextStyle(
                  fontSize: 48,
                  color: isEarned ? null : Colors.grey,
                ),
              ),
              const SizedBox(height: 12),

              // Badge name without emoji
              Text(
                cleanDisplayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isEarned ? Colors.black87 : Colors.grey[600],
                ),
              ),

              // Show earned date or "Not achieved yet"
              const SizedBox(height: 4),
              Text(
                isEarned
                    ? (badgeData?['earnedAt'] is Timestamp
                        ? 'Earned: ${_formatDate(badgeData!['earnedAt'] as Timestamp)}'
                        : 'Earned')
                    : 'Not achieved yet',
                style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: isEarned ? Colors.black54 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Format timestamp to readable date
  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  // Build an expanded description container for the currently expanded badge
  Widget _buildExpandedDescription() {
    // Get metadata for the expanded badge
    final metadata = getBadgeMetadataById(_expandedBadgeId!);
    if (metadata == null) return const SizedBox.shrink();

    final Color badgeColor = metadata['color'] as Color? ?? Colors.grey;
    final String description =
        metadata['description'] ?? 'No description available';
    final String displayName = metadata['displayName'] ?? '';
    final String emoji = _getEmoji(displayName);

    // Check if this badge is earned
    final bool isEarned = _userBadges.containsKey(_expandedBadgeId);

    // Animated container for a smooth appearance
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEarned ? badgeColor.withOpacity(0.1) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge emoji - no background
            Text(
              emoji,
              style: TextStyle(
                fontSize: 24,
                color: isEarned ? null : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),

            // Description text
            Expanded(
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: isEarned ? Colors.black87 : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
