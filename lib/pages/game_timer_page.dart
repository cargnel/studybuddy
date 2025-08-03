import 'package:flutter/material.dart';

class GameTimerPage extends StatelessWidget {
  final ValueNotifier<bool> runningNotifier;
  final ValueNotifier<bool> pausedNotifier;
  final ValueNotifier<Duration> timeElapsedNotifier;

  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  final int sessionSeconds;
  // final Future<void> Function() onTimerSaved; // Removed

  const GameTimerPage({
    super.key,
    required this.runningNotifier,
    required this.pausedNotifier,
    required this.timeElapsedNotifier,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.sessionSeconds,
    // required this.onTimerSaved, // Removed
  });

  @override
  Widget build(BuildContext context) {
    String format(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Timer'),
      ),
      body: Center(
        child: ValueListenableBuilder<Duration>(
          valueListenable: timeElapsedNotifier,
          builder: (context, elapsed, _) {
            return Text(
              format(elapsed),
              style: const TextStyle(fontSize: 64),
            );
          },
        ),
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: runningNotifier,
        builder: (context, running, _) {
          if (!running) {
            return FloatingActionButton(
              onPressed: () {
                onStart();
                // onTimerSaved(); // Removed
              },
              child: const Icon(Icons.play_arrow),
            );
          } else {
            return ValueListenableBuilder<bool>(
              valueListenable: pausedNotifier,
              builder: (context, paused, _) {
                if (paused) {
                  return FloatingActionButton(
                    onPressed: () {
                      onResume();
                      // onTimerSaved(); // Removed
                    },
                    child: const Icon(Icons.play_arrow),
                  );
                } else {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        onPressed: () {
                          onPause();
                          // onTimerSaved(); // Removed
                        },
                        child: const Icon(Icons.pause),
                      ),
                      const SizedBox(width: 10),
                      FloatingActionButton(
                        onPressed: () {
                          onStop();
                          // onTimerSaved(); // Removed
                        },
                        child: const Icon(Icons.stop),
                      ),
                    ],
                  );
                }
              },
            );
          }
        },
      ),
    );
  }
}
