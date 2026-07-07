import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

import 'support/runtime_test_harness.dart';

// Batch 8 AI / MCP Core 回归测试。
// 用例只验证 Runtime 受控工具，不连接真实设备、不调用外部 AI。
void main() {
  test('ai permission gate blocks unknown and confirms dangerous tools', () {
    const gate = AiToolPermissionGate();

    final unknown = gate.decide(
      const AiToolInvocationRequest(toolId: 'missingTool'),
    );
    final runNeedsConfirm = gate.decide(
      const AiToolInvocationRequest(toolId: 'runWorkflow'),
    );
    final runConfirmed = gate.decide(
      const AiToolInvocationRequest(toolId: 'runWorkflow', userConfirmed: true),
    );

    expect(unknown.status, AiToolDecisionStatus.blocked);
    expect(runNeedsConfirm.status, AiToolDecisionStatus.needsConfirmation);
    expect(runConfirmed.status, AiToolDecisionStatus.allowed);
  });

  test('ai screen summary never exposes screenshot base64', () async {
    final actions = FakeDeviceActionExecutor(
      screenshotBase64: 'raw-base64-image',
      pageSourceXml: '''
<hierarchy>
  <node class="android.widget.FrameLayout" bounds="[0,0][390,844]">
    <node class="android.widget.Button" text="开始" clickable="true" bounds="[20,40][120,88]" />
  </node>
</hierarchy>
''',
    );
    final controller = StudioRuntimeController(
      sessionManager: SequencedSessionManager([
        const WebDriverSession(
          id: 'session-1',
          capabilities: {'platformName': 'Android'},
        ),
      ]),
      deviceActions: actions,
    );

    await controller.connectDevice();
    await controller.inspectCurrentScreen(reason: 'ai-test');
    final result = await controller.invokeAiTool(
      const AiToolInvocationRequest(toolId: 'readCurrentScreenSummary'),
    );
    await controller.dispose();

    expect(result.status, AiToolInvocationStatus.completed);
    expect(result.output['hasScreenshot'], isTrue);
    expect(result.toJson().toString(), isNot(contains('raw-base64-image')));
    expect(controller.snapshot.aiAuditLog, hasLength(1));
  });

  test('ai target and locator suggestions are drafts only', () async {
    final actions = FakeDeviceActionExecutor(
      pageSourceXml: '''
<hierarchy>
  <node class="android.widget.FrameLayout" bounds="[0,0][390,844]">
    <node class="android.widget.Button" text="开始" clickable="true" bounds="[20,40][120,88]" />
  </node>
</hierarchy>
''',
    );
    final controller = StudioRuntimeController(
      sessionManager: SequencedSessionManager([
        const WebDriverSession(
          id: 'session-1',
          capabilities: {'platformName': 'Android'},
        ),
      ]),
      deviceActions: actions,
    );

    await controller.connectDevice();
    await controller.inspectCurrentScreen(reason: 'ai-target');
    final targetResult = await controller.invokeAiTool(
      const AiToolInvocationRequest(toolId: 'suggestTarget'),
    );
    final locatorResult = await controller.invokeAiTool(
      const AiToolInvocationRequest(toolId: 'suggestLocator'),
    );
    await controller.dispose();

    final targets = targetResult.output['targets'] as List<Object?>;
    final locators = locatorResult.output['locators'] as List<Object?>;
    expect(targetResult.output['draftOnly'], isTrue);
    expect(locatorResult.output['draftOnly'], isTrue);
    expect(targets.toString(), contains('label=开始'));
    expect(locators.toString(), contains('label=开始'));
    expect(controller.snapshot.targetLibrary.count, 0);
  });

  test(
    'ai run workflow tool requires confirmation and never starts run',
    () async {
      final controller = StudioRuntimeController();

      final blocked = await controller.invokeAiTool(
        const AiToolInvocationRequest(toolId: 'runWorkflow'),
      );
      final confirmed = await controller.invokeAiTool(
        const AiToolInvocationRequest(
          toolId: 'runWorkflow',
          userConfirmed: true,
        ),
      );
      await controller.dispose();

      expect(blocked.status, AiToolInvocationStatus.needsConfirmation);
      expect(confirmed.status, AiToolInvocationStatus.handoffRequired);
      expect(confirmed.output['handoff'], 'runtime.startRun');
      expect(controller.snapshot.runStatus, RunStatus.idle);
      expect(controller.snapshot.aiAuditLog, hasLength(2));
    },
  );

  test(
    'ai failure explanation and template fix use sanitized local report',
    () async {
      final report = _failedVisualReport();
      final controller = StudioRuntimeController(
        runReportReader: _FakeRunReportReader({'run-1': report}),
      );

      final failure = await controller.invokeAiTool(
        const AiToolInvocationRequest(
          toolId: 'explainRunFailure',
          arguments: {'runId': 'run-1'},
        ),
      );
      final template = await controller.invokeAiTool(
        const AiToolInvocationRequest(
          toolId: 'suggestTemplateFix',
          arguments: {'runId': 'run-1'},
        ),
      );
      await controller.dispose();

      final exported = '${failure.toJson()} ${template.toJson()}';
      expect(failure.status, AiToolInvocationStatus.completed);
      expect(template.status, AiToolInvocationStatus.completed);
      expect(failure.output['nextSteps'].toString(), contains('视觉证据'));
      expect(template.output['suggestions'].toString(), contains('重新截取'));
      expect(exported, isNot(contains('/Users/example')));
      expect(exported, isNot(contains('11112222-3333444455556666')));
    },
  );

  test('ai workflow draft is not persisted into current workflow', () async {
    final controller = StudioRuntimeController();
    final before = controller.snapshot.workflow;

    final result = await controller.invokeAiTool(
      const AiToolInvocationRequest(
        toolId: 'proposeWorkflowDraft',
        arguments: {'targetRef': 'login_button'},
      ),
    );
    await controller.dispose();

    expect(result.status, AiToolInvocationStatus.completed);
    expect(result.output['draftOnly'], isTrue);
    expect(result.output.toString(), contains('login_button'));
    expect(controller.snapshot.workflow.id, before.id);
  });
}

// 构造一个带视觉失败和敏感文本的本地报告。
RunLocalReport _failedVisualReport() {
  final detail = RunDetail(
    entry: RunHistoryEntry(
      runId: 'run-1',
      workflowName: '视觉流程 /Users/example/private',
      status: 'failed',
      loops: 1,
      completedLoops: 0,
      startedAt: DateTime.utc(2026, 1, 1, 1),
      finishedAt: DateTime.utc(2026, 1, 1, 1, 0, 3),
    ),
    events: <RunEvidenceEvent>[
      RunEvidenceEvent(
        type: 'stepStart',
        status: null,
        nodeId: 'visual_1',
        nodeType: 'visualBranch',
        label: '识别登录',
        loopIndex: 0,
        error: null,
        screenshotPath: null,
        at: DateTime.utc(2026, 1, 1, 1, 0, 1),
      ),
      RunEvidenceEvent(
        type: 'stepEnd',
        status: 'failed',
        nodeId: 'visual_1',
        nodeType: 'visualBranch',
        label: '识别登录',
        loopIndex: 0,
        error:
            'match failed at /Users/example/app on 11112222-3333444455556666',
        screenshotPath: 'screenshots/visual.png',
        at: DateTime.utc(2026, 1, 1, 1, 0, 2),
        visualEvidence: const RunVisualEvidence(
          rule: 'target=login_button',
          screenshotAvailable: true,
          confidence: 0.42,
          confidenceThreshold: 0.8,
          result: false,
          action: 'pause',
          reason: 'low confidence at /Users/example/debug.log',
          selectedNext: null,
        ),
      ),
    ],
  );
  return detail.report;
}

// Fake 报告读取器，避免测试访问本地 evidence 文件。
final class _FakeRunReportReader implements RunReportReader {
  const _FakeRunReportReader(this.reports);

  final Map<String, RunLocalReport> reports;

  @override
  Future<RunLocalReport?> readReport(String runId) async {
    return reports[runId];
  }
}
