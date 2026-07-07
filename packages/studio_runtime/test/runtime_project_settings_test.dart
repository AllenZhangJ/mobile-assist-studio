// ignore_for_file: unused_import, unnecessary_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime 本机设置和证据保留策略测试。
// 用例验证隐私设置不可降级，并能驱动证据清理。
void main() {
  // 验证本机设置 store 能保存和恢复工作站设置。
  test('local settings store writes and reads workstation settings', () async {
    final directory = await Directory.systemTemp.createTemp('settings-store-');
    final file = File('${directory.path}/settings/studio.settings.json');
    final store = LocalStudioSettingsStore(file: file);
    final settings = StudioSettings(
      hideDeviceIdentifier: true,
      hideRawWebDriverPayload: true,
      revealScreenshotsByDefault: false,
      enablePythonVision: true,
      evidenceMaxRuns: 7,
      evidenceMaxAgeDays: 9,
    );

    await store.saveSettings(settings);
    final restored = store.loadSettingsSync();
    await directory.delete(recursive: true);

    expect(restored.toJson(), settings.toJson());
  });

  // 验证隐私边界在构造、反序列化和复制时都不能关闭。
  test('studio settings enforce hard privacy boundaries', () async {
    final settings = StudioSettings(
      hideDeviceIdentifier: false,
      hideRawWebDriverPayload: false,
      revealScreenshotsByDefault: true,
      enablePythonVision: true,
      evidenceMaxRuns: 999,
      evidenceMaxAgeDays: 999,
    );
    final fromJson = StudioSettings.fromJson({
      'hideDeviceIdentifier': false,
      'hideRawWebDriverPayload': false,
      'revealScreenshotsByDefault': true,
      'enablePythonVision': true,
      'evidenceMaxRuns': -5,
      'evidenceMaxAgeDays': -9,
    });
    final copied = StudioSettings.defaults.copyWith(
      hideDeviceIdentifier: false,
      hideRawWebDriverPayload: false,
      revealScreenshotsByDefault: true,
      enablePythonVision: true,
    );

    expect(settings.hideDeviceIdentifier, isTrue);
    expect(settings.hideRawWebDriverPayload, isTrue);
    expect(settings.revealScreenshotsByDefault, isTrue);
    expect(settings.enablePythonVision, isTrue);
    expect(settings.evidenceMaxRuns, 200);
    expect(settings.evidenceMaxAgeDays, 90);
    expect(fromJson.hideDeviceIdentifier, isTrue);
    expect(fromJson.hideRawWebDriverPayload, isTrue);
    expect(fromJson.revealScreenshotsByDefault, isTrue);
    expect(fromJson.enablePythonVision, isTrue);
    expect(fromJson.evidenceMaxRuns, 1);
    expect(fromJson.evidenceMaxAgeDays, 1);
    expect(copied.hideDeviceIdentifier, isTrue);
    expect(copied.hideRawWebDriverPayload, isTrue);
    expect(copied.revealScreenshotsByDefault, isTrue);
    expect(copied.enablePythonVision, isTrue);
  });

  // 验证设置更新会同步证据保留数量。
  test(
    'runtime controller updates settings and applies evidence retention',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'runtime-settings-',
      );
      final evidenceStore = LocalRunEvidenceStore(
        rootDirectory: Directory('${directory.path}/recordings'),
        maxRuns: 3,
      );
      await evidenceStore.startRun(
        workflowName: 'Run 1',
        loops: 1,
        startedAt: DateTime.utc(2026, 1, 1),
      );
      await evidenceStore.startRun(
        workflowName: 'Run 2',
        loops: 1,
        startedAt: DateTime.utc(2026, 1, 2),
      );
      await evidenceStore.startRun(
        workflowName: 'Run 3',
        loops: 1,
        startedAt: DateTime.utc(2026, 1, 3),
      );
      final settingsFile = File(
        '${directory.path}/settings/studio.settings.json',
      );
      final settingsStore = LocalStudioSettingsStore(file: settingsFile);
      final controller = StudioRuntimeController(
        evidenceStore: evidenceStore,
        settingsStore: settingsStore,
        settings: StudioSettings(evidenceMaxRuns: 3),
      );

      final updated = await controller.updateSettings(
        StudioSettings(evidenceMaxRuns: 2, enablePythonVision: true),
      );
      await controller.dispose();

      final runDirectories = await Directory('${directory.path}/recordings')
          .list()
          .where((entity) => entity is Directory)
          .cast<Directory>()
          .map(
            (directory) => directory.uri.pathSegments
                .where((segment) => segment.isNotEmpty)
                .last,
          )
          .toList();
      final restored = settingsStore.loadSettingsSync();
      await directory.delete(recursive: true);

      expect(updated, isTrue);
      expect(restored.evidenceMaxRuns, 2);
      expect(restored.enablePythonVision, isTrue);
      expect(controller.snapshot.settings.evidenceMaxRuns, 2);
      expect(controller.snapshot.settings.enablePythonVision, isTrue);
      expect(runDirectories, hasLength(2));
      expect(runDirectories, isNot(contains('run-2026-01-01T00-00-00-000Z')));
    },
  );

  // 验证证据按最大保留天数滚动清理。
  test('runtime controller applies evidence age retention', () async {
    final directory = await Directory.systemTemp.createTemp(
      'runtime-settings-age-',
    );
    final evidenceStore = LocalRunEvidenceStore(
      rootDirectory: Directory('${directory.path}/recordings'),
      maxRuns: 10,
      maxAgeDays: 90,
    );
    await evidenceStore.startRun(
      workflowName: '旧记录',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 1),
    );
    await evidenceStore.startRun(
      workflowName: '近记录',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 10),
    );
    await evidenceStore.startRun(
      workflowName: '新记录',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 11),
    );
    final settingsStore = LocalStudioSettingsStore(
      file: File('${directory.path}/settings/studio.settings.json'),
    );
    final controller = StudioRuntimeController(
      evidenceStore: evidenceStore,
      settingsStore: settingsStore,
      settings: StudioSettings(evidenceMaxRuns: 10, evidenceMaxAgeDays: 90),
    );

    final updated = await controller.updateSettings(
      StudioSettings(evidenceMaxRuns: 10, evidenceMaxAgeDays: 3),
    );
    await controller.dispose();

    final runDirectories = await Directory('${directory.path}/recordings')
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .map(
          (directory) => directory.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last,
        )
        .toList();
    final restored = settingsStore.loadSettingsSync();
    await directory.delete(recursive: true);

    expect(updated, isTrue);
    expect(restored.evidenceMaxAgeDays, 3);
    expect(controller.snapshot.settings.evidenceMaxAgeDays, 3);
    expect(runDirectories, hasLength(2));
    expect(runDirectories, isNot(contains('run-2026-01-01T00-00-00-000Z')));
    expect(runDirectories, contains('run-2026-01-10T00-00-00-000Z'));
    expect(runDirectories, contains('run-2026-01-11T00-00-00-000Z'));
  });
}
