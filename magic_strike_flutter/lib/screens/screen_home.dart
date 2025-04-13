import 'package:flutter/material.dart';
import 'package:magic_strike_flutter/constants/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate the width and height of the game card
    final cardWidth = screenWidth * 0.85; // 85% of screen width
    final cardHeight = cardWidth * 0.75; // 75% of card width

    // Placeholder data for latest games (to be replaced with backend data later)
    final latestGames = [
      {
        'id': 1,
        'date': '15 June 2023',
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
        'id': 2,
        'date': '10 June 2023',
        'frames': [
          ['1', '/'],
          ['2', '/'],
          ['3', '/'],
          ['4', '/'],
          ['5', '/'],
          ['6', '/'],
          ['7', '/'],
          ['8', '-'],
          ['1', '/'],
          ['2', '-']
        ]
      },
      {
        'id': 3,
        'date': '5 June 2023',
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
        'id': 4,
        'date': '28 May 2023',
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
        'id': 5,
        'date': '20 May 2023',
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
                  fontSize: 24,
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
                final totalScore =
                    calculateBowlingScore(game['frames'] as List);

                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: 16.0), // Gap between cards
                  child: Container(
                    width: cardWidth,
                    height: cardHeight,
                    decoration: BoxDecoration(
                      color: AppColors
                          .ringBackground3rd, // Changed to ringBackground3rd
                      borderRadius:
                          BorderRadius.circular(12.0), // Figma spec: 12
                      // No box shadow as requested
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Frames grid - moved to top
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.ringBackground3rd,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final availableWidth = constraints.maxWidth;
                                    final frameWidth = availableWidth / 10;

                                    return Column(
                                      children: [
                                        // Row moved to top instead of using Spacer
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children:
                                              List.generate(10, (frameIndex) {
                                            // Get the frame data
                                            List<dynamic> frame =
                                                (game['frames']
                                                    as List)[frameIndex];

                                            // For the 10th frame which may have 3 throws
                                            bool isTenthFrame = frameIndex == 9;
                                            bool isStrike = frame.isNotEmpty &&
                                                frame[0] == 'X';
                                            bool hasThirdThrow = isTenthFrame &&
                                                frame.length > 2;

                                            return SizedBox(
                                              width: frameWidth,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Frame number
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 2),
                                                    width: double.infinity,
                                                    decoration:
                                                        const BoxDecoration(
                                                      color: Color(
                                                          0xFFF72C22), // ringPrimary
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
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize:
                                                            12, // Increased size
                                                        fontWeight: FontWeight
                                                            .bold, // Added bold
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),

                                                  // Grid of throws for this frame
                                                  Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 4.0),
                                                    child: AspectRatio(
                                                      aspectRatio:
                                                          1.0, // Ensuring a square box (1:1 ratio)
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .transparent, // Changed back to transparent
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(3),
                                                        ),
                                                        child: Stack(
                                                          children: [
                                                            // First throw - centered in the box
                                                            Center(
                                                              child: Text(
                                                                frame.isNotEmpty
                                                                    ? frame[0]
                                                                    : '',
                                                                style:
                                                                    TextStyle(
                                                                  // Smaller size for X, normal for other symbols
                                                                  fontSize: (frame
                                                                              .isNotEmpty &&
                                                                          frame[0] ==
                                                                              'X')
                                                                      ? 18
                                                                      : (frame.length > 1 &&
                                                                              !isStrike)
                                                                          ? 16
                                                                          : 20,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .white, // Changed to white
                                                                ),
                                                              ),
                                                            ),

                                                            // Second throw - top right corner, improved visibility
                                                            if ((frame.length >
                                                                        1 &&
                                                                    !isStrike) ||
                                                                (isTenthFrame &&
                                                                    frame.length >
                                                                        1))
                                                              Align(
                                                                alignment:
                                                                    Alignment
                                                                        .topRight,
                                                                child:
                                                                    Container(
                                                                  width:
                                                                      frameWidth *
                                                                          0.4,
                                                                  height:
                                                                      frameWidth *
                                                                          0.4,
                                                                  margin:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          top:
                                                                              1,
                                                                          right:
                                                                              1),
                                                                  child: Center(
                                                                    child: Text(
                                                                      frame[1],
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),

                                                            // Third throw (10th frame only)
                                                            if (hasThirdThrow)
                                                              Align(
                                                                alignment: Alignment
                                                                    .bottomRight,
                                                                child:
                                                                    Container(
                                                                  width:
                                                                      frameWidth *
                                                                          0.4,
                                                                  height:
                                                                      frameWidth *
                                                                          0.4,
                                                                  margin:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          bottom:
                                                                              1,
                                                                          right:
                                                                              1),
                                                                  child: Center(
                                                                    child: Text(
                                                                      frame[2],
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ),
                                        const Spacer(), // Push the date & score to the bottom
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Game date and total score - moved to bottom
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                game['date'].toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Total: $totalScore', // Using calculated score
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
