import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';

class StrikesLeaderboardItem extends StatelessWidget {
  final String userId;
  final String firstName;
  final String lastName;
  final int percentage;
  final String profileUrl;
  final int rank;
  final bool isCurrentUser;

  const StrikesLeaderboardItem({
    super.key,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.percentage,
    required this.profileUrl,
    required this.rank,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Rank indicator
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1 ? AppColors.ringPrimary : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Text(
              rank.toString(),
              style: TextStyle(
                color: rank == 1 ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Profile picture
          ClipOval(
            child: Container(
              width: 40,
              height: 40,
              color: AppColors.ringPrimary.withOpacity(0.8),
              child: profileUrl.isNotEmpty &&
                      (profileUrl.startsWith('http://') ||
                          profileUrl.startsWith('https://'))
                  ? Image.network(
                      '$profileUrl?v=${DateTime.now().microsecondsSinceEpoch}',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      cacheWidth: null, // Disable cache
                      cacheHeight: null, // Disable cache
                      // Force reload by setting no-cache headers
                      headers: {
                        'Cache-Control': 'no-cache, no-store, must-revalidate',
                        'Pragma': 'no-cache',
                        'Expires': '0',
                      },
                      // Error handling
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.person,
                            color: Colors.white, size: 24);
                      },
                      // Loading placeholder
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.0,
                            ),
                          ),
                        );
                      },
                    )
                  : const Icon(Icons.person, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),

          // Player name and deRingID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$firstName ${lastName.isNotEmpty ? lastName : ""}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCurrentUser ? AppColors.ringPrimary : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  userId,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Percentage with trophy icon for top 3 players
          Row(
            children: [
              if (rank <= 3) ...[
                // Trophy icon with different sizes and colors based on rank
                Icon(
                  Icons.emoji_events,
                  color: rank == 1
                      ? Colors.amber
                      : rank == 2
                          ? Colors.grey.shade400
                          : Colors.brown.shade300,
                  size: rank == 1
                      ? 20
                      : rank == 2
                          ? 17
                          : 14,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                "$percentage%",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCurrentUser ? AppColors.ringPrimary : Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
