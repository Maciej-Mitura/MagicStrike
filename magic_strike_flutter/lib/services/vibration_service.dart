import 'package:haptic_feedback/haptic_feedback.dart';

/// Service to handle vibration feedback
class VibrationService {
  // Singleton pattern
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  // Flag to track if vibration is available to avoid repeated checks
  bool? _hasVibratorCache;

  /// Check if device supports vibration
  Future<bool> hasVibrator() async {
    // Return cached result if available
    if (_hasVibratorCache != null) {
      return _hasVibratorCache!;
    }

    try {
      // Try to check vibrator availability using haptic_feedback package
      _hasVibratorCache = await Haptics.canVibrate();
      return _hasVibratorCache!;
    } catch (e) {
      // Handle exceptions or errors
      print('Error checking vibrator availability: $e');
      // Assume vibration is not available when there's an error
      _hasVibratorCache = false;
      return false;
    }
  }

  /// Vibrate with a strike pattern (longer, more intense vibration)
  /// Creates a "bowling strike" feel with multiple vibrations simulating pins falling
  Future<void> vibrateForStrike() async {
    try {
      // Check vibrator availability with error handling
      final hasVibratorSupport = await hasVibrator();
      if (!hasVibratorSupport) {
        // Skip vibration if not supported
        return;
      }

      // Bowling strike pattern:
      // 1. Initial impact (heavy) - ball hitting pins
      await Haptics.vibrate(HapticsType.heavy);

      // 2. Short pause
      await Future.delayed(const Duration(milliseconds: 90));

      // 3. Medium impact - pins falling and colliding
      await Haptics.vibrate(HapticsType.medium);

      // 4. Another short pause
      await Future.delayed(const Duration(milliseconds: 60));

      // 5. Multiple light impacts in quick succession - remaining pins falling
      await Haptics.vibrate(HapticsType.light);
      await Future.delayed(const Duration(milliseconds: 40));
      await Haptics.vibrate(HapticsType.light);
      await Future.delayed(const Duration(milliseconds: 30));

      // 6. End with success pattern for celebration
      await Haptics.vibrate(HapticsType.success);
    } catch (e) {
      // Log the error but don't crash the app
      print('Error during strike vibration: $e');
    }
  }

  /// Stop any ongoing vibration - note: haptic_feedback doesn't directly support
  /// canceling ongoing vibrations, but our vibrations are short and don't need explicit cancellation
  void stopVibration() {
    // No direct equivalent in haptic_feedback package
    // Each vibration is short and completes on its own
    print(
        'Note: With haptic_feedback package, vibrations are short and don\'t need explicit cancellation');
  }
}
