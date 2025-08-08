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
  static Future<void> addSessionLog(
      {required Map<String, dynamic> sessionData}) async {
    final firestore = FirebaseFirestore.instance;
    final userId = sessionData['userId'] as String?;
    final timerType = sessionData['timerType'] as String?;
    final startTimeStamp = sessionData['startTime'] as Timestamp?;

    // Recupera il prefisso del nome da sessionData
    //final namePrefix = sessionData['namePrefixForDocId'] as String? ?? "unknown_user"; // <--- NUOVA RIGA

    if (userId == null || timerType == null || startTimeStamp == null) {
        print('TimerService.addSessionLog: Dati mancanti per generare ID personalizzato.');
      return;
    }

    final DateTime startTimeDt = startTimeStamp.toDate();

    String year = startTimeDt.year.toString().padLeft(4, '0');
    String month = startTimeDt.month.toString().padLeft(2, '0');
    String day = startTimeDt.day.toString().padLeft(2, '0');
    String hour = startTimeDt.hour.toString().padLeft(2, '0');
    String minute = startTimeDt.minute.toString().padLeft(2, '0');
    String second = startTimeDt.second.toString().padLeft(2, '0');

    String formattedTimestamp = "$year$month${day}T$hour$minute$second";

    String customDocumentId = "${formattedTimestamp}_$timerType";

    try {
      await firestore
          .collection('users')
          .doc(userId)
          .collection('sessions')
          .doc(customDocumentId)
          .set(sessionData);
    } catch (e) {
      print('Errore durante il salvataggio della sessione con ID personalizzato ($customDocumentId): $e');
      rethrow;
    }
  }
}
