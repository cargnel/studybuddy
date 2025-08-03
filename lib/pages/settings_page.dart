import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  final String userId;
  final int initialPomodoroWorkDuration;
  final int initialPomodoroShortBreakDuration;
  final int initialGameBonusRatioStudy; // Represents X in X:1 study:play bonus ratio

  // Callback to notify HomePage of changes
  final void Function(int workDuration, int breakDuration, int ratioStudy)? onSettingsChanged;

  const SettingsPage({
    super.key,
    required this.userId,
    required this.initialPomodoroWorkDuration,
    required this.initialPomodoroShortBreakDuration,
    required this.initialGameBonusRatioStudy,
    this.onSettingsChanged,
  });

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _pomodoroWorkDuration;
  late int _pomodoroShortBreakDuration;
  late int _gameBonusRatioStudy;

  @override
  void initState() {
    super.initState();
    _pomodoroWorkDuration = widget.initialPomodoroWorkDuration;
    _pomodoroShortBreakDuration = widget.initialPomodoroShortBreakDuration;
    _gameBonusRatioStudy = widget.initialGameBonusRatioStudy;
  }

  Future<void> _saveSettings() async {
    if (widget.userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: User ID is not available.')),
        );
      }
      return;
    }

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);

    try {
      // Create a map of the settings to be saved
      final Map<String, dynamic> settingsToSave = {
        'pomodoroWorkDurationMinutes': _pomodoroWorkDuration,
        'pomodoroShortBreakDurationMinutes': _pomodoroShortBreakDuration,
        'gameBonusRatioStudy': _gameBonusRatioStudy,
        // Add other settings to save here if any
      };

      // Save the settings map under a 'settings' field in the user's document
      await userDocRef.set(
        {'settings': settingsToSave},
        SetOptions(merge: true), // merge:true to avoid overwriting other user data/top-level fields
      );

      // Notify HomePage about the change
      widget.onSettingsChanged?.call(
        _pomodoroWorkDuration,
        _pomodoroShortBreakDuration,
        _gameBonusRatioStudy,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            // Pomodoro Work Duration
            Text(
              'Pomodoro - Durata Lavoro: $_pomodoroWorkDuration minuti',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _pomodoroWorkDuration.toDouble(),
              min: 20, // Range 20-40
              max: 40,
              divisions: (40 - 20), // 20 divisions for steps of 1 minute
              label: _pomodoroWorkDuration.round().toString(),
              onChanged: (double value) {
                setState(() {
                  _pomodoroWorkDuration = value.round();
                });
              },
            ),
            const SizedBox(height: 24),

            // Pomodoro Short Break Duration
            Text(
              'Pomodoro - Durata Pausa Breve: $_pomodoroShortBreakDuration minuti',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _pomodoroShortBreakDuration.toDouble(),
              min: 5, // Range 5-30
              max: 30,
              divisions: (30 - 5), // 25 divisions
              label: _pomodoroShortBreakDuration.round().toString(),
              onChanged: (double value) {
                setState(() {
                  _pomodoroShortBreakDuration = value.round();
                   // Optional: Add validation (e.g., break <= work) here or on save
                });
              },
            ),
            const SizedBox(height: 24),
            
            // Game Bonus Ratio
            Text(
              'Gioco - Ratio Studio per Bonus: $_gameBonusRatioStudy : 1',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '(Significa che per ogni $_gameBonusRatioStudy minuti di studio bonus, guadagni 1 minuto di gioco bonus)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Slider(
              value: _gameBonusRatioStudy.toDouble(),
              min: 1, // Range 1-5
              max: 5,
              divisions: (5 - 1), // 4 divisions
              label: _gameBonusRatioStudy.round().toString(),
              onChanged: (double value) {
                setState(() {
                  _gameBonusRatioStudy = value.round();
                });
              },
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
