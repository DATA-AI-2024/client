import 'package:daejeon_taxi/packages/index.dart';

class Throttler {
  Throttler({this.throttleGapInMillis = 1000});

  final int throttleGapInMillis;

  int? lastActionTime;

  void run(VoidCallback action) {
    if (lastActionTime == null) {
      action();
      lastActionTime = DateTime.now().millisecondsSinceEpoch;
    } else {
      if (DateTime.now().millisecondsSinceEpoch - lastActionTime! >=
          throttleGapInMillis) {
        action();
        lastActionTime = DateTime.now().millisecondsSinceEpoch;
      }
    }
  }
}
