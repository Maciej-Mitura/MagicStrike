import 'package:flutter/material.dart';

/// Metadata for all available badges/achievements in the app
final List<Map<String, dynamic>> badgeMetadata = [
  {
    'id': 'first_game',
    'displayName': '🎯 First Strike',
    'description': 'Get your first strike in a bowling game',
    'color': Colors.green,
  },
  {
    'id': 'strike_master',
    'displayName': '🔥 Strike Master',
    'description': 'Score 3 strikes in a row',
    'color': Colors.orange,
  },
  {
    'id': 'perfect_game',
    'displayName': '🏆 Perfect Game',
    'description': 'Score a perfect 300 in a game',
    'color': Colors.amber,
  },
  {
    'id': 'spare_collector',
    'displayName': '🧹 Spare Collector',
    'description': 'Convert 5 spares in a single game',
    'color': Colors.blue,
  },
  {
    'id': 'consistent_player',
    'displayName': '📊 Steady Roller',
    'description': 'Complete 5 games with scores above 150',
    'color': Colors.deepPurple,
  },
  {
    'id': 'night_owl',
    'displayName': '🦉 Night Owl',
    'description': 'Play a game after 10 PM',
    'color': Colors.indigo,
  },
  {
    'id': 'social_bowler',
    'displayName': '👥 Team Player',
    'description': 'Play in a game with 4+ players',
    'color': Colors.teal,
  },
  {
    'id': 'comeback_king',
    'displayName': '👑 Comeback King',
    'description': 'Win after being behind by 30+ points',
    'color': Colors.red,
  },
  {
    'id': 'disco_dancer',
    'displayName': '💃 Disco Dancer',
    'description': 'Participate in a Disco Bowling Sunday event',
    'color': Colors.purple,
  },
  {
    'id': 'weekly_warrior',
    'displayName': '⚔️ Weekly Warrior',
    'description': 'Play at least one game every week for a month',
    'color': Colors.brown,
  },
];

/// Get a badge icon URL from DiceBear based on the badge ID
///
/// This function generates a unique icon URL for each badge using DiceBear API
/// The URL can be used with any image loading library (NetworkImage, CachedNetworkImage, etc.)
///
/// Parameters:
/// - badgeId: The unique ID of the badge
/// - size: Optional size of the generated image (default: 128)
/// - style: Optional DiceBear style to use (default: 'icons')
/// - background: Optional background color (default: transparent)
///
/// Returns a URL string that can be used to display the badge icon
String getBadgeIconUrl(
  String badgeId, {
  int size = 128,
  String style = 'icons',
  String? background,
}) {
  // Create a URL-safe seed by ensuring badgeId is properly formatted
  final String seed = Uri.encodeComponent(badgeId);

  // Create the base URL with the selected style and seed
  // Use PNG format instead of SVG for better compatibility
  String url = 'https://api.dicebear.com/7.x/$style/png?seed=$seed';

  // Add optional parameters if provided
  if (size != 128) {
    url += '&size=$size';
  }

  if (background != null) {
    url += '&backgroundColor=$background';
  }

  // Add some additional parameters for better badge icons
  url += '&radius=20&scale=110'; // Slightly rounded icon with scale up

  return url;
}

/// Get badge metadata by ID
Map<String, dynamic>? getBadgeMetadataById(String badgeId) {
  try {
    return badgeMetadata.firstWhere(
      (badge) => badge['id'] == badgeId,
      orElse: () => throw Exception('Badge not found'),
    );
  } catch (e) {
    return null;
  }
}
