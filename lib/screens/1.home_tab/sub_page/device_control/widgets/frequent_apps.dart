import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../../models/adb_devices.dart';
import '../../../../../providers/app_usage_provider.dart';
import '../../../../../providers/device_info_provider.dart';
import '../../../../../widgets/custom_ui/pg_section_card.dart';
import 'app_grid.dart';
import 'app_grid_icon.dart';

/// Keeps the app list and its recent usage shortcuts next to each other.
class AppLauncher extends StatelessWidget {
  const AppLauncher({super.key, required this.device, this.scrollController});

  final AdbDevices device;
  final ScrollController? scrollController;

  /// Gives narrow windows horizontal scrolling instead of shrinking controls.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: constraints.maxWidth < 570 ? 570 : constraints.maxWidth,
            height: constraints.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Expanded(
                    child: AppGrid(
                        device: device, scrollController: scrollController)),
                SizedBox(width: 132, child: _FrequentApps(device: device)),
              ],
            ),
          ),
        ),
      );
}

/// Reuses launcher tiles so pinned configurations and gestures stay consistent.
class _FrequentApps extends ConsumerWidget {
  const _FrequentApps({required this.device});

  final AdbDevices device;

  /// Ranks installed apps by count, breaking ties by the latest launch.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(appUsageProvider);
    final counts = <String, int>{};
    final latest = <String, int>{};
    for (final launch in usage.valueOrNull ?? <AppLaunch>[]) {
      if (launch.device != device.serialNo) continue;
      counts.update(launch.package, (count) => count + 1, ifAbsent: () => 1);
      latest.update(
          launch.package, (time) => time > launch.time ? time : launch.time,
          ifAbsent: () => launch.time);
    }
    final apps = ref
        .watch(infoProvider)
        .where((info) => info.serialNo == device.serialNo)
        .expand((info) => info.appList)
        .where((app) => counts.containsKey(app.packageName))
        .toList()
      ..sort((a, b) {
        final count = counts[b.packageName]!.compareTo(counts[a.packageName]!);
        if (count != 0) return count;
        final time = latest[b.packageName]!.compareTo(latest[a.packageName]!);
        return time != 0 ? time : a.packageName.compareTo(b.packageName);
      });
    final topApps = apps.take(10).toList();
    return PgSectionCardNoScroll(
      label: '常用应用',
      expandContent: true,
      content: Column(
        spacing: 8,
        children: [
          const Text('最近 30 天').small.muted,
          Expanded(
              child: usage.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('记录读取失败').small),
            data: (_) => topApps.isEmpty
                ? Center(child: Text('暂无启动记录').small.muted)
                : ListView.separated(
                    itemCount: topApps.length,
                    separatorBuilder: (_, __) => const Gap(8),
                    itemBuilder: (context, index) {
                      final app = topApps[index];
                      return Column(
                        key: ValueKey(app.packageName),
                        children: [
                          SizedBox(
                              height: 88,
                              width: double.infinity,
                              child: AppGridIcon(app: app, device: device)),
                          Text('${counts[app.packageName]} 次').small.muted,
                        ],
                      );
                    },
                  ),
          )),
        ],
      ),
    );
  }
}
