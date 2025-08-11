

// MARKER: THIS FILE SHOULD BE UPDATED BY THE ASSISTANT - V4
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // No longer used for settings
import '../services/auth_service.dart';
import '../services/timer_service.dart';
import 'settings_page.dart';
import 'login_page.dart';
import 'package:audioplayers/audioplayers.dart'; // Added for beep sound

// REMINDER: Add audioplayers: ^6.0.0 (or latest) to your pubspec.yaml
// REMINDER: Add a beep sound file (e.g., assets/sounds/beep.mp3) to your assets and declare it in pubspec.yaml

// Add this top-level function, typically after imports or before your _HomePageState class
void _appOnDidReceiveLocalNotificationForIOS(
    int id, String? title, String? body, String? payload) {
  // This is the callback for iOS < 10 when a notification is received while the app is in the foreground.
  // You can add logic here if needed, e.g., show a dialog or update app state.
  // For now, it can be empty or have a debug print.
  // debugPrint('iOS foreground notification ($id): $title - $body');
}

// Utility function to format duration
String formatDuration(Duration duration, {bool showHours = false}) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  if (showHours || duration.inHours > 0) {
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  } else {
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

enum PomodoroMode {
  work,
  shortBreak,
  longBreak,
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const int _gameGateMinDailyStudyMinutes = 120;
  final AuthService _authService = AuthService();
  String? _userId;
  String? _displayName;

  final AudioPlayer _audioPlayer = AudioPlayer(); // Added for beep sound

  // Pomodoro Timer State
  final ValueNotifier<Duration> _pomodoroTimeNotifier =
      ValueNotifier(const Duration(minutes: 25));
  final ValueNotifier<bool> _pomodoroRunningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _pomodoroPausedNotifier = ValueNotifier(false);
  final ValueNotifier<int> _pomodoroSessionSeconds =
      ValueNotifier(25 * 60);

  // New setting notifiers for Phase 1
  final ValueNotifier<int> _pomodoroWorkDurationMinutes = // <--- AGGIUNGI QUESTA
      ValueNotifier(25); // Valore predefinito: 25 minuti
  final ValueNotifier<int> _pomodoroShortBreakDurationMinutes =
      ValueNotifier(5); // Dovrebbe già esserci
  final ValueNotifier<int> _pomodoroLongBreakDurationMinutes = // <--- AGGIUNGI QUESTA
      ValueNotifier(15); // Valore predefinito: 15 minuti
  final ValueNotifier<int> _gameBonusRatioStudy =
      ValueNotifier(2);
  final ValueNotifier<int> _currentMalusPlaytimeMinutes =
      ValueNotifier(0);

  DateTime? _pomodoroSessionStartTime;
  Timer? _pomodoroDartTimer;

  // Variabili per il ciclo Pomodoro (esistenti)
  PomodoroMode _pomodoroCurrentMode = PomodoroMode.work;
  final ValueNotifier<PomodoroMode> _pomodoroCurrentModeNotifier = ValueNotifier(PomodoroMode.work); // Per la UI
  int _completedWorkSessions = 0;
  final int _workSessionsBeforeLongBreak = 3; // Mantieni o rendi configurabile in settings

  // Game Timer State
  final ValueNotifier<Duration> _gameTimeElapsedNotifier =
      ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _gameRunningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _gamePausedNotifier = ValueNotifier(false);
  DateTime? _gameSessionStartTime;
  Timer? _gameDartTimer;

  // Total Times Today
  final ValueNotifier<Duration> _totalPomodoroTimeToday =
      ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> _totalGameTimeToday =
      ValueNotifier(Duration.zero);
  // Phase 3: Variables to store state at game start for malus calculation
  int _studyTimeAtGameStartMinutes = 0; // <-- AGGIUNGI QUESTA
  int _malusAtGameStartMinutes = 0;     // <-- AGGIUNGI QUESTA

  Map<String, String> _parseDisplayName(String? displayName) {
    if (displayName == null || displayName.trim().isEmpty) {
      return {'nome': "", 'cognome': ""};
    }

    final String trimmedName = displayName.trim();
    // Rimuove eventuali spazi multipli interni
    final List<String> parts = trimmedName.split(' ').where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty) {
      return {'nome': "", 'cognome': ""};
    }

    String nome = parts.first;
    String cognome = "";

    if (parts.length > 1) {
      cognome = parts.last; // Assume l'ultima parte come cognome
    }

    if (nome == cognome && parts.length == 1) {
      cognome = "";
    }

    return {'nome': nome, 'cognome': cognome};
  }

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  // Aggiungi un set per tenere traccia delle soglie notificate per la sessione di lavoro corrente
  Set<int> _notifiedWorkSessionThresholds = {};
  @override
  void initState() {
    super.initState();
    _initializeNotifications(); // Chiama l'inizializzazione delle notifiche
    _checkCurrentUserAndLoadData();
    // L'impostazione iniziale di _pomodoroTimeNotifier e _pomodoroSessionSeconds
    // è ora gestita meglio da _loadUserSettings o _loadInitialTimerStates.
  }

  @override
  void dispose() {
    _pomodoroDartTimer?.cancel();
    _gameDartTimer?.cancel();
    _audioPlayer.dispose(); // Dispose audio player
    _pomodoroTimeNotifier.dispose();
    _pomodoroRunningNotifier.dispose();
    _pomodoroPausedNotifier.dispose();
    _pomodoroSessionSeconds.dispose();
    _pomodoroWorkDurationMinutes.dispose();
    _pomodoroShortBreakDurationMinutes.dispose();
    _pomodoroLongBreakDurationMinutes.dispose();
    _pomodoroCurrentModeNotifier.dispose(); // Aggiunto dispose
    _gameBonusRatioStudy.dispose();
    _currentMalusPlaytimeMinutes.dispose();
    _gameTimeElapsedNotifier.dispose();
    _gameRunningNotifier.dispose();
    _gamePausedNotifier.dispose();
    _totalPomodoroTimeToday.dispose();
    _totalGameTimeToday.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentUserAndLoadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (mounted) {
        setState(() {
          _userId = user.uid;
          _displayName = user.displayName ?? user.email;
        });
      }
      await _loadUserSettings();
      await _loadInitialTimerStates();
      await _updateTotalTimesToday();
    } else {
      Future.microtask(() {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      });
    }
  }

  Future<void> _loadUserSettings() async {
    if (_userId == null) {
      _pomodoroWorkDurationMinutes.value = 25;
      _pomodoroShortBreakDurationMinutes.value = 5;
      _pomodoroLongBreakDurationMinutes.value = 15;
      _gameBonusRatioStudy.value = 2;
      _currentMalusPlaytimeMinutes.value = 0;

      if (!_pomodoroRunningNotifier.value) {
        _pomodoroCurrentMode = PomodoroMode.work;
        _pomodoroCurrentModeNotifier.value = _pomodoroCurrentMode;
        _pomodoroSessionSeconds.value = _getDurationSecondsForMode(_pomodoroCurrentMode);
        _pomodoroTimeNotifier.value =
            Duration(seconds: _pomodoroSessionSeconds.value);
      }
      return;
    }

    final names = _parseDisplayName(_displayName);
    String firstName = names['nome']!;
    String lastName = names['cognome']!;

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(
        _userId!);
    try {
      final docSnapshot = await userDocRef.get();

      int workMinutes = 25;
      int shortBreakMinutes = 5;
      int longBreakMinutes = 15;
      int gameBonus = 2;
      int currentMalus = 0;

      Map<String, dynamic> settingsToSave = {};
      bool saveSettingsNeeded = false;
      bool saveMalusNeeded = false;

      final Map<String, dynamic>? currentData = docSnapshot.data();

      if (docSnapshot.exists && currentData != null) {
        final settings = currentData['settings'] as Map<String, dynamic>?;

        if (settings != null) {
          workMinutes =
              settings['pomodoroWorkDurationMinutes'] as int? ?? workMinutes;
          if (settings['pomodoroWorkDurationMinutes'] == null) {
            settingsToSave['pomodoroWorkDurationMinutes'] = workMinutes;
            saveSettingsNeeded = true;
          }
          shortBreakMinutes =
              settings['pomodoroShortBreakDurationMinutes'] as int? ??
                  shortBreakMinutes;
          if (settings['pomodoroShortBreakDurationMinutes'] == null) {
            settingsToSave['pomodoroShortBreakDurationMinutes'] =
                shortBreakMinutes;
            saveSettingsNeeded = true;
          }
          longBreakMinutes =
              settings['pomodoroLongBreakDurationMinutes'] as int? ??
                  longBreakMinutes;
          if (settings['pomodoroLongBreakDurationMinutes'] == null) {
            settingsToSave['pomodoroLongBreakDurationMinutes'] =
                longBreakMinutes;
            saveSettingsNeeded = true;
          }
          gameBonus = settings['gameBonusRatioStudy'] as int? ?? gameBonus;
          if (settings['gameBonusRatioStudy'] == null) {
            settingsToSave['gameBonusRatioStudy'] = gameBonus;
            saveSettingsNeeded = true;
          }
        } else {
          settingsToSave = {
            'pomodoroWorkDurationMinutes': workMinutes,
            'pomodoroShortBreakDurationMinutes': shortBreakMinutes,
            'pomodoroLongBreakDurationMinutes': longBreakMinutes,
            'gameBonusRatioStudy': gameBonus,
          };
          saveSettingsNeeded = true;
        }

        currentMalus = currentData['currentMalusPlaytimeMinutes'] as int? ?? 0;
        if (currentData['currentMalusPlaytimeMinutes'] == null) {
          saveMalusNeeded = true;
        }
      } else {
        settingsToSave = {
          'pomodoroWorkDurationMinutes': workMinutes,
          'pomodoroShortBreakDurationMinutes': shortBreakMinutes,
          'pomodoroLongBreakDurationMinutes': longBreakMinutes,
          'gameBonusRatioStudy': gameBonus,
        };
        saveSettingsNeeded = true;
        saveMalusNeeded = true; 
      }

      if (saveSettingsNeeded && settingsToSave.isNotEmpty) {
        await userDocRef.set(
            {'settings': settingsToSave}, SetOptions(merge: true));
      }
      if (saveMalusNeeded) {
        await userDocRef.set({'currentMalusPlaytimeMinutes': currentMalus},
            SetOptions(merge: true));
      }

      Map<String, dynamic> nameUpdates = {};
      if (firstName.isNotEmpty) {
        if (!docSnapshot.exists || currentData?['nome'] == null ||
            currentData?['nome'] != firstName) {
          nameUpdates['nome'] = firstName;
        }
      }
      if (lastName.isNotEmpty) {
        if (!docSnapshot.exists || currentData?['cognome'] == null ||
            currentData?['cognome'] != lastName) {
          nameUpdates['cognome'] = lastName;
        }
      }
      if (nameUpdates.isNotEmpty) {
        await userDocRef.set(nameUpdates, SetOptions(merge: true));
      }

      _pomodoroWorkDurationMinutes.value = workMinutes;
      _pomodoroShortBreakDurationMinutes.value = shortBreakMinutes;
      _pomodoroLongBreakDurationMinutes.value = longBreakMinutes;
      _gameBonusRatioStudy.value = gameBonus;
      _currentMalusPlaytimeMinutes.value = currentMalus;

      if (!_pomodoroRunningNotifier.value) {
        // _pomodoroCurrentMode e _completedWorkSessions sono caricati da _loadInitialTimerStates
        // Quindi, se il timer non è in esecuzione, ci affidiamo ai valori caricati o ai default lì.
        // Qui aggiorniamo _pomodoroSessionSeconds e _pomodoroTimeNotifier basati sulla modalità corrente.
        _pomodoroSessionSeconds.value = _getDurationSecondsForMode(_pomodoroCurrentMode);
        _pomodoroTimeNotifier.value =
            Duration(seconds: _pomodoroSessionSeconds.value);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error loading user settings: ${e.toString()}')));
      }
      _pomodoroWorkDurationMinutes.value = 25;
      _pomodoroShortBreakDurationMinutes.value = 5;
      _pomodoroLongBreakDurationMinutes.value = 15;
      _gameBonusRatioStudy.value = 2;
      _currentMalusPlaytimeMinutes.value = 0;

      if (!_pomodoroRunningNotifier.value) {
        _pomodoroCurrentMode = PomodoroMode.work;
        _pomodoroCurrentModeNotifier.value = _pomodoroCurrentMode;
        _pomodoroSessionSeconds.value = _getDurationSecondsForMode(_pomodoroCurrentMode);
        _pomodoroTimeNotifier.value =
            Duration(seconds: _pomodoroSessionSeconds.value);
      }
    }
  }

  Future<void> _updateUserMalusInFirestore() async {
    if (_userId == null) return;
    try {
      final userDocRef =
      FirebaseFirestore.instance.collection('users').doc(_userId!);
      await userDocRef.set(
        {'currentMalusPlaytimeMinutes': _currentMalusPlaytimeMinutes.value},
        SetOptions(merge: true),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error updating malus in Firestore: ${e.toString()}')));
      }
    }
  }

  int _getDurationSecondsForMode(PomodoroMode mode) {
    switch (mode) {
      case PomodoroMode.work:
        return _pomodoroWorkDurationMinutes.value * 60;
      case PomodoroMode.shortBreak:
        return _pomodoroShortBreakDurationMinutes.value * 60;
      case PomodoroMode.longBreak:
        return _pomodoroLongBreakDurationMinutes.value * 60;
    }
  }

  Future<void> _loadInitialTimerStates() async {
    if (_userId == null) return;

    final pomodoroState =
        await TimerService.loadTimerState(timerId: 'pomodoroTimer');
    if (pomodoroState != null) {
      _pomodoroCurrentMode = PomodoroMode.values[pomodoroState['pomodoroCurrentMode'] ?? PomodoroMode.work.index];
      _pomodoroCurrentModeNotifier.value = _pomodoroCurrentMode;
      _completedWorkSessions = pomodoroState['completedWorkSessions'] ?? 0;

      _pomodoroSessionSeconds.value = pomodoroState['sessionConfiguredDurationSeconds'] ?? _getDurationSecondsForMode(_pomodoroCurrentMode);
      _pomodoroTimeNotifier.value = Duration(seconds: pomodoroState['currentTimeSeconds'] ?? _pomodoroSessionSeconds.value);
      _pomodoroRunningNotifier.value = pomodoroState['isRunning'] ?? false;
      _pomodoroPausedNotifier.value = pomodoroState['isPaused'] ?? false;

      if (pomodoroState['sessionStartTime'] != null &&
          pomodoroState['sessionStartTime'] is Timestamp) {
        _pomodoroSessionStartTime =
            (pomodoroState['sessionStartTime'] as Timestamp).toDate();
      } else {
        _pomodoroSessionStartTime = null;
      }

      if (_pomodoroRunningNotifier.value && !_pomodoroPausedNotifier.value) {
         _pomodoroDartTimer?.cancel();
         _pomodoroDartTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
           _tickPomodoro();
         });
      }
    } else {
      // Nessuno stato salvato, imposta default basati sulla modalità di lavoro
      _pomodoroCurrentMode = PomodoroMode.work;
      _pomodoroCurrentModeNotifier.value = PomodoroMode.work;
      _completedWorkSessions = 0;
      _pomodoroSessionSeconds.value = _getDurationSecondsForMode(_pomodoroCurrentMode);
      _pomodoroTimeNotifier.value = Duration(seconds: _pomodoroSessionSeconds.value);
    }

    final gameState = await TimerService.loadTimerState(timerId: 'gameTimer');
    if (gameState != null) {
      _gameTimeElapsedNotifier.value =
          Duration(seconds: gameState['currentTimeSeconds'] ?? 0);
      _gameRunningNotifier.value = gameState['isRunning'] ?? false;
      _gamePausedNotifier.value = gameState['isPaused'] ?? false;
      if (gameState['sessionStartTime'] != null &&
          gameState['sessionStartTime'] is Timestamp) {
        _gameSessionStartTime =
            (gameState['sessionStartTime'] as Timestamp).toDate();
      } else {
        _gameSessionStartTime = null;
      }

      if (_gameRunningNotifier.value && !_gamePausedNotifier.value) {
        _actuallyStartGameTimer(fromLoad: true);
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveCurrentTimerStates() async {
    if (_userId == null) return;

    await TimerService.saveTimerState(
      timerId: 'pomodoroTimer',
      state: {
        'currentTimeSeconds': _pomodoroTimeNotifier.value.inSeconds,
        'isRunning': _pomodoroRunningNotifier.value,
        'isPaused': _pomodoroPausedNotifier.value,
        'sessionStartTime': _pomodoroSessionStartTime != null
            ? Timestamp.fromDate(_pomodoroSessionStartTime!)
            : null,
        'pomodoroCurrentMode': _pomodoroCurrentMode.index,
        'completedWorkSessions': _completedWorkSessions,
        'sessionConfiguredDurationSeconds': _pomodoroSessionSeconds.value,
      },
    );

    await TimerService.saveTimerState(
      timerId: 'gameTimer',
      state: {
        'currentTimeSeconds': _gameTimeElapsedNotifier.value.inSeconds,
        'isRunning': _gameRunningNotifier.value,
        'isPaused': _gamePausedNotifier.value,
        'sessionStartTime': _gameSessionStartTime != null
            ? Timestamp.fromDate(_gameSessionStartTime!)
            : null,
      },
    );
  }

  /*
  String _generateNamePrefixForDocId(String? displayName) {

    if (displayName == null || displayName.trim().isEmpty) {
      return "unknown_user";
    }
    String sanitizedName = displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim();
    if (sanitizedName.isEmpty) {
      return "unknown_user";
    }
    List<String> parts = sanitizedName.split(' ').where((p) => p.isNotEmpty).toList();
    String prefix;
    if (parts.length >= 2) {
      prefix = "${parts.last}_${parts.first}";
    } else if (parts.length == 1) {
      prefix = parts.first;
    } else {
      prefix = "unknown_user";
    }
    prefix = prefix.replaceAll(' ', '_').replaceAll(RegExp(r'_+'), '_');
    prefix = prefix.replaceAll(RegExp(r'^_|_$'), '');
    return prefix.isEmpty ? "unknown_user" : prefix;
  }
     */

  Future<void> _logSession({
    required String timerType,
    required DateTime startTime,
    required Duration duration,
  }) async {
    if (_userId == null || duration.inSeconds <= 0) return;
    try {
      await TimerService.addSessionLog(sessionData: {
        'userId': _userId,
        'timerType': timerType,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(startTime.add(duration)),
        'durationSeconds': duration.inSeconds,
      });
      await _updateTotalTimesToday();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging session: ${e.toString()}')));
      }
    }
  }

  Future<void> _updateTotalTimesToday() async {
    if (_userId == null) return;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId!)
          .collection('sessions')
          .get();
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay =
          DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      Duration totalPomodoro = Duration.zero;
      Duration totalGame = Duration.zero;
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data();
        if (data['startTime'] == null || data['durationSeconds'] == null) continue;
        DateTime sessionStartTime = (data['startTime'] as Timestamp).toDate();
        if (sessionStartTime
                .isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
            sessionStartTime
                .isBefore(endOfDay.add(const Duration(milliseconds: 1)))) {
          String type = data['timerType'];
          int durationSeconds = data['durationSeconds'] ?? 0;
          if (type == 'pomodoro') {
            totalPomodoro += Duration(seconds: durationSeconds);
          } else if (type == 'game') {
            totalGame += Duration(seconds: durationSeconds);
          }
        }
      }
      _totalPomodoroTimeToday.value = totalPomodoro;
      _totalGameTimeToday.value = totalGame;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error fetching daily totals: ${e.toString()}')));
      }
    }
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('app_icon');

    final DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification:
      _appOnDidReceiveLocalNotificationForIOS, // Pass the top-level function here
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        // Gestisci il tap sulla notifica qui (quando l'app è in background o terminata e l'utente tocca la notifica)
        // String? payload = notificationResponse.payload;
        // if (payload != null) {
        //   debugPrint('notification payload: $payload');
        // }
      },
      // onDidReceiveBackgroundNotificationResponse: notificationTapBackground, // per gestire tap su notifiche in background su Android (necessita di una top-level/static function)
    );

    // Richiedi permessi su Android 13+
    if (Theme.of(context).platform == TargetPlatform.android) { // Assicurati che 'Theme.of(context)' sia accessibile qui
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      if(!granted!){
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications permission denied')));
      }
      // Puoi controllare 'granted' se necessario
    }

    // Richiedi permessi su iOS (già fatto in initializationSettingsIOS ma puoi essere più esplicito)
    // Nota: su iOS >= 10, la richiesta di permessi e la gestione delle notifiche in foreground
    // sono gestite diversamente (spesso in AppDelegate). La callback onDidReceiveLocalNotification
    // è specificamente per iOS < 10 foreground.
    if (Theme.of(context).platform == TargetPlatform.iOS) { // Assicurati che 'Theme.of(context)' sia accessibile qui
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

// Funzione per mostrare una notifica
  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      'pomodoro_channel_id', // id del canale
      'Pomodoro Notifications', // nome del canale
      channelDescription: 'Notifications for Pomodoro timer alerts', // descrizione
      importance: Importance.max,
      priority: Priority.high,
      playSound: true, // Emette il suono di default
      // sound: RawResourceAndroidNotificationSound('nome_file_suono_custom_senza_estensione'), // Per suoni custom in res/raw
      ticker: 'ticker',
    );
    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      0, // id della notifica (puoi usare id diversi se necessario)
      title,
      body,
      notificationDetails,
      // payload: 'item x', // Dati opzionali da passare quando si clicca la notifica
    );
  }

  void _actuallyStartPomodoro() {
    _completedWorkSessions = 0;
    _startPomodoroSession(PomodoroMode.work, isManuallyStartedCycle: true);
  }

  void _startPomodoroSession(PomodoroMode mode, {bool fromLoad = false, bool isManuallyStartedCycle = false}) {
    _pomodoroDartTimer?.cancel();

    _pomodoroCurrentMode = mode;
    _pomodoroCurrentModeNotifier.value = mode;
    _pomodoroRunningNotifier.value = true;
    _pomodoroPausedNotifier.value = false;

    if (mode == PomodoroMode.work) {
      _notifiedWorkSessionThresholds.clear(); // Resetta le soglie notificate all'inizio di una sessione di LAVORO
    }

    if (!fromLoad) {
      _pomodoroSessionSeconds.value = _getDurationSecondsForMode(mode);
      _pomodoroTimeNotifier.value = Duration(seconds: _pomodoroSessionSeconds.value);
      _pomodoroSessionStartTime = DateTime.now();
    }

    _pomodoroDartTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      _tickPomodoro();
    });

    _saveCurrentTimerStates();

    if (mounted && !fromLoad) {
      String message = "";
      if (mode == PomodoroMode.work) message = "Work session started!";
      else if (mode == PomodoroMode.shortBreak) message = "Time for a short break!";
      else if (mode == PomodoroMode.longBreak) message = "Time for a long break!";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }


  void _tickPomodoro() {
    if (!mounted || !_pomodoroRunningNotifier.value || _pomodoroPausedNotifier.value) return;

    if (_pomodoroTimeNotifier.value.inSeconds > 0) {
      _pomodoroTimeNotifier.value =
          Duration(seconds: _pomodoroTimeNotifier.value.inSeconds - 1);
      // Logica per le notifiche intermedie durante la sessione di lavoro
      if (_pomodoroCurrentMode == PomodoroMode.work) {
        int currentTimeSeconds = _pomodoroTimeNotifier.value.inSeconds;

        // Soglie in secondi (15 min = 900s, 10 min = 600s, 5 min = 300s)
        List<int> thresholds = [900, 600, 300];

        for (int threshold in thresholds) {
          if (currentTimeSeconds == threshold && !_notifiedWorkSessionThresholds.contains(threshold)) {
            int minutesLeft = threshold ~/ 60;
            _showNotification(
              'Pomodoro Alert',
              '$minutesLeft minutes remaining in your work session!',
            );
            _notifiedWorkSessionThresholds.add(threshold); // Segna come notificata
            break; // Evita notifiche multiple nello stesso tick se le soglie fossero molto vicine
          }
        }
      }
      // Play beep sound every minute
      if (_pomodoroTimeNotifier.value.inSeconds % 60 == 0 &&
          _pomodoroTimeNotifier.value.inSeconds > 0) { // Avoid beep at 00:00
        _audioPlayer.play(AssetSource('sounds/beep.mp3')); // REMINDER: Ensure 'assets/sounds/beep.mp3' exists
      }

      _saveCurrentTimerStates();
    } else {
      // ... (logica esistente per quando la sessione finisce)
      Duration completedSessionDuration = Duration(seconds: _pomodoroSessionSeconds.value);
      if (_pomodoroSessionStartTime != null) {
        _logSession(
            timerType: 'pomodoro',
            startTime: _pomodoroSessionStartTime!,
            duration: completedSessionDuration);
      }

      PomodoroMode previousMode = _pomodoroCurrentMode;
      PomodoroMode nextMode;

      if (previousMode == PomodoroMode.work) {
        _completedWorkSessions++;
        if (_currentMalusPlaytimeMinutes.value > 0) {
          // ... (logica riduzione malus) ...
        }
        if (_completedWorkSessions >= _workSessionsBeforeLongBreak) {
          nextMode = PomodoroMode.longBreak;
        } else {
          nextMode = PomodoroMode.shortBreak;
        }
      } else if (previousMode == PomodoroMode.shortBreak) {
        nextMode = PomodoroMode.work;
      } else {
        nextMode = PomodoroMode.work;
        _completedWorkSessions = 0;
      }
      _startPomodoroSession(nextMode);
    }
  }
  void _stopPomodoro() {
    _pomodoroDartTimer?.cancel();

    if (_pomodoroSessionStartTime != null && _pomodoroRunningNotifier.value) {
      Duration durationToLog = Duration(seconds: _pomodoroSessionSeconds.value) - _pomodoroTimeNotifier.value;
      if (durationToLog.inSeconds > 0) {
        _logSession(
          timerType: 'pomodoro',
          startTime: _pomodoroSessionStartTime!,
          duration: durationToLog,
        );
      }
    }

    _pomodoroRunningNotifier.value = false;
    _pomodoroPausedNotifier.value = false;
    _pomodoroCurrentMode = PomodoroMode.work;
    _pomodoroCurrentModeNotifier.value = PomodoroMode.work;
    _pomodoroSessionSeconds.value = _getDurationSecondsForMode(PomodoroMode.work);
    _pomodoroTimeNotifier.value = Duration(seconds: _pomodoroSessionSeconds.value);
    _pomodoroSessionStartTime = null;

    _saveCurrentTimerStates();

    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pomodoro session stopped.')));
    }
  }

  void _pausePomodoro() {
    if (_pomodoroRunningNotifier.value) {
      _pomodoroPausedNotifier.value = true;
      _saveCurrentTimerStates();
    }
  }

  void _resumePomodoro() {
    if (_pomodoroRunningNotifier.value && _pomodoroPausedNotifier.value) {
      _pomodoroPausedNotifier.value = false;
      _pomodoroSessionStartTime ??= DateTime.now().subtract(
         Duration(seconds: _pomodoroSessionSeconds.value) - _pomodoroTimeNotifier.value
      );
      _saveCurrentTimerStates();
    }
  }

  void _actuallyStartGameTimer({bool fromLoad = false}) {
    _gameDartTimer?.cancel();
    _gameRunningNotifier.value = true;
    _gamePausedNotifier.value = false;

    if (!fromLoad) {
      _gameTimeElapsedNotifier.value = Duration.zero;
      _gameSessionStartTime = DateTime.now();
      _studyTimeAtGameStartMinutes = _totalPomodoroTimeToday.value.inMinutes;
      _malusAtGameStartMinutes = _currentMalusPlaytimeMinutes.value;
    }

    _gameDartTimer =
        Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      _tickGame();
    });
    _saveCurrentTimerStates();
  }

  void _tickGame() {
    if (!mounted) {
      _gameDartTimer?.cancel();
      return;
    }
    if (!_gameRunningNotifier.value || _gamePausedNotifier.value) {
      return;
    }
    _gameTimeElapsedNotifier.value =
        Duration(seconds: _gameTimeElapsedNotifier.value.inSeconds + 1);
    _saveCurrentTimerStates();
  }

  void _pauseGameTimer() {
    if (_gameRunningNotifier.value) {
      _gamePausedNotifier.value = true;
      _saveCurrentTimerStates();
    }
  }

  void _resumeGameTimer() {
    if (_gameRunningNotifier.value) {
      _gamePausedNotifier.value = false;
      _gameSessionStartTime ??=
          DateTime.now().subtract(_gameTimeElapsedNotifier.value);
      _saveCurrentTimerStates();
    }
  }

  void _stopGameTimer() {
    _gameDartTimer?.cancel();
    if (_gameSessionStartTime != null && _gameRunningNotifier.value) {
      Duration durationToLog = _gameTimeElapsedNotifier.value;
      if (durationToLog.inSeconds > 0) {
        _logSession(
            timerType: 'game',
            startTime: _gameSessionStartTime!,
            duration: durationToLog);
        bool shouldAccumulateMalus = false;
        if (_malusAtGameStartMinutes > 0) {
          shouldAccumulateMalus = true;
        }
        else if (_studyTimeAtGameStartMinutes < _gameGateMinDailyStudyMinutes) {
          shouldAccumulateMalus = true;
        }
        if (shouldAccumulateMalus) {
          int gameMinutesPlayed = durationToLog.inMinutes;
          if (gameMinutesPlayed > 0) {
            int malusGenerated = gameMinutesPlayed * _gameBonusRatioStudy.value;
            _currentMalusPlaytimeMinutes.value += malusGenerated;
            _updateUserMalusInFirestore();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Malus time increased by $malusGenerated minutes.'),
                  backgroundColor: Colors.red[700],
                ),
              );
            }
          }
        }
      }
    }
    _gameRunningNotifier.value = false;
    _gamePausedNotifier.value = false;
    _gameTimeElapsedNotifier.value = Duration.zero;
    _gameSessionStartTime = null;
    _studyTimeAtGameStartMinutes = 0;
    _malusAtGameStartMinutes = 0;
    _saveCurrentTimerStates();
  }

  Future<bool?> _showConfirmationDialog(
      BuildContext context, String currentTimer, String newTimer) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Start $newTimer?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('The $currentTimer is currently active.'),
                Text(
                    'Do you want to stop the $currentTimer and start the $newTimer?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('Confirm'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToPomodoroPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PomodoroPage(
          timeNotifier: _pomodoroTimeNotifier,
          runningNotifier: _pomodoroRunningNotifier,
          pausedNotifier: _pomodoroPausedNotifier,
          sessionSeconds: _pomodoroSessionSeconds,
          currentModeNotifier: _pomodoroCurrentModeNotifier, // Passato qui
          onStart: () async {
            if (!mounted) return;
            if (_gameRunningNotifier.value) {
              final confirmed = await _showConfirmationDialog(
                  context, "Game Timer", "Pomodoro Timer");
              if (!mounted) return;
              if (confirmed == true) {
                _stopGameTimer();
                _actuallyStartPomodoro();
              }
            } else {
              _actuallyStartPomodoro();
            }
          },
          onPause: _pausePomodoro,
          onResume: _resumePomodoro,
          onStop: _stopPomodoro,
        ),
      ),
    );
  }

  void _navigateToGameTimerPage(BuildContext context) {
    final studyMinutesToday = _totalPomodoroTimeToday.value.inMinutes;
    if (studyMinutesToday < _gameGateMinDailyStudyMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Warning: You haven\'t met the daily study goal of $_gameGateMinDailyStudyMinutes minutes. Playing now will accumulate malus time.'),
          backgroundColor: Colors.blue[700],
          duration: const Duration(seconds: 4),
        ),
      );
    }
    if (_currentMalusPlaytimeMinutes.value > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Warning: You have ${_currentMalusPlaytimeMinutes.value} minutes of malus. Playing more will increase it.'),
          backgroundColor: Colors.orange[700],
          duration: const Duration(seconds: 4),
        ),
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameTimerPage(
          timeElapsedNotifier: _gameTimeElapsedNotifier,
          runningNotifier: _gameRunningNotifier,
          pausedNotifier: _gamePausedNotifier,
          onStart: () async {
            if (!mounted) return;
            if (_pomodoroRunningNotifier.value) {
              final confirmed = await _showConfirmationDialog(
                  context, "Pomodoro Timer", "Game Timer");
              if (!mounted || confirmed != true) return;
              _stopPomodoro();
            }
            _actuallyStartGameTimer();
          },
          onPause: _pauseGameTimer,
          onResume: _resumeGameTimer,
          onStop: _stopGameTimer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_displayName ?? 'Study Buddy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              if (_userId == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('User data still loading... Please wait.')));
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    userId: _userId!,
                    initialPomodoroWorkDuration: 
                        _pomodoroWorkDurationMinutes.value, // Modificato per usare il notifier
                    initialPomodoroShortBreakDuration:
                        _pomodoroShortBreakDurationMinutes.value,
                    initialPomodoroLongBreakDuration:
                        _pomodoroLongBreakDurationMinutes.value, // Aggiunto
                    initialGameBonusRatioStudy: _gameBonusRatioStudy.value,
                    onSettingsChanged:
                        (workDur, shortBreakDur, longBreakDur, ratioStudy) {
                      if (!mounted) return;
                      // setState(() { // Non necessario se i ValueNotifier aggiornano la UI
                        _pomodoroWorkDurationMinutes.value = workDur;
                        _pomodoroShortBreakDurationMinutes.value = shortBreakDur;
                        _pomodoroLongBreakDurationMinutes.value = longBreakDur; // Aggiunto
                        _gameBonusRatioStudy.value = ratioStudy;

                        if (!_pomodoroRunningNotifier.value) {
                           // Aggiorna la durata della sessione corrente se non è in esecuzione
                           // basandosi sulla modalità Pomodoro corrente.
                          _pomodoroSessionSeconds.value = _getDurationSecondsForMode(_pomodoroCurrentMode);
                          _pomodoroTimeNotifier.value =
                              Duration(seconds: _pomodoroSessionSeconds.value);
                        }
                      // });
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTimerButton(
                    context,
                    title: 'Pomodoro',
                    timeNotifier: _pomodoroTimeNotifier,
                    totalTimeTodayNotifier: _totalPomodoroTimeToday,
                    backgroundColor: Colors.redAccent,
                    onTap: () => _navigateToPomodoroPage(context),
                  ),
                  const SizedBox(width: 8),
                  _buildTimerButton(
                    context,
                    title: 'Game Timer',
                    timeNotifier: _gameTimeElapsedNotifier,
                    totalTimeTodayNotifier: _totalGameTimeToday,
                    backgroundColor: Colors.greenAccent,
                    onTap: () => _navigateToGameTimerPage(context),
                  ),
                ],
              ),
            ),
            // TODO: Add weekly/monthly stats view
          ],
        ),
      ),
    );
  }

  Widget _buildTimerButton(
    BuildContext context, {
    required String title,
    required ValueNotifier<Duration> timeNotifier,
    required ValueNotifier<Duration> totalTimeTodayNotifier,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(6.0),
            decoration: BoxDecoration(
              color: backgroundColor.withAlpha(50),
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((255 * 0.1).round()),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
              border: Border.all(color: backgroundColor, width: 2),
            ),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  ValueListenableBuilder<Duration>(
                    valueListenable: timeNotifier,
                    builder: (context, duration, _) {
                      return Text(
                        formatDuration(duration),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  ValueListenableBuilder<Duration>(
                    valueListenable: totalTimeTodayNotifier,
                    builder: (context, totalDuration, _) {
                      return Text(
                        'Today: ${formatDuration(totalDuration, showHours: true)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withAlpha((255 * 0.7).round()),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Pomodoro Page ---
class PomodoroPage extends StatefulWidget {
  final ValueNotifier<Duration> timeNotifier;
  final ValueNotifier<bool> runningNotifier;
  final ValueNotifier<bool> pausedNotifier;
  final ValueNotifier<int> sessionSeconds;
  final ValueNotifier<PomodoroMode> currentModeNotifier; // Aggiunto
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const PomodoroPage({
    super.key,
    required this.timeNotifier,
    required this.runningNotifier,
    required this.pausedNotifier,
    required this.sessionSeconds,
    required this.currentModeNotifier, // Aggiunto
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  String _getModeText(PomodoroMode mode) {
    switch (mode) {
      case PomodoroMode.work:
        return 'Work Session';
      case PomodoroMode.shortBreak:
        return 'Short Break';
      case PomodoroMode.longBreak:
        return 'Long Break';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, 
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // Timer continues running in the background. No action needed here to stop it.
        // if (didPop && widget.runningNotifier.value) {
        //   print('Popped PomodoroPage while timer was running.');
        // }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pomodoro Timer'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ValueListenableBuilder<PomodoroMode>(
                valueListenable: widget.currentModeNotifier,
                builder: (context, mode, _) {
                  return Text(
                    _getModeText(mode),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: mode == PomodoroMode.work
                              ? Colors.blueGrey
                              : Colors.teal,
                        ),
                  );
                },
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<Duration>(
                valueListenable: widget.timeNotifier,
                builder: (context, timeLeft, _) {
                  return Text(
                    formatDuration(timeLeft),
                    style: Theme.of(context).textTheme.displayLarge,
                  );
                },
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                valueListenable: widget.runningNotifier,
                builder: (context, isRunning, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: widget.pausedNotifier,
                    builder: (context, isPaused, child) {
                      if (!isRunning) {
                        return FloatingActionButton.extended(
                          onPressed: widget.onStart,
                          label: const Text('Start Session'),
                          icon: const Icon(Icons.play_arrow),
                        );
                      } else if (isPaused) {
                        return FloatingActionButton.extended(
                          onPressed: widget.onResume,
                          label: const Text('Resume Session'),
                          icon: const Icon(Icons.play_arrow),
                        );
                      } else {
                        return FloatingActionButton.extended(
                          onPressed: widget.onPause,
                          label: const Text('Pause Session'),
                          icon: const Icon(Icons.pause),
                        );
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                  valueListenable: widget.runningNotifier,
                  builder: (context, isRunning, _) {
                    if (isRunning) {
                      return TextButton.icon(
                        icon: const Icon(Icons.stop, color: Colors.red),
                        label: const Text('Stop Session',
                            style: TextStyle(color: Colors.red)),
                        onPressed: widget.onStop,
                      );
                    }
                    return const SizedBox.shrink();
                  }),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Game Timer Page ---
class GameTimerPage extends StatefulWidget {
  final ValueNotifier<Duration> timeElapsedNotifier;
  final ValueNotifier<bool> runningNotifier;
  final ValueNotifier<bool> pausedNotifier;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const GameTimerPage({
    super.key,
    required this.timeElapsedNotifier,
    required this.runningNotifier,
    required this.pausedNotifier,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  State<GameTimerPage> createState() => _GameTimerPageState();
}

class _GameTimerPageState extends State<GameTimerPage> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, 
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // Timer continues running in the background. No action needed here to stop it.
        // if (didPop && widget.runningNotifier.value) {
        //   print('Popped GameTimerPage while timer was running.');
        // }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Game Timer'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ValueListenableBuilder<Duration>(
                valueListenable: widget.timeElapsedNotifier,
                builder: (context, timeElapsed, _) {
                  return Text(
                    formatDuration(timeElapsed),
                    style: Theme.of(context).textTheme.displayLarge,
                  );
                },
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                valueListenable: widget.runningNotifier,
                builder: (context, isRunning, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: widget.pausedNotifier,
                    builder: (context, isPaused, child) {
                      if (!isRunning) {
                        return FloatingActionButton.extended(
                          onPressed: widget.onStart,
                          label: const Text('Start Game'),
                          icon: const Icon(Icons.play_arrow),
                        );
                      } else if (isPaused) {
                        return FloatingActionButton.extended(
                          onPressed: widget.onResume,
                          label: const Text('Resume Game'),
                          icon: const Icon(Icons.play_arrow),
                        );
                      } else {
                        return FloatingActionButton.extended(
                          onPressed: widget.onPause,
                          label: const Text('Pause Game'),
                          icon: const Icon(Icons.pause),
                        );
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                  valueListenable: widget.runningNotifier,
                  builder: (context, isRunning, _) {
                    if (isRunning) {
                      return TextButton.icon(
                        icon: const Icon(Icons.stop, color: Colors.red),
                        label: const Text('Stop Game',
                            style: TextStyle(color: Colors.red)),
                        onPressed: widget.onStop,
                      );
                    }
                    return const SizedBox.shrink();
                  }),
            ],
          ),
        ),
      ),
    );
  }
}
