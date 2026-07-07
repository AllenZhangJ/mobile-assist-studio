import 'dart:io';

import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

// V4 终验摘要读取回归。
// 只覆盖脱敏摘要，不读取截图或执行真实设备动作。
void main() {
  test(
    'local v4 acceptance reader parses latest final report summary',
    () async {
      final temp = await Directory.systemTemp.createTemp('v4_acceptance_test_');
      addTearDown(() async {
        if (temp.existsSync()) await temp.delete(recursive: true);
      });
      await File(
        '${temp.path}/FINAL_ACCEPTANCE_2026-01-01T00-00-00Z.json',
      ).writeAsString(_acceptanceJson(git: 'old', androidRuns: 1));
      await File(
        '${temp.path}/FINAL_ACCEPTANCE_2026-01-02T00-00-00Z.json',
      ).writeAsString(_acceptanceJson(git: '1234567890abcdef', androidRuns: 0));

      final reader = LocalV4AcceptanceSummaryReader(directory: temp);
      final summary = await reader.readLatest();

      expect(summary.hasReport, isTrue);
      expect(summary.auditOk, isTrue);
      expect(summary.complete, isFalse);
      expect(summary.statusLabel, '最终验收未完成');
      expect(summary.gitRevision, '12345678');
      expect(summary.androidStatus, '未就绪');
      expect(summary.androidDetail, '可用 0，未授权 0，离线 0');
      expect(summary.screenshots, 1);
      expect(summary.iosRuns, 1);
      expect(summary.androidRuns, 0);
      expect(summary.fullSmokeReports, 7);
      expect(summary.latestFullSmokeLabel, '前置检查阻断');
      expect(summary.primaryNextStep, startsWith('Android：'));
      expect(summary.hasAndroidRun, isFalse);
    },
  );

  test('runtime controller refreshes v4 acceptance summary safely', () async {
    final temp = await Directory.systemTemp.createTemp('v4_acceptance_test_');
    addTearDown(() async {
      if (temp.existsSync()) await temp.delete(recursive: true);
    });
    await File(
      '${temp.path}/FINAL_ACCEPTANCE_2026-01-02T00-00-00Z.json',
    ).writeAsString(_acceptanceJson(git: 'abcdef12', androidRuns: 0));

    final controller = StudioRuntimeController(
      v4AcceptanceSummaryReader: LocalV4AcceptanceSummaryReader(
        directory: temp,
      ),
    );

    await controller.refreshV4AcceptanceSummary();

    expect(controller.snapshot.v4AcceptanceSummary.hasReport, isTrue);
    expect(controller.snapshot.v4AcceptanceSummary.androidRuns, 0);
    expect(controller.snapshot.v4AcceptanceSummary.failures, hasLength(1));
  });

  test('local v4 acceptance reader skips broken reports', () async {
    final temp = await Directory.systemTemp.createTemp('v4_acceptance_test_');
    addTearDown(() async {
      if (temp.existsSync()) await temp.delete(recursive: true);
    });
    await File(
      '${temp.path}/FINAL_ACCEPTANCE_2026-01-01T00-00-00Z.json',
    ).writeAsString(_acceptanceJson(git: 'good', androidRuns: 1));
    await File(
      '${temp.path}/FINAL_ACCEPTANCE_2026-01-02T00-00-00Z.json',
    ).writeAsString('{broken');

    final summary = await LocalV4AcceptanceSummaryReader(
      directory: temp,
    ).readLatest();

    expect(summary.hasReport, isTrue);
    expect(summary.gitRevision, 'good');
    expect(summary.androidRuns, 1);
  });
}

String _acceptanceJson({required String git, required int androidRuns}) {
  return '''
{
  "schemaVersion": 1,
  "kind": "v4FinalAcceptance",
  "timestamp": "2026-01-02T00:00:00.000000Z",
  "git": "$git",
  "completion": {
    "auditOk": true,
    "complete": false,
    "label": "最终验收未完成",
    "failures": ["缺少 Android 平台 smoke run。"]
  },
  "evidence": {
    "readiness": {
      "localState": {
        "androidDevice": {
          "status": "未就绪",
          "detail": "可用 0，未授权 0，离线 0"
        }
      }
    },
    "archive": {
      "counts": {
        "screenshots": 1,
        "iosRuns": 1,
        "androidRuns": $androidRuns,
        "fullSmokeReports": 7
      },
      "latestFullSmoke": {
        "label": "前置检查阻断"
      }
    }
  },
  "nextSteps": [
    "Android：连接一台已开启 USB 调试的手机，运行 `npm run v4:android-smoke:full`。"
  ]
}
''';
}
