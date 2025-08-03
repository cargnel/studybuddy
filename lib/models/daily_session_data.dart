// models/daily_session_data.dart

class DailySessionData {
  final String date;
  final int readingTime;
  final int homeworkTime;
  final int totalStudyTime;
  final bool gateUnlocked;

  final bool bonusEligible;
  final int faccendeDone;
  final int bonusMinutesGenerated;

  final int bonusConversionStep;
  final double bonusConversionRatio;

  final int studyTimeUsedToPayMalus;

  final int malusFromPreviousDay;
  final int malusPaidToday;
  final int malusGenerated;
  final int malusRemaining;

  final bool gameUnlocked;
  final int gameTimeUsed;
  final int gameTimeAllowed;
  final int gameOveruse;
  final int gameOveruseMalusGenerated;

  final List<Map<String, String>> activityLog;

  DailySessionData({
    required this.date,
    required this.readingTime,
    required this.homeworkTime,
    required this.totalStudyTime,
    required this.gateUnlocked,
    required this.bonusEligible,
    required this.faccendeDone,
    required this.bonusMinutesGenerated,
    required this.bonusConversionStep,
    required this.bonusConversionRatio,
    required this.studyTimeUsedToPayMalus,
    required this.malusFromPreviousDay,
    required this.malusPaidToday,
    required this.malusGenerated,
    required this.malusRemaining,
    required this.gameUnlocked,
    required this.gameTimeUsed,
    required this.gameTimeAllowed,
    required this.gameOveruse,
    required this.gameOveruseMalusGenerated,
    required this.activityLog,
  });

  Map<String, dynamic> toJson() => {
    "date": date,
    "readingTime": readingTime,
    "homeworkTime": homeworkTime,
    "totalStudyTime": totalStudyTime,
    "gateUnlocked": gateUnlocked,
    "bonusEligible": bonusEligible,
    "faccendeDone": faccendeDone,
    "bonusMinutesGenerated": bonusMinutesGenerated,
    "bonusConversionStep": bonusConversionStep,
    "bonusConversionRatio": bonusConversionRatio,
    "studyTimeUsedToPayMalus": studyTimeUsedToPayMalus,
    "malusFromPreviousDay": malusFromPreviousDay,
    "malusPaidToday": malusPaidToday,
    "malusGenerated": malusGenerated,
    "malusRemaining": malusRemaining,
    "gameUnlocked": gameUnlocked,
    "gameTimeUsed": gameTimeUsed,
    "gameTimeAllowed": gameTimeAllowed,
    "gameOveruse": gameOveruse,
    "gameOveruseMalusGenerated": gameOveruseMalusGenerated,
    "activityLog": activityLog,
  };

  factory DailySessionData.fromJson(Map<String, dynamic> json) {
    return DailySessionData(
      date: json['date'],
      readingTime: json['readingTime'],
      homeworkTime: json['homeworkTime'],
      totalStudyTime: json['totalStudyTime'],
      gateUnlocked: json['gateUnlocked'],
      bonusEligible: json['bonusEligible'],
      faccendeDone: json['faccendeDone'],
      bonusMinutesGenerated: json['bonusMinutesGenerated'],
      bonusConversionStep: json['bonusConversionStep'],
      bonusConversionRatio: (json['bonusConversionRatio'] as num).toDouble(),
      studyTimeUsedToPayMalus: json['studyTimeUsedToPayMalus'],
      malusFromPreviousDay: json['malusFromPreviousDay'],
      malusPaidToday: json['malusPaidToday'],
      malusGenerated: json['malusGenerated'],
      malusRemaining: json['malusRemaining'],
      gameUnlocked: json['gameUnlocked'],
      gameTimeUsed: json['gameTimeUsed'],
      gameTimeAllowed: json['gameTimeAllowed'],
      gameOveruse: json['gameOveruse'],
      gameOveruseMalusGenerated: json['gameOveruseMalusGenerated'],
      activityLog: List<Map<String, String>>.from(
        (json['activityLog'] ?? []).map((entry) => Map<String, String>.from(entry)),
      ),
    );
  }
}
