import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Workflow 画布能力徽标回归。
// 用例只验证 UI 派生提示，不触发真实 Runtime 命令。
void main() {
  testWidgets('workflow canvas shows platform capability badges', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1500, 900));

    final preview =
        StudioRuntimeSnapshot.initial(
          workflow: _capabilityWorkflow,
          targets: const [
            RuntimeTargetDefinition(
              id: 'login_button',
              kind: RuntimeTargetKind.selector,
              label: '登录按钮',
              payload: {'selector': 'label=登录'},
            ),
          ],
        ).copyWith(
          connectionStatus: ConnectionStatus.connected,
          mobileRuntime: const MobileRuntimeSummary(
            platform: MobilePlatform.android,
            resourceState: MobileResourceState.idle,
            capabilities: _androidWithoutSourceCapabilities,
          ),
        );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));
    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-node-tap_login')),
        matching: find.byKey(
          const ValueKey('workflow-node-capability-tap_login'),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-node-tap_login')),
        matching: find.text('缺元素'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-node-snapshot')),
        matching: find.text('安卓可用'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-node-visual_missing')),
        matching: find.text('需目标'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('workflow canvas marks device actions as waiting when offline', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 860));

    final preview = StudioRuntimeSnapshot.initial(workflow: _offlineWorkflow)
        .copyWith(
          connectionStatus: ConnectionStatus.disconnected,
          mobileRuntime: const MobileRuntimeSummary(
            platform: MobilePlatform.android,
            resourceState: MobileResourceState.idle,
            capabilities: _androidReadyCapabilities,
          ),
        );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));
    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-node-tap_raw')),
        matching: find.text('待连'),
      ),
      findsOneWidget,
    );
  });
}

const _androidWithoutSourceCapabilities = MobileDriverCapabilityReport(
  platform: MobilePlatform.android,
  screenshot: true,
  tap: true,
  swipe: true,
  input: true,
  pageSource: false,
  selectorTarget: false,
  imageTarget: false,
  ocrTarget: false,
  appLifecycle: true,
  logs: true,
  performance: false,
  remotePreview: false,
);

const _androidReadyCapabilities = MobileDriverCapabilityReport(
  platform: MobilePlatform.android,
  screenshot: true,
  tap: true,
  swipe: true,
  input: true,
  pageSource: true,
  selectorTarget: true,
  imageTarget: false,
  ocrTarget: false,
  appLifecycle: true,
  logs: true,
  performance: false,
  remotePreview: false,
);

const _capabilityWorkflow = WorkflowDefinition(
  id: 'capability-badge-workflow',
  name: '能力徽标测试',
  entryNodesId: 'start',
  nodes: [
    WorkflowNode(
      id: 'start',
      type: WorkflowNodeType.start,
      label: '开始',
      next: ['tap_login'],
    ),
    WorkflowNode(
      id: 'tap_login',
      type: WorkflowNodeType.tap,
      label: '点登录',
      parameters: {'targetRef': 'login_button', 'durationMs': 80},
      next: ['snapshot'],
    ),
    WorkflowNode(
      id: 'snapshot',
      type: WorkflowNodeType.snapshot,
      label: '截图',
      parameters: {'save': true},
      next: ['visual_missing'],
    ),
    WorkflowNode(
      id: 'visual_missing',
      type: WorkflowNodeType.visualBranch,
      label: '看结果',
      parameters: {'confidenceThreshold': 0.8},
      next: ['end'],
    ),
    WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
  ],
);

const _offlineWorkflow = WorkflowDefinition(
  id: 'offline-capability-workflow',
  name: '离线能力测试',
  entryNodesId: 'start',
  nodes: [
    WorkflowNode(
      id: 'start',
      type: WorkflowNodeType.start,
      label: '开始',
      next: ['tap_raw'],
    ),
    WorkflowNode(
      id: 'tap_raw',
      type: WorkflowNodeType.tap,
      label: '点一下',
      parameters: {'x': 10, 'y': 20, 'durationMs': 80},
      next: ['end'],
    ),
    WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
  ],
);
