import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Valori di default
  double malusRatio = 2.0;
  int unauthorizedPlayMalus = 1; // ore
  bool canStudyReduceMalus = true;

  int bonusCompiti = 2;
  int bonusFaccende = 1;
  int bonusLettura = 1;

  int maxGameHoursPerDay = 2;
  int pomodoroWorkMinutes = 25;
  int pomodoroBreakMinutes = 5;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      malusRatio = prefs.getDouble('malusRatio') ?? malusRatio;
      unauthorizedPlayMalus = prefs.getInt('unauthorizedPlayMalus') ?? unauthorizedPlayMalus;
      canStudyReduceMalus = prefs.getBool('canStudyReduceMalus') ?? canStudyReduceMalus;

      bonusCompiti = prefs.getInt('bonusCompiti') ?? bonusCompiti;
      bonusFaccende = prefs.getInt('bonusFaccende') ?? bonusFaccende;
      bonusLettura = prefs.getInt('bonusLettura') ?? bonusLettura;

      maxGameHoursPerDay = prefs.getInt('maxGameHoursPerDay') ?? maxGameHoursPerDay;
      pomodoroWorkMinutes = prefs.getInt('pomodoroWorkMinutes') ?? pomodoroWorkMinutes;
      pomodoroBreakMinutes = prefs.getInt('pomodoroBreakMinutes') ?? pomodoroBreakMinutes;

      isLoading = false;
    });
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('malusRatio', malusRatio);
    await prefs.setInt('unauthorizedPlayMalus', unauthorizedPlayMalus);
    await prefs.setBool('canStudyReduceMalus', canStudyReduceMalus);

    await prefs.setInt('bonusCompiti', bonusCompiti);
    await prefs.setInt('bonusFaccende', bonusFaccende);
    await prefs.setInt('bonusLettura', bonusLettura);

    await prefs.setInt('maxGameHoursPerDay', maxGameHoursPerDay);
    await prefs.setInt('pomodoroWorkMinutes', pomodoroWorkMinutes);
    await prefs.setInt('pomodoroBreakMinutes', pomodoroBreakMinutes);
  }

  Widget buildNumberInput({
    required String label,
    required num value,
    required Function(num) onChanged,
    double min = 0,
    double max = 100,
    int decimals = 0,
  }) {
    final controller = TextEditingController(text: value.toString());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        onSubmitted: (text) {
          final parsed = decimals > 0 ? double.tryParse(text) : int.tryParse(text);
          if (parsed != null && parsed >= min && parsed <= max) {
            onChanged(parsed);
            saveSettings();
          } else {
            controller.text = value.toString();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text('Impostazioni')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Malus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            buildNumberInput(
              label: 'Malus Ratio (ore gioco extra per 1 ora da scontare)',
              value: malusRatio,
              decimals: 1,
              onChanged: (val) => setState(() => malusRatio = val.toDouble()),
            ),
            buildNumberInput(
              label: 'Malus per gioco a gate chiuso (ore)',
              value: unauthorizedPlayMalus,
              onChanged: (val) => setState(() => unauthorizedPlayMalus = val.toInt()),
            ),
            SwitchListTile(
              title: Text('Studio può scalare malus solo se non gioco quel giorno'),
              value: canStudyReduceMalus,
              onChanged: (val) {
                setState(() => canStudyReduceMalus = val);
                saveSettings();
              },
            ),
            Divider(height: 32),
            Text('Bonus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            buildNumberInput(
              label: 'Bonus compiti',
              value: bonusCompiti,
              onChanged: (val) => setState(() => bonusCompiti = val.toInt()),
            ),
            buildNumberInput(
              label: 'Bonus faccende',
              value: bonusFaccende,
              onChanged: (val) => setState(() => bonusFaccende = val.toInt()),
            ),
            buildNumberInput(
              label: 'Bonus lettura',
              value: bonusLettura,
              onChanged: (val) => setState(() => bonusLettura = val.toInt()),
            ),
            Divider(height: 32),
            Text('Preset', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            buildNumberInput(
              label: 'Ore massimo gioco per giorno',
              value: maxGameHoursPerDay,
              onChanged: (val) => setState(() => maxGameHoursPerDay = val.toInt()),
            ),
            buildNumberInput(
              label: 'Durata Pomodoro - lavoro (minuti)',
              value: pomodoroWorkMinutes,
              onChanged: (val) => setState(() => pomodoroWorkMinutes = val.toInt()),
            ),
            buildNumberInput(
              label: 'Durata Pomodoro - pausa (minuti)',
              value: pomodoroBreakMinutes,
              onChanged: (val) => setState(() => pomodoroBreakMinutes = val.toInt()),
            ),
          ],
        ),
      ),
    );
  }
}
