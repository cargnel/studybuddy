import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TimerService {
  static final _firestore = FirebaseFirestore.instance;
  static String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Saves the state of a specific timer (pomodoroTimer or gameTimer)
  static Future<void> saveTimerState({
    required String timerId, // 'pomodoroTimer' or 'gameTimer'
    required Map<String, dynamic> state,
  }) async {
    if (_userId == null) return; // User not logged in
    // Ensure state map is not null and add lastSaved timestamp
    final Map<String, dynamic> dataToSave = Map.from(state);
    dataToSave['lastSaved'] = FieldValue.serverTimestamp();

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('timers')
        .doc(timerId) // Use timerId to differentiate documents
        .set(dataToSave, SetOptions(merge: true));
  }

  // Loads the state of a specific timer
  static Future<Map<String, dynamic>?> loadTimerState({
    required String timerId, // 'pomodoroTimer' or 'gameTimer'
  }) async {
    if (_userId == null) return null; // User not logged in
    try {
      final docSnap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('timers')
          .doc(timerId)
          .get();
      if (!docSnap.exists || docSnap.data() == null) {
        return null; // No saved state for this timer
      }
      return docSnap.data();
    } catch (e) {
      // print('Error loading timer state for $timerId: $e');
      return null; // Return null on error
    }
  }

  // Adds a new session log
  static Future<void> addSessionLog({
    required Map<String, dynamic> sessionData,
  }) async {
    if (_userId == null) return; // User not logged in
    // Ensure sessionData map is not null and add loggedAt timestamp
    final Map<String, dynamic> dataToLog = Map.from(sessionData);
    dataToLog['loggedAt'] = FieldValue.serverTimestamp();
    
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('sessions') // New collection for session logs
        .add(dataToLog);
  }
}
