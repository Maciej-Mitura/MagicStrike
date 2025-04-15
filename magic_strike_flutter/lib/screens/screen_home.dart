import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate the width and height of the game card
    final cardWidth = screenWidth * 0.85; // 85% of screen width

    // Placeholder data for latest games (to be replaced with backend data later)
    final latestGames = [
      {
        'id': 1,
        'date': '15 June 2023',
        'players': [
          {
            'name': 'John',
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
        'players': [
          {
            'name': 'Michael',
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
        'players': [
          {
            'name': 'Emily',
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
      {
        'id': 4,
        'date': '28 May 2023',
        'players': [
          {
            'name': 'Alex',
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
          },
          {
            'name': 'Jessica',
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
          }
        ]
      },
      {
        'id': 5,
        'date': '20 May 2023',
        'players': [
          {
            'name': 'Thomas',
            'frames': [
              ['X', ''],
              ['X', ''],
              ['X', ''],
              ['8', '/'],
              ['9', '-'],
              ['X', ''],
              ['X', ''],
              ['7', '2'],
              ['8', '/'],
              ['X', 'X', 'X']
            ]
          }
        ]
      },
    ];

    // Function to calculate the bowling score
    int calculateBowlingScore(List<dynamic> frames) {
      int totalScore = 0;

      for (int frameIndex = 0; frameIndex < 10; frameIndex++) {
        List<dynamic> frame = frames[frameIndex];
        bool isStrike = frame[0] == 'X';
        bool isSpare = frame.length > 1 && frame[1] == '/';

        if (isStrike) {
          // Base score for strike is 10
          totalScore += 10;

          // Add bonus for strike: next two rolls
          // First bonus roll
          if (frameIndex == 9) {
            // 10th frame - bonus is in the same frame
            if (frame.length > 1) {
              if (frame[1] == 'X') {
                totalScore += 10; // Strike on first bonus
              } else if (frame[1] == '-') {
                totalScore += 0; // Miss on first bonus
              } else {
                totalScore += int.parse(frame[1]); // Number on first bonus
              }

              // Second bonus roll (only for 10th frame strike)
              if (frame.length > 2) {
                if (frame[2] == 'X') {
                  totalScore += 10; // Strike on second bonus
                } else if (frame[2] == '/') {
                  // Spare on second bonus (10 - value of first bonus)
                  int firstBonusValue = frame[1] == 'X'
                      ? 10
                      : frame[1] == '-'
                          ? 0
                          : int.parse(frame[1]);
                  totalScore += 10 - firstBonusValue;
                } else if (frame[2] == '-') {
                  totalScore += 0; // Miss on second bonus
                } else {
                  totalScore += int.parse(frame[2]); // Number on second bonus
                }
              }
            }
          } else {
            // Frames 1-9: look ahead to next frames for bonus
            if (frameIndex + 1 < frames.length) {
              // First bonus roll (from next frame)
              if (frames[frameIndex + 1][0] == 'X') {
                totalScore += 10; // Next roll is also a strike

                // For the second bonus roll after a strike
                if (frameIndex + 2 < 10) {
                  // If next frame is also a strike, look at first roll of frame after that
                  if (frames[frameIndex + 2][0] == 'X') {
                    totalScore += 10; // Another strike
                  } else {
                    // Not a strike, so just add the first roll value
                    totalScore += frames[frameIndex + 2][0] == '-'
                        ? 0
                        : int.parse(frames[frameIndex + 2][0]);
                  }
                } else if (frameIndex == 8) {
                  // Special case for frame 9 where second bonus is in frame 10's second roll
                  if (frames[9].length > 1) {
                    if (frames[9][1] == 'X') {
                      totalScore += 10;
                    } else if (frames[9][1] == '-') {
                      totalScore += 0;
                    } else if (frames[9][1] == '/') {
                      // This shouldn't happen in proper bowling, but handle it anyway
                      totalScore += 10 -
                          (frames[9][0] == '-'
                              ? 0
                              : 10); // Spare after strike is always 10
                    } else {
                      totalScore += int.parse(frames[9][1]);
                    }
                  }
                }
              } else {
                // Next roll is not a strike
                if (frames[frameIndex + 1][0] == '-') {
                  totalScore += 0; // Miss
                } else {
                  totalScore +=
                      int.parse(frames[frameIndex + 1][0]); // Regular number
                }

                // Second bonus roll
                if (frames[frameIndex + 1].length > 1) {
                  if (frames[frameIndex + 1][1] == '/') {
                    // Spare - add (10 - first roll)
                    totalScore += 10 -
                        (frames[frameIndex + 1][0] == '-'
                            ? 0
                            : int.parse(frames[frameIndex + 1][0]));
                  } else if (frames[frameIndex + 1][1] == '-') {
                    totalScore += 0; // Miss
                  } else if (frames[frameIndex + 1][1] == 'X') {
                    totalScore += 10; // This would be a strike in frame 10
                  } else {
                    totalScore +=
                        int.parse(frames[frameIndex + 1][1]); // Regular number
                  }
                }
              }
            }
          }
        } else if (isSpare) {
          // Base score for spare is 10
          totalScore += 10;

          // Add bonus for spare: next one roll
          if (frameIndex == 9) {
            // 10th frame spare - bonus is in the same frame
            if (frame.length > 2) {
              if (frame[2] == 'X') {
                totalScore += 10; // Strike bonus
              } else if (frame[2] == '-') {
                totalScore += 0; // Miss bonus
              } else {
                totalScore += int.parse(frame[2]); // Number bonus
              }
            }
          } else {
            // Frames 1-9: look ahead to next frame for bonus
            if (frameIndex + 1 < frames.length) {
              if (frames[frameIndex + 1][0] == 'X') {
                totalScore += 10; // Strike bonus
              } else if (frames[frameIndex + 1][0] == '-') {
                totalScore += 0; // Miss bonus
              } else {
                totalScore +=
                    int.parse(frames[frameIndex + 1][0]); // Number bonus
              }
            }
          }
        } else {
          // Open frame - just add the values
          for (var roll in frame) {
            if (roll == 'X') {
              totalScore += 10; // This would only happen in frame 10
            } else if (roll == '-') {
              totalScore += 0; // Miss
            } else if (roll == '/') {
              // This should never happen in an open frame calculation
              // But just in case, handle it as a spare (10 - previous roll)
              var prevRoll = frame[frame.indexOf(roll) - 1];
              totalScore += 10 - (prevRoll == '-' ? 0 : int.parse(prevRoll));
            } else {
              totalScore += int.parse(roll); // Regular number
            }
          }
        }
      }

      return totalScore;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Fixed app bar that doesn't scroll
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 24.0, top: 50.0, bottom: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Latest games',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // Scrollable content below the fixed app bar
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
              physics: const BouncingScrollPhysics(), // Smooth scrolling effect
              itemCount: latestGames.length,
              itemBuilder: (context, index) {
                final game = latestGames[index];

                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: 16.0), // Gap between cards
                  child: Container(
                    width: cardWidth,
                    // Set height based on player count plus space for header
                    height: 90.0 + ((game['players'] as List).length * 35.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: AppColors.ringPrimary,
                        width: 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0), // Reduce padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Game date at the top
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: 8.0), // Reduced bottom padding
                            child: Text(
                              game['date'].toString(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                                color: Colors.black,
                              ),
                            ),
                          ),

                          // Frames grid with player names
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(
                                    2.0), // Reduced padding even more
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final availableWidth = constraints.maxWidth;
                                    // Decrease name column width to 15% to give more space to frames
                                    final nameColumnWidth =
                                        availableWidth * 0.15;
                                    // Allocate width for frames (80%) and total score column (5%)
                                    final framesWidth = availableWidth * 0.80;
                                    final totColumnWidth =
                                        availableWidth * 0.05;
                                    // Calculate frame width from available frames space
                                    final frameWidth = (framesWidth / 10) -
                                        1; // Account for spacing
                                    // Calculate a proper frame height that won't overflow
                                    final frameHeight = frameWidth *
                                        0.9; // Slightly shorter than width

                                    // Create a row of frame numbers at the top
                                    final frameHeaders = Row(
                                      children: [
                                        // Empty space above player names
                                        SizedBox(width: nameColumnWidth),
                                        // Frame numbers
                                        SizedBox(
                                          width: framesWidth,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children:
                                                List.generate(10, (frameIndex) {
                                              return SizedBox(
                                                width: frameWidth,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 2),
                                                  decoration:
                                                      const BoxDecoration(
                                                    color:
                                                        AppColors.ringPrimary,
                                                    borderRadius:
                                                        BorderRadius.only(
                                                      topLeft:
                                                          Radius.circular(3),
                                                      topRight:
                                                          Radius.circular(3),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${frameIndex + 1}',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ),
                                        ),
                                        // Total score header
                                        Container(
                                          width: totColumnWidth,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2),
                                          decoration: const BoxDecoration(
                                            color: AppColors.ringPrimary,
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(3),
                                              topRight: Radius.circular(3),
                                            ),
                                          ),
                                          child: const Text(
                                            'T',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );

                                    // Create player rows with name and frames
                                    final playerRows = Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(
                                          (game['players'] as List).length,
                                          (playerIndex) {
                                        final player = (game['players']
                                            as List)[playerIndex];
                                        final playerName =
                                            player['name'] as String;
                                        final frames = player['frames'] as List;
                                        final playerScore =
                                            calculateBowlingScore(frames);

                                        // Display shortened name if too long
                                        final displayName = playerName.length >
                                                5
                                            ? '${playerName.substring(0, 4)}.'
                                            : playerName;

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical:
                                                  1.0), // Minimal vertical padding
                                          child: Row(
                                            children: [
                                              // Player name column
                                              SizedBox(
                                                width: nameColumnWidth,
                                                child: Text(
                                                  displayName,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                    color: Colors.black,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),

                                              // Player frames
                                              SizedBox(
                                                width: framesWidth,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: List.generate(10,
                                                      (frameIndex) {
                                                    // Get the frame data
                                                    List<dynamic> frame =
                                                        frames.length >
                                                                frameIndex
                                                            ? frames[frameIndex]
                                                            : [];

                                                    // For the 10th frame which may have 3 throws
                                                    bool isTenthFrame =
                                                        frameIndex == 9;
                                                    bool isStrike =
                                                        frame.isNotEmpty &&
                                                            frame[0] == 'X';
                                                    bool hasThirdThrow =
                                                        isTenthFrame &&
                                                            frame.length > 2;

                                                    return SizedBox(
                                                      width: frameWidth,
                                                      child: SizedBox(
                                                        height:
                                                            frameHeight, // Use calculated height
                                                        child: Container(
                                                          margin: const EdgeInsets
                                                              .all(
                                                              0.5), // Very small margin
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        2), // Smaller radius
                                                            border: Border.all(
                                                              color: AppColors
                                                                  .ringPrimary,
                                                              width: 0.5,
                                                            ),
                                                          ),
                                                          child: Stack(
                                                            children: [
                                                              // First throw - centered in the box (lower z-index)
                                                              Positioned.fill(
                                                                child: Center(
                                                                  child: Text(
                                                                    frame.isNotEmpty
                                                                        ? frame[
                                                                            0]
                                                                        : '',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize: (frame.isNotEmpty &&
                                                                              frame[0] == 'X')
                                                                          ? 16
                                                                          : (frame.length > 1 && !isStrike)
                                                                              ? 16
                                                                              : 16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .normal,
                                                                      color: Colors
                                                                          .black,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),

                                                              // Second throw - top right corner (higher z-index)
                                                              if ((frame.length >
                                                                          1 &&
                                                                      !isStrike) ||
                                                                  (isTenthFrame &&
                                                                      frame.length >
                                                                          1))
                                                                Positioned(
                                                                  top: 1,
                                                                  right: 1,
                                                                  child:
                                                                      Container(
                                                                    width: frameWidth *
                                                                        0.3, // Slightly smaller
                                                                    height: frameWidth *
                                                                        0.3, // Slightly smaller
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: Colors
                                                                          .transparent, // Transparent background
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              2),
                                                                    ),
                                                                    child:
                                                                        Center(
                                                                      child:
                                                                          Text(
                                                                        frame[
                                                                            1],
                                                                        style:
                                                                            const TextStyle(
                                                                          fontSize:
                                                                              7, // Small font size
                                                                          fontWeight:
                                                                              FontWeight.normal,
                                                                          color:
                                                                              Colors.black,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),

                                                              // Third throw (10th frame only) (higher z-index)
                                                              if (hasThirdThrow)
                                                                Positioned(
                                                                  bottom: 1,
                                                                  right: 1,
                                                                  child:
                                                                      Container(
                                                                    width: frameWidth *
                                                                        0.3, // Slightly smaller
                                                                    height: frameWidth *
                                                                        0.3, // Slightly smaller
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      color: Colors
                                                                          .transparent, // Transparent background
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              2),
                                                                    ),
                                                                    child:
                                                                        Center(
                                                                      child:
                                                                          Text(
                                                                        frame[
                                                                            2],
                                                                        style:
                                                                            const TextStyle(
                                                                          fontSize:
                                                                              7, // Small font size
                                                                          fontWeight:
                                                                              FontWeight.normal,
                                                                          color:
                                                                              Colors.black,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ),
                                              ),

                                              // Score after frames
                                              Container(
                                                width: totColumnWidth,
                                                height:
                                                    frameHeight, // Match height of frame
                                                padding: EdgeInsets.zero,
                                                alignment: Alignment
                                                    .center, // Center alignment
                                                decoration: BoxDecoration(
                                                  // Remove the background color
                                                  borderRadius:
                                                      BorderRadius.zero,
                                                ),
                                                child: Center(
                                                  // Explicitly center the content
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      '$playerScore',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    );

                                    // Combine the frame headers and player rows
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        frameHeaders,
                                        const SizedBox(
                                            height: 4), // Reduced spacing
                                        playerRows,
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
