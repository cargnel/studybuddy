import 'dart:async';
//import '../services/timer_service.dart';

class TimerController {
  bool running = false;
  bool paused = false;
  int timeLeft = 1500;
  String mode = 'pomodoro';
  Timer? _timer;

  void start(Function onTick) {
    if (running) return;
    running = true;
    paused = false;

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (timeLeft > 0) {
        timeLeft--;
        onTick();
      } else {
        stop();
        onTick();
      }
    });
  }

  void pause() {
    paused = true;
    running = false;
    _timer?.cancel();
  }

  void stop() {
    running = false;
    paused = false;
    _timer?.cancel();
  }

  void cancel() {
    _timer?.cancel();
  }
}
