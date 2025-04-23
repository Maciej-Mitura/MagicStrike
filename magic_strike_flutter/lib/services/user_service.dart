import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';

class UserService {
  // Singleton pattern
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Store user data in memory for easy access
  String? _currentUserDeRingID;
  String? _currentUserFirstName;

  // Getters for the stored values
  String? get currentUserDeRingID => _currentUserDeRingID;
  String? get currentUserFirstName => _currentUserFirstName;

  /// Initialize user data after login or registration
  /// Checks if user exists in Firestore, if not creates a new user document
  Future<Map<String, String>> initializeUserData() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user is currently logged in');
      }

      final String uid = currentUser.uid;
      print('Initializing user data for UID: $uid');

      // Extract first name from display name
      String? firstName;
      if (currentUser.displayName != null) {
        // Use the first part as firstName if display name contains spaces
        firstName = currentUser.displayName!.split(' ').first;
      } else {
        // Fallback to email prefix if no display name
        firstName = currentUser.email?.split('@').first;
      }

      // Check if user document exists
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        // User exists, get deRingID and firstName
        final userData = userDoc.data();
        String? deRingID = userData?['deRingID'] as String?;
        String? storedFirstName = userData?['firstName'] as String?;

        // If deRingID doesn't exist, create one
        if (deRingID == null) {
          deRingID = await _generateNewDeRingID();
          await _firestore.collection('users').doc(uid).update({
            'deRingID': deRingID,
          });
        }

        // If firstName doesn't exist or has changed, update it
        if (storedFirstName == null ||
            (firstName != null && storedFirstName != firstName)) {
          await _firestore.collection('users').doc(uid).update({
            'firstName': firstName,
          });
          storedFirstName = firstName;
        }

        // Store values in memory
        _currentUserDeRingID = deRingID;
        _currentUserFirstName = storedFirstName ?? '';

        // Make sure we have the profile picture loaded
        await _loadProfilePictureOnLogin(uid);

        return {
          'deRingID': deRingID,
          'firstName': storedFirstName ?? '',
        };
      } else {
        // User doesn't exist, create new document with new deRingID
        final newDeRingID = await _generateNewDeRingID();

        // Create a new user document
        await _firestore.collection('users').doc(uid).set({
          'deRingID': newDeRingID,
          'firstName': firstName,
          'email': currentUser.email,
          'displayName': currentUser.displayName,
          'createdAt': FieldValue.serverTimestamp(),
          // Additional user fields with empty initial values
          'clubOrTeam': '', // User's bowling club or team
          'dateOfBirth': '', // User's date of birth
          'gender': '', // User's gender
          'lastName': '', // User's last name
          'side': '', // User's bowling side (e.g., right/left)
          'style': '', // User's bowling style
        });

        // Store values in memory
        _currentUserDeRingID = newDeRingID;
        _currentUserFirstName = firstName ?? '';

        return {
          'deRingID': newDeRingID,
          'firstName': firstName ?? '',
        };
      }
    } catch (e) {
      print('Error initializing user data: $e');
      throw Exception('Failed to initialize user data: $e');
    }
  }

  /// Generate a new deRingID based on the highest existing ID
  Future<String> _generateNewDeRingID() async {
    try {
      // Get all user documents
      final QuerySnapshot userSnapshot =
          await _firestore.collection('users').get();

      // Find highest deRingID
      int highestNumber = 0;

      for (final doc in userSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final deRingID = data['deRingID'] as String?;

        if (deRingID != null && deRingID.startsWith('DR')) {
          try {
            final numberPart = deRingID.substring(2); // Remove "DR" prefix
            final number = int.parse(numberPart);

            if (number > highestNumber) {
              highestNumber = number;
            }
          } catch (e) {
            // Ignore parsing errors
            print('Error parsing deRingID: $deRingID');
          }
        }
      }

      // Increment the highest number
      final newNumber = highestNumber + 1;

      // Format with leading zeros (e.g., DR00002)
      final formattedNumber = newNumber.toString().padLeft(5, '0');
      final newDeRingID = 'DR$formattedNumber';

      print('Generated new deRingID: $newDeRingID');
      return newDeRingID;
    } catch (e) {
      print('Error generating new deRingID: $e');
      // Fallback to a timestamp-based ID if something fails
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'DR$timestamp';
    }
  }

  /// Get user data (deRingID and firstName) for the current user (from cache or Firestore)
  Future<Map<String, String?>> getCurrentUserData() async {
    try {
      // Return cached values if available
      if (_currentUserDeRingID != null && _currentUserFirstName != null) {
        print(
            'Returning cached user data: $_currentUserFirstName ($_currentUserDeRingID)');
        return {
          'deRingID': _currentUserDeRingID,
          'firstName': _currentUserFirstName,
        };
      }

      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('getCurrentUserData: No user is currently logged in');
        return {
          'deRingID': null,
          'firstName': null,
        };
      }

      print('Fetching user data for UID: ${currentUser.uid}');
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final deRingID = userData?['deRingID'] as String?;
        final firstName = userData?['firstName'] as String?;

        // Cache the values
        _currentUserDeRingID = deRingID;
        _currentUserFirstName = firstName;

        print('Fetched user data from Firestore: $firstName ($deRingID)');
        return {
          'deRingID': deRingID,
          'firstName': firstName,
        };
      } else {
        print(
            'User document not found in Firestore for UID: ${currentUser.uid}');

        // If the document doesn't exist, try to initialize it
        print('Attempting to initialize user data...');
        return await initializeUserData();
      }
    } catch (e) {
      print('Error getting current user data: $e');
      return {
        'deRingID': null,
        'firstName': null,
      };
    }
  }

  /// Clear cached user data on logout
  void clearUserData() {
    _currentUserDeRingID = null;
    _currentUserFirstName = null;
  }

  /// Update the cached firstName value
  void updateCachedFirstName(String firstName) {
    _currentUserFirstName = firstName;
  }

  /// Update all games with the new firstName for the current user
  /// This ensures all historical games show the correct user information
  Future<void> updateGamesWithNewName(String newFirstName) async {
    try {
      final String? deRingID = _currentUserDeRingID;
      final String? oldFirstName = _currentUserFirstName;

      if (deRingID == null || oldFirstName == null) {
        print('Cannot update games: Missing deRingID or firstName');
        return;
      }

      print(
          'Updating games for user $deRingID: $oldFirstName -> $newFirstName');

      // Query all games
      final QuerySnapshot gamesSnapshot =
          await _firestore.collection('games').get();

      int updatedGamesCount = 0;

      // Batch to handle multiple updates efficiently
      final WriteBatch batch = _firestore.batch();

      // Iterate through all games
      for (final doc in gamesSnapshot.docs) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        bool gameNeedsUpdate = false;

        // Update creatorName if this user created the game
        if (data['createdBy'] == deRingID) {
          data['creatorName'] = newFirstName;
          gameNeedsUpdate = true;
          print('Updated creator name in game ${doc.id}');
        }

        // Update player information in the players array
        if (data['players'] != null && data['players'] is List) {
          final List<dynamic> players = List.from(data['players']);

          for (int i = 0; i < players.length; i++) {
            if (players[i] is Map && players[i]['userId'] == deRingID) {
              // Create a new map with updated firstName
              Map<String, dynamic> updatedPlayer =
                  Map<String, dynamic>.from(players[i]);
              updatedPlayer['firstName'] = newFirstName;

              // Replace the player in the list
              players[i] = updatedPlayer;
              gameNeedsUpdate = true;
              print('Updated player name in game ${doc.id}');
            }
          }

          if (gameNeedsUpdate) {
            data['players'] = players;
          }
        }

        // If any changes were made, add this document to the batch
        if (gameNeedsUpdate) {
          batch.update(doc.reference, data);
          updatedGamesCount++;
        }
      }

      // Commit all updates
      if (updatedGamesCount > 0) {
        await batch.commit();
        print(
            'Updated $updatedGamesCount games with new firstName: $newFirstName');
      } else {
        print('No games needed to be updated');
      }
    } catch (e) {
      print('Error updating games with new name: $e');
    }
  }

  /// Upload a profile picture to Firebase Storage and update the user document
  Future<String?> uploadProfilePicture(XFile imageFile) async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No user is currently logged in');
      }

      final String uid = currentUser.uid;
      final File file = File(imageFile.path);

      // Check if file exists and has data
      if (!file.existsSync()) {
        throw Exception('File does not exist');
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('File is empty');
      }

      print('Uploading file: ${file.path}, size: $fileSize bytes');

      // Create a reference to the location where the file should be uploaded
      final storageReference = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('$uid.jpg');

      // Set metadata with content type
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': uid},
      );

      try {
        // Upload the file to Firebase Storage with explicit timeout
        final UploadTask uploadTask = storageReference.putFile(file, metadata);

        // Monitor upload progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        }, onError: (e) {
          print('Upload task error: $e');
        });

        // Wait for the upload to complete with timeout
        final TaskSnapshot taskSnapshot = await uploadTask.timeout(
          const Duration(minutes: 2),
          onTimeout: () {
            print('Upload timed out, cancelling task');
            uploadTask.cancel();
            throw Exception('Upload timed out after 2 minutes');
          },
        );

        print('Upload completed, getting download URL');

        // Get the download URL
        final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        print('Download URL obtained: $downloadUrl');

        // Update the user document in Firestore with the download URL
        await _firestore.collection('users').doc(uid).update({
          'profilePicture': downloadUrl,
          // Remove any base64 image to avoid conflicts
          'profilePictureBase64': FieldValue.delete(),
        });

        print('User document updated with new profile picture URL');

        // Force notification that profile picture has been updated
        await _loadProfilePictureOnLogin(uid);

        return downloadUrl;
      } catch (uploadError) {
        print('Primary upload method failed: $uploadError');
        print('Trying alternative upload method...');
        return await _tryAlternativeUpload(file, uid);
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
      return null;
    }
  }

  /// Alternative upload method in case the main one fails
  Future<String?> _tryAlternativeUpload(File file, String uid) async {
    try {
      // Use a different path to avoid conflicts
      final storageReference = FirebaseStorage.instance
          .ref()
          .child('profile_pictures_alt')
          .child('${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Read the file as bytes
      final List<int> bytes = await file.readAsBytes();

      // Upload as bytes instead of File object
      final UploadTask uploadTask = storageReference.putData(
        Uint8List.fromList(bytes),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      print('Alternative upload started...');

      // Wait for completion
      final TaskSnapshot taskSnapshot = await uploadTask;
      print('Alternative upload completed');

      // Get URL
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      print('Alternative download URL: $downloadUrl');

      // Update user document
      await _firestore.collection('users').doc(uid).update({
        'profilePicture': downloadUrl,
      });

      return downloadUrl;
    } catch (e) {
      print('Alternative upload also failed: $e');
      return null;
    }
  }

  /// Get the user's profile picture URL
  Future<String?> getProfilePictureUrl() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return null;
      }

      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        return userData?['profilePicture'] as String?;
      }
      return null;
    } catch (e) {
      print('Error getting profile picture URL: $e');
      return null;
    }
  }

  /// Check and request permissions needed for picking images
  Future<bool> _checkAndRequestPermissions() async {
    try {
      if (Platform.isAndroid) {
        print('Checking Android permissions...');
        bool hasPermission = false;

        // For Android 13+ (API level 33+)
        if (await Permission.photos.status.isGranted) {
          print('Photos permission already granted');
          hasPermission = true;
        } else {
          print('Requesting photos permission...');
          final status = await Permission.photos.request();
          if (status.isGranted) {
            print('Photos permission granted');
            hasPermission = true;
          } else {
            print('Photos permission denied');
          }
        }

        // For older Android versions
        if (!hasPermission && await Permission.storage.status.isGranted) {
          print('Storage permission already granted');
          hasPermission = true;
        } else if (!hasPermission) {
          print('Requesting storage permission...');
          final status = await Permission.storage.request();
          if (status.isGranted) {
            print('Storage permission granted');
            hasPermission = true;
          } else {
            print('Storage permission denied');
          }
        }

        if (!hasPermission) {
          // Try with direct media images permission (for Android 13+)
          if (await Permission.mediaLibrary.status.isGranted) {
            print('Media library permission already granted');
            hasPermission = true;
          } else {
            print('Requesting media library permission...');
            final status = await Permission.mediaLibrary.request();
            hasPermission = status.isGranted;
            print(
                'Media library permission ${hasPermission ? "granted" : "denied"}');
          }
        }

        return hasPermission;
      } else if (Platform.isIOS) {
        // For iOS, check and request photos permission
        if (await Permission.photos.status.isGranted) {
          return true;
        } else {
          final status = await Permission.photos.request();
          return status.isGranted;
        }
      }

      // Default to true for other platforms
      return true;
    } catch (e) {
      print('Error checking permissions: $e');
      // Default to true to try picking anyway
      return true;
    }
  }

  /// Pick an image from gallery and upload it as profile picture
  Future<String?> pickAndUploadProfilePicture() async {
    try {
      // Try to check permissions, but don't block on it
      // Image picker has its own permission handling
      final hasPermissions = await _checkAndRequestPermissions();
      if (!hasPermissions) {
        print(
            'Warning: Permission not explicitly granted for accessing photos');
        // Continue anyway since image_picker has its own permission request
      }

      final ImagePicker picker = ImagePicker();

      print('Opening image picker...');

      // Pick an image from gallery
      try {
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
          requestFullMetadata: false, // Reduces memory usage
        );

        if (image == null) {
          print('Image picker: No image selected (user cancelled)');
          return null;
        }

        print('Image selected: ${image.path}');

        // Check file size before uploading
        final File file = File(image.path);
        final fileSize = await file.length();
        final fileSizeKB = fileSize / 1024;

        print('Image size: ${fileSizeKB.toStringAsFixed(2)} KB');

        if (fileSizeKB > 5000) {
          // If image is too large (over 5MB), reduce quality further
          print('Image too large, reducing quality');
          final XFile? compressedImage = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 512,
            maxHeight: 512,
            imageQuality: 50, // Lower quality
            requestFullMetadata: false,
          );

          if (compressedImage == null) {
            print('Failed to compress image');
            return null;
          }

          // Upload the compressed image
          print('Uploading compressed image...');
          return await uploadProfilePicture(compressedImage);
        }

        // Upload the selected image
        print('Uploading image...');
        return await uploadProfilePicture(image);
      } catch (pickerError) {
        print('Error picking image: $pickerError');
        rethrow;
      }
    } catch (e) {
      print('Error picking and uploading profile picture: $e');
      return null;
    }
  }

  /// Ensure the profile picture is loaded on login
  Future<void> _loadProfilePictureOnLogin(String uid) async {
    try {
      // This will trigger a notification to update the More screen
      final profilePicUrl = await getProfilePictureUrl();
      print(
          'Profile picture loaded on login: ${profilePicUrl != null ? 'available' : 'not available'}');

      // If no profile picture URL, check for base64 image
      if (profilePicUrl == null) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final String? base64Image =
              userData?['profilePictureBase64'] as String?;
          if (base64Image != null) {
            print('Base64 profile picture found on login');
          }
        }
      }
    } catch (e) {
      print('Error loading profile picture on login: $e');
    }
  }
}
