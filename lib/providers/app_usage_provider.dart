import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A launch is scoped to the device serial, including USB/Wi-Fi connections.
typedef AppLaunch = ({String device, String package, int time});

/// Persists launches for a rolling 30-day window.
final appUsageProvider =
    AsyncNotifierProvider<AppUsageNotifier, List<AppLaunch>>(
        AppUsageNotifier.new);

/// Stores launch history independently of app names and launcher filters.
class AppUsageNotifier extends AsyncNotifier<List<AppLaunch>> {
  static const _key = 'app-launch-history';
  late SharedPreferences _prefs;

  /// Loads saved launches; malformed storage is surfaced as an error.
  @override
  Future<List<AppLaunch>> build() async {
    _prefs = await SharedPreferences.getInstance();
    final json = jsonDecode(_prefs.getString(_key) ?? '[]') as List;
    final launches = json
        .map((entry) => (
              device: entry['device'] as String,
              package: entry['package'] as String,
              time: entry['time'] as int,
            ))
        .toList();
    final timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state.hasValue) state = AsyncData(_recent(state.requireValue));
    });
    ref.onDispose(timer.cancel);
    return _recent(launches);
  }

  /// Drops expired events, also when the page stays open across the cutoff.
  List<AppLaunch> _recent(List<AppLaunch> launches) {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    return launches.where((launch) => launch.time > cutoff).toList();
  }

  /// Records one dispatched launch after the scrcpy process has been created.
  Future<void> record(String device, String package) async {
    await future;
    final launches = [
      ..._recent(state.requireValue),
      (
        device: device,
        package: package,
        time: DateTime.now().millisecondsSinceEpoch
      ),
    ];
    state = AsyncData(launches);
    final saved = await _prefs.setString(
        _key,
        jsonEncode([
          for (final launch in launches)
            {
              'device': launch.device,
              'package': launch.package,
              'time': launch.time
            },
        ]));
    if (!saved) throw StateError('Unable to save app launch history');
  }
}
