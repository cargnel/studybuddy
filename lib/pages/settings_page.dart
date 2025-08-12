import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  final String userId;
  final int initialPomodoroWorkDuration;
  final int initialPomodoroShortBreakDuration;
  final int initialPomodoroLongBreakDuration;
  final int initialGameBonusRatioStudy; 
  final List<int> initialNotificationThresholds; // <-- Aggiunto parametro
  final int initialWorkSessionsBeforeLongBreak;

  // Callback to notify HomePage of changes
  final void Function(int workDuration, int shortBreakDuration, int longBreakDuration, int ratioStudy)? onSettingsChanged;

  const SettingsPage({
    super.key,
    required this.userId,
    required this.initialPomodoroWorkDuration,
    required this.initialPomodoroShortBreakDuration,
    required this.initialPomodoroLongBreakDuration,
    required this.initialGameBonusRatioStudy,
    required this.initialNotificationThresholds, // <-- Aggiunto parametro
    required this.initialWorkSessionsBeforeLongBreak,
    this.onSettingsChanged,
  });

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _pomodoroWorkDuration;
  late int _pomodoroShortBreakDuration;
  late int _pomodoroLongBreakDuration;
  late int _gameBonusRatioStudy;
  late List<int> _notificationThresholds;
  late TextEditingController _notificationThresholdsController;
  late int _workSessionsBeforeLongBreak;

  @override
  void initState() {
    super.initState();
    _pomodoroWorkDuration = widget.initialPomodoroWorkDuration;
    _pomodoroShortBreakDuration = widget.initialPomodoroShortBreakDuration;
    _pomodoroLongBreakDuration = widget.initialPomodoroLongBreakDuration;
    _gameBonusRatioStudy = widget.initialGameBonusRatioStudy;
    _notificationThresholds = List<int>.from(widget.initialNotificationThresholds);
    _notificationThresholdsController = TextEditingController(text: _notificationThresholds.join(","));
    _workSessionsBeforeLongBreak = widget.initialWorkSessionsBeforeLongBreak;
  }

  @override
  void dispose() {
    _notificationThresholdsController.dispose();
    super.dispose();
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
      final Map<String, dynamic> settingsToSave = {
        'pomodoroWorkDurationMinutes': _pomodoroWorkDuration,
        'pomodoroShortBreakDurationMinutes': _pomodoroShortBreakDuration,
        'pomodoroLongBreakDurationMinutes': _pomodoroLongBreakDuration,
        'gameBonusRatioStudy': _gameBonusRatioStudy,
        'notificationThresholds': _notificationThresholds,
        'workSessionsBeforeLongBreak': _workSessionsBeforeLongBreak,
      };

      await userDocRef.set(
        {'settings': settingsToSave},
        SetOptions(merge: true), 
      );

      widget.onSettingsChanged?.call(
        _pomodoroWorkDuration,
        _pomodoroShortBreakDuration,
        _pomodoroLongBreakDuration,
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
            Text(
              'Pomodoro - Durata Lavoro: $_pomodoroWorkDuration minuti',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _pomodoroWorkDuration.toDouble(),
              min: 5,
              max: 60,
              divisions: (60 - 5), // max - min
              label: _pomodoroWorkDuration.round().toString(),
              onChanged: (double value) {
                setState(() {
                  _pomodoroWorkDuration = value.round();
                });
              },
            ),
            const SizedBox(height: 24),

            Text(
              'Pomodoro - Durata Pausa Breve: $_pomodoroShortBreakDuration minuti',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _pomodoroShortBreakDuration.toDouble(),
              min: 2,
              max: 30,
              divisions: (30 - 2), //max - min
              label: _pomodoroShortBreakDuration.round().toString(),
              onChanged: (double value) {
                setState(() {
                  _pomodoroShortBreakDuration = value.round();
                });
              },
            ),
            const SizedBox(height: 24),

            // <-- NUOVO SLIDER PER PAUSA LUNGA -->
            Text(
              'Pomodoro - Durata Pausa Lunga: $_pomodoroLongBreakDuration minuti',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _pomodoroLongBreakDuration.toDouble(),
              min: 2, // Range 10-45 (esempio)
              max: 45,
              divisions: (45 - 2), // max - min,
              label: _pomodoroLongBreakDuration.round().toString(),
              onChanged: (double value) {
                setState(() {
                  _pomodoroLongBreakDuration = value.round();
                });
              },
            ),
            const SizedBox(height: 24),
            // <-- FINE NUOVO SLIDER -->
            
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
              min: 1, 
              max: 5,
              divisions: (5 - 1), 
              label: _gameBonusRatioStudy.round().toString(),
              onChanged: (double value) {
                setState(() {
                  _gameBonusRatioStudy = value.round();
                });
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Notifiche - Soglie di avviso (minuti, separati da virgola):',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextField(
              controller: _notificationThresholdsController,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                hintText: 'Esempio: 15,10,5',
              ),
              onChanged: (value) {
                setState(() {
                  _notificationThresholds = value.split(',').map((e) => int.tryParse(e.trim()) ?? 0).where((e) => e > 0).toList();
                });
              },
            ),
            const SizedBox(height: 24),

            Text(
              'Sessioni di lavoro prima della pausa lunga: $_workSessionsBeforeLongBreak',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _workSessionsBeforeLongBreak.toDouble(),
              min: 2,
              max: 8,
              divisions: 6,
              label: _workSessionsBeforeLongBreak.round().toString(),
              onChanged: (double value) {
                setState(() {
                  _workSessionsBeforeLongBreak = value.round();
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
