import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrcpygui/models/adb_devices.dart';
import 'package:scrcpygui/models/device_info_model.dart';
import 'package:scrcpygui/models/scrcpy_related/scrcpy_info/scrcpy_display.dart';
import 'package:scrcpygui/providers/device_info_provider.dart';
import 'package:scrcpygui/providers/version_provider.dart';
import 'package:scrcpygui/utils/const.dart';
import 'package:scrcpygui/utils/scrcpy_command.dart';

/// Builds real launch arguments with the selected binary version and config.
Future<List<String>> _buildCommand(
  WidgetTester tester, {
  String version = '4.1',
  bool virtualDisplay = false,
  bool stayAwake = false,
  String additionalFlags = '',
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(scrcpyVersionProvider.notifier).state = version;
  container.read(infoProvider.notifier).setDevicesInfo([
    DeviceInfo(
      serialNo: 'phone',
      deviceName: 'Phone',
      buildVersion: '16',
      cameras: [],
      displays: [ScrcpyDisplay(id: '0', resolution: '1440x3200')],
      videoEncoders: [],
      audioEncoder: [],
      appList: [],
    ),
  ]);
  final device = AdbDevices(
    id: '192.0.2.1:5555',
    modelName: 'Phone',
    serialNo: 'phone',
    status: true,
  );
  final config = defaultMirror.copyWith(
    videoOptions: defaultMirror.videoOptions.copyWith(
      displayId: virtualDisplay ? 'new' : '0',
    ),
    deviceOptions: defaultMirror.deviceOptions.copyWith(stayAwake: stayAwake),
    additionalFlags: additionalFlags,
  );
  var command = <String>[];
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: Consumer(builder: (context, ref, child) {
      command = ScrcpyCommand.buildCommand(ref, config, device);
      return const SizedBox();
    }),
  ));
  return command;
}

/// Checks inactivity prevention without breaking older binaries or main screens.
void main() {
  for (final version in ['4.0', '4.1']) {
    testWidgets('virtual displays stay active on scrcpy $version',
        (tester) async {
      final command = await _buildCommand(
        tester,
        version: version,
        virtualDisplay: true,
      );

      expect(command, contains('--new-display'));
      expect(command, contains('--keep-active'));
    });
  }

  for (final version in ['3.2', '3.3.4']) {
    testWidgets('scrcpy $version keeps compatible sleep arguments',
        (tester) async {
      final command = await _buildCommand(
        tester,
        version: version,
        virtualDisplay: true,
        stayAwake: true,
      );

      expect(command, contains('--stay-awake'));
      expect(command, isNot(contains('--keep-active')));
    });
  }

  testWidgets('ordinary mirroring retains its default sleep behavior',
      (tester) async {
    final command = await _buildCommand(tester);

    expect(command, isNot(contains('--keep-active')));
  });

  testWidgets('stay awake also works without charging on supported versions',
      (tester) async {
    final command = await _buildCommand(tester, stayAwake: true);

    expect(command, contains('--stay-awake'));
    expect(command, contains('--keep-active'));
  });

  testWidgets('an explicit keep-active flag is not duplicated', (tester) async {
    final command = await _buildCommand(
      tester,
      virtualDisplay: true,
      additionalFlags: '--keep-active',
    );

    expect(command.where((flag) => flag == '--keep-active'), hasLength(1));
  });
}
