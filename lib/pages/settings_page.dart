import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  final void Function(int)? onPomodoroDurationChanged;
  final String userId;
  final int initialPomodoroDuration;

  const SettingsPage({
    super.key,
    required this.userId,
    required this.initialPomodoroDuration,
    this.onPomodoroDurationChanged,
  });

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _pomodoroDuration;
  // Add other settings variables here if needed

  @override
  void initState() {
    super.initState();
    _pomodoroDuration = widget.initialPomodoroDuration;
  }

  Future<void> _saveSettings() async {
    if (widget.userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User ID is not available.')),
      );
      return;
    }

    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(widget.userId);

    try {
      await userDocRef.set({
        'settings': {
          'pomodoroDurationMinutes': _pomodoroDuration,
          // Add other settings to save here
        }
      }, SetOptions(merge: true)); // merge:true to avoid overwriting other user data/settings

      if (widget.onPomodoroDurationChanged != null) {
        widget.onPomodoroDurationChanged!(_pomodoroDuration);
      }

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
              'Pomodoro Duration: $_pomodoroDuration minutes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: _pomodoroDuration.toDouble(),
              min: 5,
              max: 60,
              divisions: 11, // (60-5)/5
              label: _pomodoroDuration.round().toString(),
              onChanged: (double value) {
                setState(() {
                  _pomodoroDuration = value.round();
                });
              },
            ),
            const SizedBox(height: 24),
            // Add other settings UI elements here
            // e.g., for game timer alerts, theme settings, etc.
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
