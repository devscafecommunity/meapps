import 'package:meremind/services/reminder_notifier.dart';

/// Records what would be scheduled on the device.
class FakeNotifier implements ReminderNotifier {
  FakeNotifier({this.fail = false});

  /// Throw on every call, like a platform without permission.
  final bool fail;
  bool initialized = false;
  final scheduled = <String, DateTime>{};
  final titles = <String, String>{};

  void _check() {
    if (fail) throw StateError('notifications unavailable');
  }

  @override
  Future<void> init() async {
    _check();
    initialized = true;
  }

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime when,
  }) async {
    _check();
    scheduled[id] = when;
    titles[id] = title;
  }

  @override
  Future<void> cancel(String id) async {
    _check();
    scheduled.remove(id);
    titles.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    _check();
    scheduled.clear();
    titles.clear();
  }
}
