import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrcpygui/providers/app_usage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Checks rolling retention, concurrent launches and persistence across restarts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retains recent per-device launches and persists concurrent updates',
      () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'app-launch-history': jsonEncode([
        {
          'device': 'phone-a',
          'package': 'expired',
          'time': now.subtract(const Duration(days: 31)).millisecondsSinceEpoch
        },
        {
          'device': 'phone-b',
          'package': 'app',
          'time': now.subtract(const Duration(days: 29)).millisecondsSinceEpoch
        },
      ]),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final loaded = await container.read(appUsageProvider.future);
    expect(loaded.single.device, 'phone-b');
    final notifier = container.read(appUsageProvider.notifier);
    await Future.wait([
      notifier.record('phone-a', 'app'),
      notifier.record('phone-a', 'app'),
      notifier.record('phone-a', 'another'),
    ]);

    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    final saved = await restarted.read(appUsageProvider.future);
    expect(saved, hasLength(4));
    expect(saved.where((e) => e.device == 'phone-a' && e.package == 'app'),
        hasLength(2));
    expect(saved.where((e) => e.device == 'phone-b'), hasLength(1));
    expect(saved.any((e) => e.package == 'expired'), isFalse);
  });

  test('corrupt history is reported instead of silently overwritten', () async {
    SharedPreferences.setMockInitialValues({'app-launch-history': 'invalid'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await expectLater(
        container.read(appUsageProvider.future), throwsFormatException);
  });
}
