class BowlingGameModel {
  final String roomCode;
  final List<BowlingPlayer> players;
  int currentPlayerIndex = 0;
  int currentFrame = 1;
  int currentThrow = 1;

  BowlingGameModel({
    required this.roomCode,
    required this.players,
  });

  // Get the current player
  BowlingPlayer? getCurrentPlayer() {
    if (currentPlayerIndex >= players.length) return null;
    return players[currentPlayerIndex];
  }

  // Record a throw for the current player
  void recordThrow(int pinsDown) {
    if (currentPlayerIndex >= players.length) return;

    final player = players[currentPlayerIndex];

    // Ensure the player has enough frames
    while (player.frames.length < currentFrame) {
      player.frames.add(BowlingFrame());
    }

    // Get the current frame
    final frame = player.frames[currentFrame - 1];

    // Record the throw
    if (currentThrow == 1) {
      // First throw
      frame.firstThrow = pinsDown;

      // If it's a strike, move to next player/frame (except in 10th frame)
      if (pinsDown == 10 && currentFrame < 10) {
        _advanceToNextPlayer();
      } else {
        // Not a strike or 10th frame, move to second throw
        currentThrow = 2;
      }
    } else if (currentThrow == 2) {
      // Second throw
      frame.secondThrow = pinsDown;

      // In 10th frame, check if player gets bonus throw
      if (currentFrame == 10) {
        // If strike or spare in 10th, get one more throw
        if (frame.firstThrow == 10 ||
            (frame.firstThrow != null && frame.firstThrow! + pinsDown == 10)) {
          currentThrow = 3;
        } else {
          // No bonus, move to next player
          _advanceToNextPlayer();
        }
      } else {
        // Not 10th frame, always advance to next player
        _advanceToNextPlayer();
      }
    } else if (currentThrow == 3 && currentFrame == 10) {
      // Third throw (only in 10th frame)
      frame.thirdThrow = pinsDown;

      // Move to next player
      _advanceToNextPlayer();
    }

    // Calculate scores after each throw
    _calculateScores();
  }

  // Move to the next player or frame
  void _advanceToNextPlayer() {
    currentThrow = 1;

    // Next player
    currentPlayerIndex++;

    // If we've gone through all players, advance to the next frame
    if (currentPlayerIndex >= players.length) {
      currentPlayerIndex = 0;
      currentFrame++;

      // Check if game is complete
      if (currentFrame > 10) {
        // Game complete
        currentFrame = 10;
        currentPlayerIndex = players.length; // Set to invalid index
      }
    }
  }

  // Calculate scores for all players
  void _calculateScores() {
    for (final player in players) {
      int totalScore = 0;

      for (int i = 0; i < player.frames.length; i++) {
        final frame = player.frames[i];
        frame.score = 0;

        // Basic score for this frame
        int frameScore = 0;

        // First throw
        if (frame.firstThrow != null) {
          frameScore += frame.firstThrow!;
        }

        // Second throw
        if (frame.secondThrow != null) {
          frameScore += frame.secondThrow!;
        }

        // Third throw (10th frame only)
        if (i == 9 && frame.thirdThrow != null) {
          frameScore += frame.thirdThrow!;
        }

        // Add strike/spare bonuses for frames 1-9
        if (i < 9) {
          // Strike bonus - next two throws
          if (frame.isStrike) {
            // Get next throw
            int? nextThrow = _getNextThrow(player, i);
            if (nextThrow != null) frameScore += nextThrow;

            // Get second next throw
            int? secondNextThrow = _getSecondNextThrow(player, i);
            if (secondNextThrow != null) frameScore += secondNextThrow;
          }
          // Spare bonus - next throw
          else if (frame.isSpare) {
            int? nextThrow = _getNextThrow(player, i);
            if (nextThrow != null) frameScore += nextThrow;
          }
        }

        // Add frame score to total
        totalScore += frameScore;
        frame.score = totalScore;
      }
    }
  }

  // Get the next throw after a given frame
  int? _getNextThrow(BowlingPlayer player, int frameIndex) {
    // Next frame exists
    if (frameIndex + 1 < player.frames.length) {
      final nextFrame = player.frames[frameIndex + 1];

      // Return first throw of next frame
      return nextFrame.firstThrow;
    }

    return null;
  }

  // Get the second next throw after a given frame
  int? _getSecondNextThrow(BowlingPlayer player, int frameIndex) {
    // Next frame exists
    if (frameIndex + 1 < player.frames.length) {
      final nextFrame = player.frames[frameIndex + 1];

      // If first throw in next frame is a strike and not 10th frame
      if (nextFrame.firstThrow == 10 && frameIndex + 1 < 9) {
        // Look at first throw of the frame after next
        if (frameIndex + 2 < player.frames.length) {
          return player.frames[frameIndex + 2].firstThrow;
        }
      } else {
        // Otherwise return second throw of next frame
        return nextFrame.secondThrow;
      }
    }

    return null;
  }

  // Edit a frame throw (for admin corrections)
  void editFrameThrow(String playerId, int frameIndex, int pinsDown) {
    // Get the player
    final playerIndex = players.indexWhere((p) => p.id == playerId);
    if (playerIndex < 0 || frameIndex >= 10) return;

    final player = players[playerIndex];

    // Ensure the frame exists
    if (frameIndex >= player.frames.length) return;

    final frame = player.frames[frameIndex];

    // For simplicity, just replace the first throw and clear second/third
    frame.firstThrow = pinsDown;
    frame.secondThrow = null;
    frame.thirdThrow = null;

    // Recalculate scores
    _calculateScores();

    // Reset current player/frame to the edited frame
    if (frameIndex + 1 < currentFrame ||
        (frameIndex + 1 == currentFrame && playerIndex <= currentPlayerIndex)) {
      currentFrame = frameIndex + 1;
      currentPlayerIndex = playerIndex;
      currentThrow = frame.firstThrow == 10 && currentFrame < 10 ? 1 : 2;
    }
  }
}

class BowlingPlayer {
  final String id;
  final String name;
  final List<BowlingFrame> frames;

  BowlingPlayer({
    required this.id,
    required this.name,
    required this.frames,
  });
}

class BowlingFrame {
  int? firstThrow;
  int? secondThrow;
  int? thirdThrow; // Only used in 10th frame
  int score = 0;

  // A frame is complete if it has enough throws
  bool get isComplete {
    // First 9 frames
    if (score < 10) {
      return firstThrow == 10 || secondThrow != null;
    }
    // 10th frame
    else {
      // Strike in 10th frame requires 3 throws
      if (firstThrow == 10) {
        return thirdThrow != null;
      }
      // Spare in 10th frame requires 3 throws
      else if (isSpare) {
        return thirdThrow != null;
      }
      // Open frame in 10th only needs 2 throws
      else {
        return secondThrow != null;
      }
    }
  }

  // Check if this is a strike
  bool get isStrike => firstThrow == 10;

  // Check if this is a spare
  bool get isSpare {
    if (firstThrow == null || secondThrow == null) return false;
    if (isStrike) return false;
    return firstThrow! + secondThrow! == 10;
  }
}
