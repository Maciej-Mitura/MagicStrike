import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../constants/badge_data.dart';
import '../services/badge_service.dart';

class AchievementsRow extends StatefulWidget {
  final String? userId;
  final double cardHeight;
  final double cardWidth;
  final bool showDate;
  final VoidCallback? onViewAllPressed;

  const AchievementsRow({
    super.key,
    this.userId,
    this.cardHeight = 120,
    this.cardWidth = 120,
    this.showDate = false,
    this.onViewAllPressed,
  });

  @override
  State<AchievementsRow> createState() => _AchievementsRowState();
}

class _AchievementsRowState extends State<AchievementsRow> {
  final BadgeService _badgeService = BadgeService();
  Map<String, dynamic> _badges = {};
  bool _isLoading = true;

  // Track which badge is currently expanded
  String? _expandedBadgeId;

  @override
  void initState() {
    super.initState();
    _loadUserBadges();
  }

  Future<void> _loadUserBadges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final badges = await _badgeService.getUserBadges(userId: widget.userId);

      if (mounted) {
        setState(() {
          _badges = badges;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('Error loading badges for achievements row: $e');
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
    // Make entire component scrollable to prevent overflow
    return LayoutBuilder(builder: (context, constraints) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Achievements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (widget.onViewAllPressed != null)
                  TextButton(
                    onPressed: widget.onViewAllPressed,
                    child: Text(
                      'View All',
                      style: TextStyle(
                        color: AppColors.ringPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Badges list
          if (_isLoading)
            Center(
              child: SizedBox(
                height: widget.cardHeight,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            )
          else if (_badges.isEmpty)
            SizedBox(
              height: widget.cardHeight,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No achievements yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            // Fixed height for badge row to prevent layout shifts
            SizedBox(
              height: widget.cardHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _badges.length,
                itemBuilder: (context, index) {
                  final String badgeId = _badges.keys.elementAt(index);
                  final Map<String, dynamic> badgeData = _badges[badgeId];

                  // Find badge metadata
                  final metadata = getBadgeMetadataById(badgeId);
                  if (metadata == null) return const SizedBox.shrink();

                  // Format date if needed
                  String? formattedDate;
                  if (widget.showDate && badgeData['earnedAt'] is Timestamp) {
                    final timestamp = badgeData['earnedAt'] as Timestamp;
                    final date = timestamp.toDate();
                    formattedDate = '${date.day}/${date.month}/${date.year}';
                  }

                  return _buildBadgeCard(
                    badgeId: badgeId,
                    metadata: metadata,
                    earnedDate: formattedDate,
                    isExpanded: _expandedBadgeId == badgeId,
                    index: index,
                  );
                },
              ),
            ),

          // Description container in separate widget with fixed constraints
          if (_expandedBadgeId != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 60,
                maxHeight: 120, // Limit max height
                maxWidth: constraints.maxWidth, // Match parent width
              ),
              child: _buildExpandedDescription(),
            ),
        ],
      );
    });
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

    // Animated container for a smooth appearance
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
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
              style: const TextStyle(
                fontSize: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Description text
            Expanded(
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeCard({
    required String badgeId,
    required Map<String, dynamic> metadata,
    String? earnedDate,
    required bool isExpanded,
    required int index,
  }) {
    final Color badgeColor = metadata['color'] as Color? ?? Colors.grey;
    final String displayName = metadata['displayName'] ?? 'Unknown';

    // Extract emoji and clean display name
    final String badgeEmoji = _getEmoji(displayName);
    final String cleanDisplayName = _getDisplayName(displayName);

    return Container(
      width: widget.cardWidth,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 0,
        color: isExpanded
            ? badgeColor.withOpacity(0.2) // Highlight when expanded
            : badgeColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Tooltip(
          message: metadata['description'] ?? '',
          child: InkWell(
            onTap: () {
              // Toggle expanded state instead of showing snackbar
              _toggleExpandBadge(badgeId);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Badge icon - just the emoji
                  Text(
                    badgeEmoji,
                    style: const TextStyle(
                      fontSize: 40,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    cleanDisplayName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),

                  if (earnedDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Earned: $earnedDate',
                      style: const TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
