import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TimerService {
  static Future<void> saveTimerState({
    required String timerId, // e.g., "pomodoroTimer", "gameTimer"
    required bool running,
    required bool paused,
    required int currentTime, // unified field for timeLeft (Pomodoro) or timeElapsed (Game)
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('timers') // Collection for individual timer states
        .doc(timerId);

    await docRef.set({
      'running': running,
      'paused': paused,
      'currentTime': currentTime,
      'lastSaved': FieldValue.serverTimestamp(),
    });
  }

  static Future<Map<String, dynamic>?> loadTimerState({
    required String timerId, // e.g., "pomodoroTimer", "gameTimer"
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('timers')
        .doc(timerId);

    final docSnap = await docRef.get();
    if (!docSnap.exists) return null;

    final data = docSnap.data();
    if (data == null) return null;

    // Provide default values if some fields are missing
    return {
      'running': data['running'] ?? false,
      'paused': data['paused'] ?? false,
      // Default to 25 minutes (1500s) for pomodoro, 0 for game if not found
      'currentTime': data['currentTime'] ?? (timerId == 'pomodoroTimer' ? 1500 : 0),
    };
  }

  static Future<void> addSessionLog({
    required Map<String, dynamic> sessionData,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Ensure userId is part of the log and add a server timestamp for logging time
    final Map<String, dynamic> dataToLog = {
      ...sessionData,
      'userId': user.uid,
      'loggedAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('sessions') // New collection for session logs
        .add(dataToLog); // .add() to generate a unique ID for each log entry
  }
}
