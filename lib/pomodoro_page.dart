import 'package:flutter/material.dart';
import 'package:studybuddy/value_listenable_builder_2.dart';

class PomodoroPage extends StatelessWidget {
  final ValueNotifier<bool> runningNotifier;
  final ValueNotifier<bool> pausedNotifier;
  final ValueNotifier<Duration> timeLeftNotifier;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const PomodoroPage({
    super.key,
    required this.runningNotifier,
    required this.pausedNotifier,
    required this.timeLeftNotifier,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro Timer'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<Duration>(
              valueListenable: timeLeftNotifier,
              builder: (context, timeLeft, child) {
                return Text(
                  _formatDuration(timeLeft),
                  style: const TextStyle(fontSize: 48),
                );
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder2<bool, bool>(
              valueListenable1: runningNotifier,
              valueListenable2: pausedNotifier,
              builder: (context, isRunning, isPaused, child) {
                if (isRunning) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: isPaused ? onResume : onPause,
                        child: Text(isPaused ? 'Resume' : 'Pausa'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: onStop,
                        child: const Text('Reset'),
                      ),
                    ],
                  );
                }
                return ElevatedButton(
                  onPressed: onStart,
                  child: const Text('Avvia'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}