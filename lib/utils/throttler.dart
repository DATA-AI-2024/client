import 'dart:async';
import 'dart:ui';

class Throttler {
  Throttler({
    this.throttleGapInMillis = 1000,
    this.runLastAttemptedAction = false,
  });

  final int throttleGapInMillis;

  /// After [throttleGapInMillis], run the last action that was attempted to be
  /// added before [throttleGapInMillis] expired and thus was supposed to be dropped.
  final bool runLastAttemptedAction;

  int? lastActionTime;

  VoidCallback? lastAttemptedAction;

  late final runLastAttemptedActionDuration =
      Duration(milliseconds: throttleGapInMillis);

  void run(VoidCallback action) {
    final now = DateTime.now();

    if (lastActionTime == null ||
        now.millisecondsSinceEpoch - lastActionTime! >= throttleGapInMillis) {
      action();
      lastActionTime = now.millisecondsSinceEpoch;
      if (runLastAttemptedAction) {
        Timer(runLastAttemptedActionDuration, () {
          if (lastAttemptedAction != null) {
            run(lastAttemptedAction!);
          }
        });
      }
    } else {
      lastAttemptedAction = action;
    }
  }
}
