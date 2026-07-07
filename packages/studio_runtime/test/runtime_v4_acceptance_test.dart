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
      expect(summary.gitBranch, 'main');
      expect(summary.gitDirty, isFalse);
      expect(summary.gitWorktreeLabel, '干净');
      expect(summary.gitRemoteSynced, isTrue);
      expect(summary.gitAhead, 0);
      expect(summary.gitBehind, 0);
      expect(summary.gitRemoteLabel, '已同步');
      expect(summary.iosStatus, '未就绪');
      expect(summary.iosDetail, '可用 0，不可用 1');
      expect(summary.androidStatus, '未就绪');
      expect(summary.androidDetail, '可用 0，未授权 0，离线 0');
      expect(summary.screenshots, 1);
      expect(summary.iosRuns, 1);
      expect(summary.androidRuns, 0);
      expect(summary.fullSmokeReports, 7);
      expect(summary.latestFullSmokeLabel, '前置检查阻断');
      expect(summary.primaryNextStep, startsWith('Android：'));
      expect(summary.hasAndroidRun, isFalse);
      expect(summary.totalBatchCount, 9);
      expect(summary.completedBatchCount, 8);
      expect(summary.batchProgressLabel, '8/9');
      expect(summary.firstPendingBatch?.name, 'Batch 2 双平台 smoke');
      expect(summary.gateGaps, hasLength(2));
      expect(summary.gateGaps.first.title, 'Android smoke');
      expect(summary.gateGaps.first.command, 'npm run v4:android-smoke:full');
      expect(summary.fieldChecklist, hasLength(3));
      expect(
        summary.fieldChecklist.map((item) => item.command),
        containsAll(<String?>[
          'npm run v4:android-smoke:full',
          'npm run v4:smoke:full:password-prompt',
          'npm run v4:acceptance-final',
        ]),
      );
    },
  );

  test('local v4 acceptance reader keeps code-state gate gaps', () async {
    final temp = await Directory.systemTemp.createTemp('v4_acceptance_test_');
    addTearDown(() async {
      if (temp.existsSync()) await temp.delete(recursive: true);
    });
    await File(
      '${temp.path}/FINAL_ACCEPTANCE_2026-01-02T00-00-00Z.json',
    ).writeAsString(_acceptanceJsonWithCodeGate());

    final summary = await LocalV4AcceptanceSummaryReader(
      directory: temp,
    ).readLatest();

    expect(summary.hasReport, isTrue);
    expect(summary.gitDirty, isTrue);
    expect(summary.gitWorktreeLabel, '有改动');
    expect(summary.gitRemoteSynced, isFalse);
    expect(summary.gitAhead, 1);
    expect(summary.gitBehind, 0);
    expect(summary.gitRemoteLabel, '未推');
    expect(summary.gateGaps.map((gap) => gap.title), <String>['代码工作区', '远端同步']);
    expect(summary.gateGaps.every((gap) => gap.command == null), isTrue);
    expect(summary.fieldChecklist.map((item) => item.title), <String>[
      '清代码',
      '推远端',
    ]);
    expect(
      summary.fieldChecklist.every((item) => item.command == null),
      isTrue,
    );
    expect(summary.primaryNextStep, startsWith('代码：'));
  });

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
    expect(summary.gitDirty, isFalse);
    expect(summary.gitRemoteSynced, isTrue);
    expect(summary.androidRuns, 1);
  });

  test('local v4 acceptance reader redacts visible report text', () async {
    final temp = await Directory.systemTemp.createTemp('v4_acceptance_test_');
    addTearDown(() async {
      if (temp.existsSync()) await temp.delete(recursive: true);
    });
    await File(
      '${temp.path}/FINAL_ACCEPTANCE_2026-01-02T00-00-00Z.json',
    ).writeAsString(_acceptanceJsonWithSensitiveText());

    final summary = await LocalV4AcceptanceSummaryReader(
      directory: temp,
    ).readLatest();
    final visibleText = [
      summary.statusLabel,
      summary.gitBranch ?? '',
      summary.gitWorktreeLabel,
      summary.gitRemoteLabel,
      summary.iosStatus,
      summary.iosDetail,
      summary.androidStatus,
      summary.androidDetail,
      summary.latestFullSmokeLabel,
      ...summary.failures,
      ...summary.nextSteps,
      for (final gap in summary.gateGaps) ...[
        gap.title,
        gap.current,
        gap.requiredText,
        if (gap.command != null) gap.command!,
      ],
      for (final item in summary.fieldChecklist) ...[
        item.title,
        item.proof,
        if (item.command != null) item.command!,
      ],
      for (final batch in summary.batches) ...[
        batch.name,
        batch.status,
        batch.evidence,
      ],
    ].join(' ');

    expect(visibleText, contains('[本机路径]'));
    expect(visibleText, contains('[本机地址]'));
    expect(visibleText, contains('[标识]'));
    expect(visibleText, contains('[命令已过滤]'));
    expect(summary.gateGaps.single.command, isNull);
    expect(summary.fieldChecklist.single.command, isNull);
    expect(visibleText, isNot(contains('/Users/example')));
    expect(visibleText, isNot(contains('00008110-000A01E03C3B801E')));
    expect(visibleText, isNot(contains('http://127.0.0.1:4723')));
    expect(visibleText, isNot(contains('rm -rf')));
    expect(visibleText, isNot(contains('osascript')));
  });
}

String _acceptanceJson({required String git, required int androidRuns}) {
  return '''
{
  "schemaVersion": 1,
  "kind": "v4FinalAcceptance",
  "timestamp": "2026-01-02T00:00:00.000000Z",
  "git": "$git",
  "gitStatus": {
    "revision": "$git",
    "branch": "main",
    "dirty": false,
    "worktree": "干净",
    "upstream": "origin/main",
    "ahead": 0,
    "behind": 0,
    "synced": true,
    "remote": "已同步"
  },
  "completion": {
    "auditOk": true,
    "complete": false,
    "label": "最终验收未完成",
    "failures": ["缺少 Android 平台 smoke run。"]
  },
  "evidence": {
    "readiness": {
      "localState": {
        "iosDevice": {
          "status": "未就绪",
          "detail": "可用 0，不可用 1"
        },
        "androidDevice": {
          "status": "未就绪",
          "detail": "可用 0，未授权 0，离线 0"
        }
      },
      "batches": ${_batchRowsJson()}
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
  ],
  "gateGaps": [
    {
      "title": "Android smoke",
      "current": "缺少 Android 平台 smoke run。",
      "required": "Android 真机 smoke run 留档存在",
      "command": "npm run v4:android-smoke:full"
    },
    {
      "title": "Full smoke",
      "current": "最近 full smoke 尚未完整通过。",
      "required": "最近双平台 full smoke 完整通过",
      "command": "npm run v4:smoke:full:password-prompt"
    }
  ],
  "fieldChecklist": [
    {
      "order": 2,
      "title": "补 Android",
      "command": "npm run v4:android-smoke:full",
      "proof": "只连接一台已允许 USB 调试的 Android 手机。"
    },
    {
      "order": 3,
      "title": "跑全量",
      "command": "npm run v4:smoke:full:password-prompt",
      "proof": "双平台 full smoke 完整通过。"
    },
    {
      "order": 4,
      "title": "做终验",
      "command": "npm run v4:acceptance-final",
      "proof": "终验返回 0。"
    }
  ]
}
''';
}

String _acceptanceJsonWithSensitiveText() {
  return '''
{
  "schemaVersion": 1,
  "kind": "v4FinalAcceptance",
  "timestamp": "2026-01-02T00:00:00.000000Z",
  "git": "abcdef12",
  "gitStatus": {
    "revision": "abcdef12",
    "branch": "/Users/example/project",
    "dirty": true,
    "worktree": "有未提交改动",
    "upstream": "/Users/example/remote",
    "ahead": 2,
    "behind": 1,
    "synced": false,
    "remote": "已分叉"
  },
  "completion": {
    "auditOk": true,
    "complete": false,
    "label": "最终验收未完成 /Users/example/project",
    "failures": [
      "设备 00008110-000A01E03C3B801E 在 http://127.0.0.1:4723/session 失败"
    ]
  },
  "evidence": {
    "readiness": {
      "localState": {
        "iosDevice": {
          "status": "未就绪 /Users/example/status",
          "detail": "路径 /Users/example/project 设备 00008110-000A01E03C3B801E"
        },
        "androidDevice": {
          "status": "未就绪 /Users/example/status",
          "detail": "路径 /Users/example/project 设备 00008110-000A01E03C3B801E"
        }
      },
      "batches": ${_batchRowsJson(sensitive: true)}
    },
    "archive": {
      "counts": {
        "screenshots": 1,
        "iosRuns": 1,
        "androidRuns": 0,
        "fullSmokeReports": 7
      },
      "latestFullSmoke": {
        "label": "前置检查阻断 http://127.0.0.1:4723/status"
      }
    }
  },
  "nextSteps": [
    "打开 /Users/example/project 后处理 00008110-000A01E03C3B801E，并运行 `rm -rf /Users/example/project`"
  ],
  "gateGaps": [
    {
      "title": "iOS smoke /Users/example",
      "current": "设备 00008110-000A01E03C3B801E 在 http://127.0.0.1:4723/session 失败",
      "required": "不要泄露 /Users/example/project",
      "command": "rm -rf /Users/example/project"
    }
  ],
  "fieldChecklist": [
    {
      "order": 1,
      "title": "补 iOS",
      "command": "osascript -e bad",
      "proof": "打开 /Users/example/project 后处理 00008110-000A01E03C3B801E"
    }
  ]
}
''';
}

String _acceptanceJsonWithCodeGate() {
  return '''
{
  "schemaVersion": 1,
  "kind": "v4FinalAcceptance",
  "timestamp": "2026-01-02T00:00:00.000000Z",
  "git": "abcdef12",
  "gitStatus": {
    "revision": "abcdef12",
    "branch": "main",
    "dirty": true,
    "worktree": "有未提交改动",
    "upstream": "origin/main",
    "ahead": 1,
    "behind": 0,
    "synced": false,
    "remote": "未推送"
  },
  "completion": {
    "auditOk": true,
    "complete": false,
    "label": "最终验收未完成",
    "failures": [
      "代码工作区：有未提交改动。",
      "远端同步：未推送。"
    ]
  },
  "evidence": {
    "readiness": {
      "localState": {
        "iosDevice": {
          "status": "可用",
          "detail": "可用 1，不可用 0"
        },
        "androidDevice": {
          "status": "可用",
          "detail": "可用 1，未授权 0，离线 0"
        }
      },
      "batches": ${_batchRowsJson()}
    },
    "archive": {
      "counts": {
        "screenshots": 1,
        "iosRuns": 1,
        "androidRuns": 1,
        "fullSmokeReports": 1
      },
      "latestFullSmoke": {
        "label": "完整通过"
      }
    }
  },
  "nextSteps": [
    "代码：提交或撤销本地改动，保持工作区干净。",
    "远端：推送当前提交，并确认本地与上游同步。"
  ],
  "gateGaps": [
    {
      "title": "代码工作区",
      "current": "有未提交改动",
      "required": "工作区干净，无未提交改动"
    },
    {
      "title": "远端同步",
      "current": "未推送，ahead 1，behind 0",
      "required": "当前提交已推送并与上游同步"
    }
  ],
  "fieldChecklist": [
    {
      "order": 1,
      "title": "清代码",
      "proof": "工作区干净，没有未提交改动。"
    },
    {
      "order": 2,
      "title": "推远端",
      "proof": "当前提交已推送，ahead 0 且 behind 0。"
    }
  ]
}
''';
}

String _batchRowsJson({bool sensitive = false}) {
  final batch2Evidence = sensitive
      ? 'Android 00008110-000A01E03C3B801E 缺少 /Users/example/run'
      : 'iOS 最近 失败，Android 最近 无记录';
  return '''
[
  {"name": "Batch 0 真源治理", "status": "已落地", "evidence": "V4 文档"},
  {"name": "Batch 1 Runtime 基座", "status": "已落地", "evidence": "Runtime tests"},
  {"name": "Batch 2 双平台 smoke", "status": "现场未就绪", "evidence": "$batch2Evidence"},
  {"name": "Batch 3 Inspector", "status": "已落地", "evidence": "Inspector tests"},
  {"name": "Batch 4 Target / Recorder", "status": "已落地", "evidence": "Target tests"},
  {"name": "Batch 5 Vision Core", "status": "已落地", "evidence": "Vision tests"},
  {"name": "Batch 6 Workflow Canvas", "status": "已落地", "evidence": "Canvas tests"},
  {"name": "Batch 7 Evidence / Report", "status": "已落地", "evidence": "Report tests"},
  {"name": "Batch 8 AI / MCP Core", "status": "已落地", "evidence": "AI tests"}
]
''';
}
