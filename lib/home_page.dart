import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studybuddy/auth_service.dart';
import 'package:studybuddy/pomodoro_page.dart';
import 'package:studybuddy/game_timer_page.dart';
import 'package:studybuddy/settings_page.dart';
import 'package:studybuddy/value_listenable_builder_2.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ValueNotifier<bool> pomodoroRunning = ValueNotifier(false);
  final ValueNotifier<Duration> pomodoroTimeLeft =
  ValueNotifier(const Duration(minutes: 25));
  final ValueNotifier<bool> pomodoroPaused = ValueNotifier(false);
  Timer? _pomodoroTimer;

  final ValueNotifier<bool> gameTimerRunning = ValueNotifier(false);
  final ValueNotifier<Duration> gameTimerElapsed = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> gameTimerPaused = ValueNotifier(false);
  Timer? _gameTimer;

  static const Duration _pomodoroDuration = Duration(minutes: 25);

  void _startPomodoroTimer() async {
    if (gameTimerRunning.value) {
      final confirm = await _showConfirmDialog(
          'L\'altro timer è attivo. Vuoi interromperlo e avviare il Pomodoro?');
      if (!confirm) return;
      _stopGameTimer();
    }

    if (!pomodoroRunning.value) {
      pomodoroRunning.value = true;
      pomodoroPaused.value = false;
      _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (pomodoroTimeLeft.value.inSeconds > 0) {
          pomodoroTimeLeft.value -= const Duration(seconds: 1);
        } else {
          _stopPomodoroTimer();
        }
      });
    }
  }

  void _pausePomodoroTimer() {
    _pomodoroTimer?.cancel();
    pomodoroPaused.value = true;
  }

  void _resumePomodoroTimer() {
    pomodoroPaused.value = false;
    _pomodoroTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (pomodoroTimeLeft.value.inSeconds > 0) {
        pomodoroTimeLeft.value -= const Duration(seconds: 1);
      } else {
        _stopPomodoroTimer();
      }
    });
  }

  void _stopPomodoroTimer() {
    _pomodoroTimer?.cancel();
    pomodoroRunning.value = false;
    pomodoroPaused.value = false;
    pomodoroTimeLeft.value = _pomodoroDuration;
  }

  void _startGameTimer() async {
    if (pomodoroRunning.value) {
      final confirm = await _showConfirmDialog(
          'L\'altro timer è attivo. Vuoi interromperlo e avviare il Game Timer?');
      if (!confirm) return;
      _stopPomodoroTimer();
    }

    if (!gameTimerRunning.value) {
      gameTimerRunning.value = true;
      gameTimerPaused.value = false;
      _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        gameTimerElapsed.value += const Duration(seconds: 1);
      });
    }
  }

  void _pauseGameTimer() {
    _gameTimer?.cancel();
    gameTimerPaused.value = true;
  }

  void _resumeGameTimer() {
    gameTimerPaused.value = false;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      gameTimerElapsed.value += const Duration(seconds: 1);
    });
  }

  void _stopGameTimer() {
    _gameTimer?.cancel();
    gameTimerRunning.value = false;
    gameTimerPaused.value = false;
    gameTimerElapsed.value = Duration.zero;
  }

  Future<bool> _showConfirmDialog(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conferma'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _pomodoroTimer?.cancel();
    _gameTimer?.cancel();
    pomodoroRunning.dispose();
    pomodoroTimeLeft.dispose();
    pomodoroPaused.dispose();
    gameTimerRunning.dispose();
    gameTimerElapsed.dispose();
    gameTimerPaused.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final name = user.displayName ?? 'Utente';

    return Scaffold(
      appBar: AppBar(
        title: Text('Ciao, $name'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            leading: const Icon(Icons.timer),
            title: Row(
              children: [
                const Text('🧠Pomodoro⏱️'),
                const SizedBox(width: 10),
                ValueListenableBuilder2<bool, Duration>(
                  valueListenable1: pomodoroRunning,
                  valueListenable2: pomodoroTimeLeft,
                  builder: (context, isRunning, timeLeft, child) {
                    if (isRunning) {
                      return Text(
                        _formatDuration(timeLeft),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PomodoroPage(
                  runningNotifier: pomodoroRunning,
                  pausedNotifier: pomodoroPaused,
                  timeLeftNotifier: pomodoroTimeLeft,
                  onStart: _startPomodoroTimer,
                  onPause: _pausePomodoroTimer,
                  onResume: _resumePomodoroTimer,
                  onStop: _stopPomodoroTimer,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.videogame_asset),
            title: Row(
              children: [
                const Text('🎮️Game Timer⏱️'),
                const SizedBox(width: 10),
                ValueListenableBuilder2<bool, Duration>(
                  valueListenable1: gameTimerRunning,
                  valueListenable2: gameTimerElapsed,
                  builder: (context, isRunning, timeElapsed, child) {
                    if (isRunning) {
                      return Text(
                        _formatDuration(timeElapsed),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GameTimerPage(
                  runningNotifier: gameTimerRunning,
                  pausedNotifier: gameTimerPaused,
                  timeElapsedNotifier: gameTimerElapsed,
                  onStart: _startGameTimer,
                  onPause: _pauseGameTimer,
                  onResume: _resumeGameTimer,
                  onStop: _stopGameTimer,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('🔧Impostazioni⚙️'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }
}