// MARKER: THIS FILE SHOULD BE UPDATED BY THE ASSISTANT - V4
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // No longer used for settings
import '../services/auth_service.dart';
import '../services/timer_service.dart';
import 'settings_page.dart';
import 'login_page.dart';

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  String? _userId;
  String? _displayName;

  // Pomodoro Timer State
  final ValueNotifier<Duration> _pomodoroTimeNotifier =
      ValueNotifier(const Duration(minutes: 25));
  final ValueNotifier<bool> _pomodoroRunningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _pomodoroPausedNotifier = ValueNotifier(false);
  final ValueNotifier<int> _pomodoroSessionSeconds =
      ValueNotifier(25 * 60); 

  // New setting notifiers for Phase 1
  final ValueNotifier<int> _pomodoroShortBreakDurationMinutes =
      ValueNotifier(5); 
  final ValueNotifier<int> _gameBonusRatioStudy =
      ValueNotifier(2); 
  final ValueNotifier<int> _currentMalusPlaytimeMinutes =
      ValueNotifier(0); 

  DateTime? _pomodoroSessionStartTime;
  Timer? _pomodoroDartTimer;

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

  @override
  void initState() {
    super.initState();
    _checkCurrentUserAndLoadData();
  }

  @override
  void dispose() {
    _pomodoroDartTimer?.cancel();
    _gameDartTimer?.cancel();
    _pomodoroTimeNotifier.dispose();
    _pomodoroRunningNotifier.dispose();
    _pomodoroPausedNotifier.dispose();
    _pomodoroSessionSeconds.dispose();
    _pomodoroShortBreakDurationMinutes.dispose();
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
      const defaultWorkMinutes = 25;
      const defaultBreakMinutes = 5;
      const defaultRatioStudy = 2;

      _pomodoroSessionSeconds.value = defaultWorkMinutes * 60;
      _pomodoroShortBreakDurationMinutes.value = defaultBreakMinutes;
      _gameBonusRatioStudy.value = defaultRatioStudy;
      _currentMalusPlaytimeMinutes.value = 0; 

      if (!_pomodoroRunningNotifier.value) {
        _pomodoroTimeNotifier.value =
            Duration(seconds: _pomodoroSessionSeconds.value);
      }
      return;
    }

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(_userId!);
    try {
      final docSnapshot = await userDocRef.get();
      int pomodoroWorkDuration = 25;
      int pomodoroBreakDuration = 5;
      int gameBonusRatio = 2;
      int currentMalus = 0;

      Map<String, dynamic> settingsToSave = {};
      bool saveSettingsNeeded = false;
      bool saveMalusNeeded = false;

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        final settings = data['settings'] as Map<String, dynamic>?;

        if (settings != null) {
          pomodoroWorkDuration = settings['pomodoroWorkDurationMinutes'] as int? ?? pomodoroWorkDuration;
          if (settings['pomodoroWorkDurationMinutes'] == null) {
            settingsToSave['pomodoroWorkDurationMinutes'] = pomodoroWorkDuration;
            saveSettingsNeeded = true;
          }

          pomodoroBreakDuration = settings['pomodoroShortBreakDurationMinutes'] as int? ?? pomodoroBreakDuration;
          if (settings['pomodoroShortBreakDurationMinutes'] == null) {
            settingsToSave['pomodoroShortBreakDurationMinutes'] = pomodoroBreakDuration;
            saveSettingsNeeded = true;
          }

          gameBonusRatio = settings['gameBonusRatioStudy'] as int? ?? gameBonusRatio;
          if (settings['gameBonusRatioStudy'] == null) {
            settingsToSave['gameBonusRatioStudy'] = gameBonusRatio;
            saveSettingsNeeded = true;
          }
        } else {
          settingsToSave['pomodoroWorkDurationMinutes'] = pomodoroWorkDuration;
          settingsToSave['pomodoroShortBreakDurationMinutes'] = pomodoroBreakDuration;
          settingsToSave['gameBonusRatioStudy'] = gameBonusRatio;
          saveSettingsNeeded = true;
        }

        currentMalus = data['currentMalusPlaytimeMinutes'] as int? ?? 0;
        if (data['currentMalusPlaytimeMinutes'] == null) {
           saveMalusNeeded = true; 
        }

      } else {
        settingsToSave = {
          'pomodoroWorkDurationMinutes': pomodoroWorkDuration,
          'pomodoroShortBreakDurationMinutes': pomodoroBreakDuration,
          'gameBonusRatioStudy': gameBonusRatio,
        };
        saveSettingsNeeded = true;
        saveMalusNeeded = true; 
      }

      if (saveSettingsNeeded && settingsToSave.isNotEmpty) {
        await userDocRef.set(
            {'settings': settingsToSave}, SetOptions(merge: true));
      }
      if (saveMalusNeeded) {
        // Ensure malus is saved at the root of the user document
        await userDocRef.set({'currentMalusPlaytimeMinutes': currentMalus}, SetOptions(merge: true));
      }

      _pomodoroSessionSeconds.value = pomodoroWorkDuration * 60;
      _pomodoroShortBreakDurationMinutes.value = pomodoroBreakDuration;
      _gameBonusRatioStudy.value = gameBonusRatio;
      _currentMalusPlaytimeMinutes.value = currentMalus;

      if (!_pomodoroRunningNotifier.value) {
        _pomodoroTimeNotifier.value =
            Duration(seconds: _pomodoroSessionSeconds.value);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading user settings: ${e.toString()}')));
      }
      _pomodoroSessionSeconds.value = 25 * 60;
      _pomodoroShortBreakDurationMinutes.value = 5;
      _gameBonusRatioStudy.value = 2;
      _currentMalusPlaytimeMinutes.value = 0;
      if (!_pomodoroRunningNotifier.value) {
        _pomodoroTimeNotifier.value =
            Duration(seconds: _pomodoroSessionSeconds.value);
      }
    }
  }

  Future<void> _loadInitialTimerStates() async {
    if (_userId == null) return;

    final pomodoroState =
        await TimerService.loadTimerState(timerId: 'pomodoroTimer');
    if (pomodoroState != null) {
      _pomodoroTimeNotifier.value = Duration(
          seconds:
              pomodoroState['currentTimeSeconds'] ?? _pomodoroSessionSeconds.value);
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
        _actuallyStartPomodoro(fromLoad: true);
      }
    } else {
      _pomodoroTimeNotifier.value =
          Duration(seconds: _pomodoroSessionSeconds.value);
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

  void _actuallyStartPomodoro({bool fromLoad = false}) {
    _pomodoroDartTimer?.cancel();
    _pomodoroRunningNotifier.value = true;
    _pomodoroPausedNotifier.value = false;

    if (!fromLoad) {
      _pomodoroTimeNotifier.value =
          Duration(seconds: _pomodoroSessionSeconds.value);
      _pomodoroSessionStartTime = DateTime.now();
    }

    _pomodoroDartTimer =
        Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      _tickPomodoro();
    });
    _saveCurrentTimerStates();
  }

  void _tickPomodoro() {
    if (!mounted) {
      _pomodoroDartTimer?.cancel();
      return;
    }
    if (!_pomodoroRunningNotifier.value || _pomodoroPausedNotifier.value) {
      return;
    }
    if (_pomodoroTimeNotifier.value.inSeconds > 0) {
      _pomodoroTimeNotifier.value =
          Duration(seconds: _pomodoroTimeNotifier.value.inSeconds - 1);
      _saveCurrentTimerStates();
    } else {
      if (_pomodoroSessionStartTime != null) {
        _logSession(
          timerType: 'pomodoro',
          startTime: _pomodoroSessionStartTime!,
          duration: Duration(seconds: _pomodoroSessionSeconds.value),
        );
      }
      _stopPomodoro();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Pomodoro session finished! Time for a break.')),
        );
      }
    }
  }

  void _pausePomodoro() {
    if (_pomodoroRunningNotifier.value) {
      _pomodoroPausedNotifier.value = true;
      _saveCurrentTimerStates();
    }
  }

  void _resumePomodoro() {
    if (_pomodoroRunningNotifier.value) {
      _pomodoroPausedNotifier.value = false;
      _pomodoroSessionStartTime ??= DateTime.now()
          .subtract(Duration(seconds: _pomodoroSessionSeconds.value) -
              _pomodoroTimeNotifier.value);
      _saveCurrentTimerStates();
    }
  }

  void _stopPomodoro() {
    _pomodoroDartTimer?.cancel();
    if (_pomodoroSessionStartTime != null && _pomodoroRunningNotifier.value) {
      Duration durationToLog =
          Duration(seconds: _pomodoroSessionSeconds.value) -
              _pomodoroTimeNotifier.value;
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
    _pomodoroTimeNotifier.value =
        Duration(seconds: _pomodoroSessionSeconds.value);
    _pomodoroSessionStartTime = null;
    _saveCurrentTimerStates();
  }

  void _actuallyStartGameTimer({bool fromLoad = false}) {
    _gameDartTimer?.cancel();
    _gameRunningNotifier.value = true;
    _gamePausedNotifier.value = false;

    if (!fromLoad) {
      _gameTimeElapsedNotifier.value = Duration.zero;
      _gameSessionStartTime = DateTime.now();
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
          duration: durationToLog,
        );
      }
    }
    _gameRunningNotifier.value = false;
    _gamePausedNotifier.value = false;
    _gameTimeElapsedNotifier.value = Duration.zero;
    _gameSessionStartTime = null;
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
              if (!mounted) return;
              if (confirmed == true) {
                _stopPomodoro();
                _actuallyStartGameTimer();
              }
            } else {
              _actuallyStartGameTimer();
            }
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
                        (_pomodoroSessionSeconds.value / 60).round(),
                    initialPomodoroShortBreakDuration:
                        _pomodoroShortBreakDurationMinutes.value, // Phase 1 change
                    initialGameBonusRatioStudy: _gameBonusRatioStudy.value, // Phase 1 change
                    onSettingsChanged:
                        (workDuration, breakDuration, ratioStudy) { // Phase 1 change
                      if (!mounted) return;
                      setState(() {
                        _pomodoroSessionSeconds.value = workDuration * 60;
                        _pomodoroShortBreakDurationMinutes.value = breakDuration; // Phase 1 change
                        _gameBonusRatioStudy.value = ratioStudy; // Phase 1 change

                        if (!_pomodoroRunningNotifier.value) {
                          _pomodoroTimeNotifier.value =
                              Duration(seconds: _pomodoroSessionSeconds.value);
                        }
                      });
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
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, 
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Stop Timer?'),
            content: const Text(
                'The Pomodoro timer is running. Do you want to stop it and go back?'),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Stop and Go Back')),
            ],
          ),
        );
        if (confirm == true && mounted) {
          widget.onStop();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pomodoro Timer'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ValueListenableBuilder<int>(
                  valueListenable: widget.sessionSeconds,
                  builder: (context, fullDurationSeconds, _) {
                    return ValueListenableBuilder<Duration>(
                      valueListenable: widget.timeNotifier,
                      builder: (context, timeLeft, _) {
                        return Text(
                          formatDuration(timeLeft),
                          style: Theme.of(context).textTheme.displayLarge,
                        );
                      },
                    );
                  }),
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
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Stop Timer?'),
            content: const Text(
                'The Game timer is running. Do you want to stop it and go back?'),
            actions: <Widget>[
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Stop and Go Back')),
            ],
          ),
        );
        if (confirm == true && mounted) {
          widget.onStop();
          Navigator.of(context).pop();
        }
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
