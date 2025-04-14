class LiveGame {
  final String id;
  String status;
  int currentFrame;
  int viewerCount;
  List<Player> players;

  LiveGame({
    required this.id,
    required this.status,
    required this.currentFrame,
    required this.viewerCount,
    required this.players,
  });

  // Update a throw for a player
  void updateThrow(
      String playerId, int frameIndex, int throwIndex, String display) {
    // Find the player
    final playerIndex = players.indexWhere((p) => p.id == playerId);
    if (playerIndex < 0) return;

    final player = players[playerIndex];

    // Ensure we have enough frames
    while (player.frames.length <= frameIndex) {
      player.frames.add(BowlingFrame.empty());
    }

    // Get the frame
    final frame = player.frames[frameIndex];

    // Ensure we have enough throws
    while (frame.throws.length <= throwIndex) {
      frame.throws.add(BowlingThrow(display: '-', pins: 0));
    }

    // Calculate pins based on display
    int pins = 0;
    if (display == 'X') {
      // Strike - 10 pins
      pins = 10;
    } else if (display == '/') {
      // Spare - remaining pins (10 - previous throw)
      final previousPins = frame.throws.isNotEmpty ? frame.throws[0].pins : 0;
      pins = 10 - previousPins;
    } else if (display == '-') {
      // Miss - 0 pins
      pins = 0;
    } else {
      // Number of pins
      pins = int.tryParse(display) ?? 0;
    }

    // Update the throw
    frame.throws[throwIndex] = BowlingThrow(display: display, pins: pins);

    // If this is the second throw and it makes a spare (adds up to 10) with the first throw
    // and the first throw wasn't a strike, convert it to a spare display
    if (throwIndex == 1 &&
        !frame.throws[0].isStrike &&
        frame.throws[0].pins + pins == 10) {
      frame.throws[throwIndex] = BowlingThrow(display: '/', pins: pins);
    }

    // Store the frame index + 1 as frameScore to identify the 10th frame
    frame.frameScore = frameIndex + 1;

    // Calculate the total for this player
    player.totalScore = _calculatePlayerTotal(player);

    // Update the current frame for the game
    _updateCurrentFrame();
  }

  // Calculate total score for a player
  int _calculatePlayerTotal(Player player) {
    int totalScore = 0;

    for (int i = 0; i < player.frames.length; i++) {
      final frame = player.frames[i];

      // Only count complete frames (except in progress frames in 10th)
      if (!frame.isComplete && i != 9) continue;

      // Handle first 9 frames
      if (i < 9) {
        // For a strike, add 10 + next two throws
        if (frame.isStrike) {
          totalScore += 10;

          // Add bonus: next two throws
          int bonus = 0;
          int bonusThrows = 0;

          // Look ahead for next throws
          for (int j = i + 1;
              j < player.frames.length && bonusThrows < 2;
              j++) {
            final nextFrame = player.frames[j];
            for (final t in nextFrame.throws) {
              if (bonusThrows < 2) {
                bonus += t.pins;
                bonusThrows++;
              }
            }
          }

          totalScore += bonus;
        }
        // For a spare, add 10 + next throw
        else if (frame.isSpare) {
          totalScore += 10;

          // Add bonus: next throw
          int bonus = 0;

          // Look ahead for next throw
          if (i + 1 < player.frames.length &&
              player.frames[i + 1].throws.isNotEmpty) {
            bonus = player.frames[i + 1].throws[0].pins;
          }

          totalScore += bonus;
        }
        // For an open frame, add the pins
        else {
          for (final t in frame.throws) {
            totalScore += t.pins;
          }
        }
      }
      // Handle 10th frame specially
      else if (i == 9) {
        // In 10th frame, just add all pins knocked down
        for (final t in frame.throws) {
          totalScore += t.pins;
        }
      }
    }

    return totalScore;
  }

  // Update the current frame based on player progress
  void _updateCurrentFrame() {
    // Skip if no players
    if (players.isEmpty) return;

    // Determine the minimum current frame among all players
    int minCurrentFrame = 11; // Higher than max frame

    for (final player in players) {
      int playerCurrentFrame = 1;

      // Find the first incomplete frame for this player
      for (int i = 0; i < player.frames.length; i++) {
        if (!player.frames[i].isComplete) {
          playerCurrentFrame = i + 1;
          break;
        }
        // If we got through all frames and they're all complete
        if (i == player.frames.length - 1) {
          playerCurrentFrame = i + 2; // Next frame after last complete one
        }
      }

      // Update minimum current frame
      minCurrentFrame = min(minCurrentFrame, playerCurrentFrame);
    }

    // Clamp to valid frame range (1-10)
    minCurrentFrame = min(max(minCurrentFrame, 1), 10);

    // Update the game's current frame
    currentFrame = minCurrentFrame;

    // Check if game is complete (all players have completed frame 10)
    bool allComplete = true;
    for (final player in players) {
      // Check if player has 10 frames and the 10th is complete
      if (player.frames.length < 10 || !player.frames[9].isComplete) {
        allComplete = false;
        break;
      }
    }

    // Update game status if complete
    if (allComplete) {
      status = 'completed';
    }
  }

  // Create a demo regular game with one player
  static LiveGame createDemoRegularGame() {
    final player = Player(
      id: 'player1',
      name: 'John Doe',
      frames: List.generate(8, (i) {
        final frame = BowlingFrame.empty();

        // Add a variety of throws
        if (i % 3 == 0) {
          // Strike
          frame.throws.add(BowlingThrow(display: 'X', pins: 10));
        } else if (i % 3 == 1) {
          // Spare
          frame.throws.add(BowlingThrow(display: '8', pins: 8));
          frame.throws.add(BowlingThrow(display: '/', pins: 2));
        } else {
          // Open
          frame.throws.add(BowlingThrow(display: '7', pins: 7));
          frame.throws.add(BowlingThrow(display: '2', pins: 2));
        }

        frame.frameScore = i + 1;
        return frame;
      }),
      totalScore: 0, // Will be calculated
    );

    // Add 9th frame with a strike
    final ninthFrame = BowlingFrame.empty();
    ninthFrame.throws.add(BowlingThrow(display: 'X', pins: 10));
    ninthFrame.frameScore = 9;
    player.frames.add(ninthFrame);

    // Add 10th frame with spare and bonus
    final tenthFrame = BowlingFrame.empty();
    tenthFrame.throws.add(BowlingThrow(display: '9', pins: 9));
    tenthFrame.throws.add(BowlingThrow(display: '/', pins: 1));
    tenthFrame.throws.add(BowlingThrow(display: 'X', pins: 10));
    tenthFrame.frameScore = 10;
    player.frames.add(tenthFrame);

    // Calculate total score
    player.totalScore = _calculateDemoScore(player.frames);

    return LiveGame(
      id: 'BOWL123',
      status: 'live',
      currentFrame: 10,
      viewerCount: 1,
      players: [player],
    );
  }

  // Create a demo perfect game (all strikes)
  static LiveGame createDemoPerfectGame() {
    final player = Player(
      id: 'player1',
      name: 'Perfect Bowler',
      frames: List.generate(9, (i) {
        final frame = BowlingFrame.empty();
        frame.throws.add(BowlingThrow(display: 'X', pins: 10));
        frame.frameScore = i + 1;
        return frame;
      }),
      totalScore: 270, // Score after 9 frames with all strikes
    );

    // Add 10th frame with three strikes
    final tenthFrame = BowlingFrame.empty();
    tenthFrame.throws.add(BowlingThrow(display: 'X', pins: 10));
    tenthFrame.throws.add(BowlingThrow(display: 'X', pins: 10));
    tenthFrame.throws.add(BowlingThrow(display: 'X', pins: 10));
    tenthFrame.frameScore = 10;
    player.frames.add(tenthFrame);

    return LiveGame(
      id: 'STRIKE456',
      status: 'completed',
      currentFrame: 10,
      viewerCount: 1,
      players: [player],
    );
  }

  // Create a demo multiplayer game
  static LiveGame createDemoMultiPlayerGame() {
    // Player 1 - halfway through the game
    final player1 = Player(
      id: 'player1',
      name: 'Alex',
      frames: List.generate(8, (i) {
        final frame = BowlingFrame.empty();

        // Random frame data
        if (i % 4 == 0 || i % 4 == 3) {
          // Strike
          frame.throws.add(BowlingThrow(display: 'X', pins: 10));
        } else if (i % 4 == 1) {
          // Spare
          frame.throws.add(BowlingThrow(display: '7', pins: 7));
          frame.throws.add(BowlingThrow(display: '/', pins: 3));
        } else {
          // Open
          frame.throws.add(BowlingThrow(display: '8', pins: 8));
          frame.throws.add(BowlingThrow(display: '1', pins: 1));
        }

        frame.frameScore = i + 1;
        return frame;
      }),
      totalScore: 0, // Will be calculated
    );

    // Add a strike in the 9th frame
    final player1NinthFrame = BowlingFrame.empty();
    player1NinthFrame.throws.add(BowlingThrow(display: 'X', pins: 10));
    player1NinthFrame.frameScore = 9;
    player1.frames.add(player1NinthFrame);

    // Add a strike and spare in the 10th frame
    final player1TenthFrame = BowlingFrame.empty();
    player1TenthFrame.throws.add(BowlingThrow(display: 'X', pins: 10));
    player1TenthFrame.throws.add(BowlingThrow(display: '9', pins: 9));
    player1TenthFrame.throws.add(BowlingThrow(display: '/', pins: 1));
    player1TenthFrame.frameScore = 10;
    player1.frames.add(player1TenthFrame);

    // Player 2 - slightly behind
    final player2 = Player(
      id: 'player2',
      name: 'Brian',
      frames: List.generate(7, (i) {
        final frame = BowlingFrame.empty();

        // Mostly spares for this player
        if (i % 4 == 0) {
          // Strike
          frame.throws.add(BowlingThrow(display: 'X', pins: 10));
        } else if (i % 2 == 0) {
          // Open
          frame.throws.add(
              BowlingThrow(display: (6 + i % 3).toString(), pins: 6 + i % 3));
          frame.throws.add(
              BowlingThrow(display: (3 - i % 2).toString(), pins: 3 - i % 2));
        } else {
          // Spare
          frame.throws.add(
              BowlingThrow(display: (5 + i % 3).toString(), pins: 5 + i % 3));
          frame.throws.add(BowlingThrow(display: '/', pins: 5 - i % 3));
        }

        frame.frameScore = i + 1;
        return frame;
      }),
      totalScore: 0, // Will be calculated
    );

    // Player 3 - just started
    final player3 = Player(
      id: 'player3',
      name: 'Charlie',
      frames: List.generate(2, (i) {
        final frame = BowlingFrame.empty();

        if (i == 0) {
          // First frame has a spare
          frame.throws.add(BowlingThrow(display: '9', pins: 9));
          frame.throws.add(BowlingThrow(display: '/', pins: 1));
        } else {
          // Second frame has a strike
          frame.throws.add(BowlingThrow(display: 'X', pins: 10));
        }

        frame.frameScore = i + 1;
        return frame;
      }),
      totalScore: 0, // Will be calculated
    );

    // Calculate scores
    player1.totalScore = _calculateDemoScore(player1.frames);
    player2.totalScore = _calculateDemoScore(player2.frames);
    player3.totalScore = _calculateDemoScore(player3.frames);

    return LiveGame(
      id: 'GAME789',
      status: 'live',
      currentFrame: 3,
      viewerCount: 3,
      players: [player1, player2, player3],
    );
  }

  // Helper method to calculate demo scores
  static int _calculateDemoScore(List<BowlingFrame> frames) {
    int score = 0;
    for (int i = 0; i < frames.length && i < 10; i++) {
      final frame = frames[i];

      for (final t in frame.throws) {
        score += t.pins;
      }

      // Add simple bonuses for strikes and spares
      if (i < 9 && frame.throws.isNotEmpty) {
        if (frame.throws[0].isStrike) {
          score += i + 1 < frames.length && frames[i + 1].throws.isNotEmpty
              ? frames[i + 1].throws[0].pins
              : 0;

          score += i + 1 < frames.length && frames[i + 1].throws.length > 1
              ? frames[i + 1].throws[1].pins
              : (i + 2 < frames.length && frames[i + 2].throws.isNotEmpty
                  ? frames[i + 2].throws[0].pins
                  : 0);
        } else if (frame.throws.length > 1 && frame.throws[1].isSpare) {
          score += i + 1 < frames.length && frames[i + 1].throws.isNotEmpty
              ? frames[i + 1].throws[0].pins
              : 0;
        }
      }
    }

    return score;
  }
}

class Player {
  final String id;
  final String name;
  List<BowlingFrame> frames;
  int totalScore;

  Player({
    required this.id,
    required this.name,
    required this.frames,
    required this.totalScore,
  });
}

class BowlingFrame {
  List<BowlingThrow> throws;
  int frameScore;

  BowlingFrame({
    required this.throws,
    required this.frameScore,
  });

  factory BowlingFrame.empty() {
    return BowlingFrame(
      throws: [],
      frameScore: 0,
    );
  }

  // Check if this frame is complete
  bool get isComplete {
    // Determine the frame number (10th frame is special)
    final frameIndex = frameScore - 1;
    final isTenthFrame = frameIndex == 9;

    if (isTenthFrame) {
      // In 10th frame:
      // - If first throw is strike, need 3 throws
      // - If first two throws make spare, need 3 throws
      // - Otherwise need 2 throws (open frame)

      if (throws.isEmpty) return false;

      if (throws[0].isStrike) {
        return throws.length == 3;
      } else if (throws.length >= 2 && throws[0].pins + throws[1].pins == 10) {
        return throws.length == 3;
      } else {
        return throws.length >= 2; // Open frame in 10th = 2 throws
      }
    } else {
      // In frames 1-9:
      // - Strike = frame complete immediately
      // - Otherwise need 2 throws
      if (throws.isEmpty) return false;

      return throws[0].isStrike || throws.length == 2;
    }
  }

  // Check if this frame is a strike
  bool get isStrike {
    return throws.isNotEmpty && throws[0].isStrike;
  }

  // Check if this frame is a spare
  bool get isSpare {
    return throws.length >= 2 &&
        !throws[0].isStrike &&
        throws[0].pins + throws[1].pins == 10;
  }
}

class BowlingThrow {
  final String display;
  final int pins;

  BowlingThrow({
    required this.display,
    required this.pins,
  });

  // Check if this throw is a strike
  bool get isStrike => display == 'X';

  // Check if this throw is a spare
  bool get isSpare => display == '/';

  // Get the numeric value (for score calculation)
  int? get numericValue {
    if (isStrike) return 10;
    if (isSpare) return null; // Spares depend on previous throw
    if (display == '-') return 0;
    return int.tryParse(display);
  }
}

// Helper to get max of two values
int max(int a, int b) => a > b ? a : b;

// Helper to get min of two values
int min(int a, int b) => a < b ? a : b;
