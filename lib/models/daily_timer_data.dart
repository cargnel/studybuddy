// lib/models/daily_timer_data.dart

class DailyTimerData {
  int pomodoroSeconds;
  int gameSeconds;

  DailyTimerData({
    required this.pomodoroSeconds,
    required this.gameSeconds,
  });

  factory DailyTimerData.fromJson(Map<String, dynamic> json) {
    return DailyTimerData(
      pomodoroSeconds: json['pomodoroSeconds'] ?? 0,
      gameSeconds: json['gameSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pomodoroSeconds': pomodoroSeconds,
      'gameSeconds': gameSeconds,
    };
  }
}
