import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';

import 'support/studio_widget_harness.dart';

// Shell 区域回归测试，聚焦全局框架、命令中心、状态详情和控制台。
// 用例只验证 UI 与 Runtime 状态契约，不访问真实设备或本机服务。
void main() {
  // 验证 V2 Shell 初始导航和产品文案。
  testWidgets('renders V2 shell navigation', (tester) async {
    await tester.pumpWidget(const StudioMacApp());

    expect(find.text('iOS 辅助工作台'), findsOneWidget);
    expect(find.text('V2.0 本机工作台'), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-总览')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-记录')), findsOneWidget);
    expect(find.text('本机自动化工作台'), findsOneWidget);
    expect(find.text('Flutter Demo'), findsNothing);
  });

  // 验证设置抽屉展示本机运行边界和隐私设置。
  testWidgets('settings drawer surfaces local runtime boundaries', (
    tester,
  ) async {
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      sessionId: 'redacted-session-placeholder',
      latestScreenshotAt: DateTime(2026, 1, 7, 3, 4, 5),
      settings: StudioSettings(evidenceMaxRuns: 12, evidenceMaxAgeDays: 9),
    );
    final controller = StudioRuntimeController(
      settings: StudioSettings(evidenceMaxRuns: 12, evidenceMaxAgeDays: 9),
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-settings-drawer')));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('工作台'), findsOneWidget);
    expect(find.text('运行时'), findsOneWidget);
    expect(find.text('单设备优先'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(find.text('视觉'), findsOneWidget);
    expect(find.text('视觉增强'), findsOneWidget);
    expect(find.text('轻量找图'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-toggle-视觉增强')));
    await tester.pumpAndSettle();

    expect(controller.snapshot.settings.enablePythonVision, isTrue);
    expect(find.text('Python 找图'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -680));
    await tester.pumpAndSettle();

    expect(find.text('隐私'), findsOneWidget);
    expect(find.text('证据保留'), findsOneWidget);
    expect(find.text('12 条'), findsOneWidget);
    expect(find.text('保留天数'), findsOneWidget);
    expect(find.text('9 天'), findsOneWidget);
    expect(find.text('默认显示截图'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('边界'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('边界'), findsOneWidget);
    expect(find.text('旧节点接口'), findsOneWidget);
    expect(find.text('任意脚本'), findsOneWidget);
    expect(find.text('redacted-session-placeholder'), findsNothing);
    expect(find.textContaining('127.0.0.1'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('settings-stepper-increase-证据保留')),
    );
    await tester.pumpAndSettle();

    expect(controller.snapshot.settings.evidenceMaxRuns, 13);
    expect(find.text('13 条'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('settings-stepper-increase-保留天数')),
    );
    await tester.pumpAndSettle();

    expect(controller.snapshot.settings.evidenceMaxAgeDays, 10);
    expect(find.text('10 天'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-toggle-默认显示截图')),
      -120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-toggle-默认显示截图')));
    await tester.pumpAndSettle();

    expect(controller.snapshot.settings.revealScreenshotsByDefault, isTrue);

    await controller.dispose();
  });

  // 验证顶部状态胶囊可打开只读详情抽屉。
  testWidgets('top status opens summary detail drawer', (tester) async {
    await useDesktopSurface(tester);
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runStatus: RunStatus.idle,
      sessionId: 'redacted-session-placeholder',
      latestScreenshotAt: DateTime(2026, 1, 7, 3, 4, 5),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('top-status-device')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('status-detail-drawer')), findsOneWidget);
    expect(find.text('状态详情'), findsOneWidget);
    expect(find.text('设备'), findsWidgets);
    expect(find.text('单台有线手机'), findsOneWidget);
    expect(find.text('手机会话已连接。'), findsNothing);
    expect(find.text('redacted-session-placeholder'), findsNothing);
    expect(find.textContaining('127.0.0.1'), findsNothing);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('top-status-workflow')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('status-detail-drawer')), findsOneWidget);
    expect(find.text('流程'), findsWidgets);
    expect(find.text('A-F 基础模板'), findsWidgets);
  });

  // 验证顶部流程状态会展示 Project DSL 引用问题。
  testWidgets('top status reports project workflow reference issues', (
    tester,
  ) async {
    await useDesktopSurface(tester);
    final workflow = missingSubWorkflowDefinition();
    final preview = StudioRuntimeSnapshot.initial(workflow: workflow).copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runStatus: RunStatus.idle,
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    expect(find.text('流程提醒'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('top-status-workflow')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('status-detail-drawer')), findsOneWidget);
    expect(find.text('问题'), findsOneWidget);
    expect(find.textContaining('不存在的子流程 missing-child'), findsOneWidget);
  });

  // 验证命令中心可搜索命令并切换到目标页面。
  testWidgets('global command center searches and navigates', (tester) async {
    await useDesktopSurface(tester);

    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('open-command-center')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('command-center-dialog')), findsOneWidget);
    expect(find.text('搜索命令'), findsOneWidget);
    expect(find.text('总览'), findsWidgets);
    expect(find.text('设备状态'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('command-center-search')),
      '运行',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('command-center-command-运行')),
      findsOneWidget,
    );
    expect(find.text('运行状态'), findsOneWidget);
    expect(find.text('设备状态'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('command-center-command-运行')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('command-center-dialog')), findsNothing);
    expect(find.text('运行设置'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('command-center-dialog')), findsOneWidget);
  });

  // 验证命令中心支持方向键、回车和 Esc。
  testWidgets('global command center supports keyboard operation', (
    tester,
  ) async {
    await useDesktopSurface(tester);

    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('open-command-center')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('command-center-dialog')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('command-center-dialog')), findsNothing);
    expect(find.text('开始录制'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-command-center')));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('command-center-dialog')), findsNothing);
  });

  // 验证本机环境检查只走 Runtime 检查器，不触发设备动作。
  testWidgets('global command center runs local stack check only', (
    tester,
  ) async {
    await useDesktopSurface(tester);
    final controller = StudioRuntimeController(
      dependencyChecker: FakeDependencyChecker(
        LocalDependencyReport(
          checks: const [
            LocalDependencyCheck(
              id: 'appium-cli',
              label: '驱动工具',
              status: LocalDependencyStatus.ready,
              summary: '驱动工具可用。',
              nextStep: '连接设备。',
            ),
          ],
          checkedAt: DateTime(2026, 1, 7, 3, 4, 5),
          message: '本机检查通过。',
        ),
      ),
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('open-command-center')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('command-center-search')),
      '环境',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('command-center-command-查环境')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('command-center-dialog')), findsNothing);
    expect(controller.snapshot.dependencyReport.message, '本机检查通过。');
    expect(controller.snapshot.events.last.message, '本机检查通过。');

    await controller.dispose();
  });

  // 验证复制隧道命令只是高级备用，不启动命令。
  testWidgets('global command center copies tunnel command only', (
    tester,
  ) async {
    await useDesktopSurface(tester);
    final copiedText = captureClipboardText();
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('open-command-center')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('command-center-search')),
      '隧道',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('command-center-command-复制隧道')),
      findsOneWidget,
    );

    await tester.tap(find.text('复制隧道'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('command-center-dialog')), findsNothing);
    expect(
      copiedText(),
      'sudo node_modules/.bin/appium driver run xcuitest tunnel-creation',
    );
    expect(controller.snapshot.runStatus, RunStatus.idle);
    expect(controller.snapshot.connectionStatus, ConnectionStatus.disconnected);
    expect(controller.snapshot.workflow.name, 'A-F 基础模板');

    await controller.dispose();
  });

  // 验证命令中心复制诊断摘要时只输出脱敏状态，不触发设备或运行。
  testWidgets('global command center copies sanitized diagnostics summary', (
    tester,
  ) async {
    await useDesktopSurface(tester);
    final copiedText = captureClipboardText();
    final controller = StudioRuntimeController();
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      sessionId: '0123456789ABCDEF0123456789ABCDEF',
      appiumMessage:
          'Appium ready at http://127.0.0.1:4723 from /Users/example/project.',
      events: [
        RuntimeEvent(
          level: 'info',
          message:
              'Appium ready at http://127.0.0.1:4723 from /Users/example/project with 0123456789ABCDEF0123456789ABCDEF.',
        ),
      ],
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-command-center')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('command-center-search')),
      '诊断',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('command-center-command-复制诊断')),
      findsOneWidget,
    );

    await tester.tap(find.text('复制诊断'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('command-center-dialog')), findsNothing);
    expect(copiedText(), contains('应用：本机工作台'));
    expect(copiedText(), contains('设备：设备就绪'));
    expect(copiedText(), contains('驱动：驱动运行'));
    expect(copiedText(), contains('运行：空闲'));
    expect(copiedText(), contains('边界：本机、单设备、串行'));
    expect(copiedText(), isNot(contains('127.0.0.1')));
    expect(copiedText(), isNot(contains('/Users/example')));
    expect(copiedText(), isNot(contains('0123456789ABCDEF0123456789ABCDEF')));
    expect(controller.snapshot.runStatus, RunStatus.idle);
    expect(controller.snapshot.connectionStatus, ConnectionStatus.disconnected);

    await controller.dispose();
  });

  // 验证命令中心可打开智能抽屉，并调用只读工具生成脱敏结果。
  testWidgets('global command center invokes safe ai tool', (tester) async {
    await useDesktopSurface(tester);
    final copiedText = captureClipboardText();
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('open-command-center')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('command-center-search')),
      '智能',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('command-center-command-智能')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('command-center-command-智能')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ai-command-drawer')), findsOneWidget);
    expect(find.text('建议、草稿、解释'), findsOneWidget);
    expect(find.text('暂无结果'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('ai-tool-readCurrentScreenSummary')),
    );
    await tester.pumpAndSettle();

    expect(find.text('已生成读屏摘要。'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(
      controller.snapshot.aiAuditLog.last.toolId,
      'readCurrentScreenSummary',
    );
    expect(controller.snapshot.runStatus, RunStatus.idle);
    expect(controller.snapshot.connectionStatus, ConnectionStatus.disconnected);

    await tester.tap(find.byTooltip('复制结果'));
    await tester.pumpAndSettle();

    expect(copiedText(), contains('readCurrentScreenSummary'));
    expect(copiedText(), contains('completed'));
    expect(copiedText(), contains('appLifecycle'));
    expect(copiedText(), contains('selectorTarget'));
    expect(copiedText(), isNot(contains('screenshotBase64')));
    expect(copiedText(), isNot(contains('127.0.0.1')));

    await controller.dispose();
  });

  // 验证危险智能工具必须确认，确认后也只交接不直接运行。
  testWidgets('ai run handoff requires confirmation and does not run', (
    tester,
  ) async {
    await useDesktopSurface(tester);
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('open-command-center')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('command-center-search')),
      '智能',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('command-center-command-智能')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ai-tool-runWorkflow')));
    await tester.pumpAndSettle();

    expect(find.text('确认交接'), findsOneWidget);
    expect(find.text('智能不会直接运行，只生成交接结果。'), findsOneWidget);

    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    expect(find.text('需交接'), findsWidgets);
    expect(find.textContaining('AI 不直接运行'), findsWidgets);
    expect(controller.snapshot.aiAuditLog.last.toolId, 'runWorkflow');
    expect(controller.snapshot.aiAuditLog.last.userConfirmed, isTrue);
    expect(controller.snapshot.runStatus, RunStatus.idle);
    expect(controller.snapshot.connectionStatus, ConnectionStatus.disconnected);

    await controller.dispose();
  });

  // 验证全局底部控制台的展开、标签和清空行为。
  testWidgets('bottom console expands, tabs and clears visible events', (
    tester,
  ) async {
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      events: [
        RuntimeEvent(level: 'info', message: '工作台运行时已就绪。'),
        RuntimeEvent(level: 'warning', message: '需要检查设备。'),
        RuntimeEvent(
          level: 'warning',
          message: '驱动检查失败：Unable to reach Appium: Connection failed.',
        ),
        RuntimeEvent(level: 'error', message: '驱动启动失败。'),
      ],
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    expect(find.byTooltip('展开控制台'), findsOneWidget);
    expect(find.textContaining('驱动启动失败'), findsWidgets);

    await tester.tap(find.byTooltip('展开控制台'));
    await tester.pumpAndSettle();

    expect(find.text('日志'), findsOneWidget);
    expect(find.text('错误'), findsWidgets);
    expect(find.text('检查'), findsOneWidget);
    expect(find.text('网络'), findsOneWidget);
    expect(find.text('调试'), findsOneWidget);
    expect(find.text('级别'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('console-level-filter-error')),
      findsOneWidget,
    );
    expect(find.text('信息'), findsWidgets);
    expect(find.text('提醒'), findsWidgets);
    expect(find.text('INFO'), findsNothing);
    expect(find.text('WARNING'), findsNothing);
    expect(find.text('ERROR'), findsNothing);
    expect(find.textContaining('工作台运行时已就绪'), findsOneWidget);
    expect(find.textContaining('需要检查设备'), findsOneWidget);
    expect(find.textContaining('未发现本机驱动'), findsOneWidget);
    expect(find.textContaining('Unable to reach'), findsNothing);
    expect(find.byTooltip('复制'), findsOneWidget);
    expect(find.byTooltip('清空'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('console-level-filter-error')));
    await tester.pumpAndSettle();

    expect(find.textContaining('驱动启动失败'), findsWidgets);
    expect(find.textContaining('工作台运行时已就绪'), findsNothing);
    expect(find.textContaining('需要检查设备'), findsNothing);

    await tester.tap(find.byTooltip('清空'));
    await tester.pumpAndSettle();

    expect(find.text('暂无控制台事件'), findsWidgets);
    expect(find.textContaining('驱动启动失败'), findsNothing);
  });

  // 验证网络标签只展示脱敏后的本机驱动通道摘要。
  testWidgets('bottom console network tab shows sanitized driver channel', (
    tester,
  ) async {
    final copiedText = captureClipboardText();
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      sessionId: '0123456789ABCDEF0123456789ABCDEF',
      appiumMessage:
          'Appium is ready at http://127.0.0.1:4723 from /Users/example/project with 0123456789ABCDEF0123456789ABCDEF.',
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byTooltip('展开控制台'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('网络'));
    await tester.pumpAndSettle();

    expect(find.text('通道'), findsOneWidget);
    expect(find.text('应用 -> 本机驱动 -> 手机'), findsOneWidget);
    expect(find.text('协议'), findsOneWidget);
    expect(find.text('本机驱动'), findsOneWidget);
    expect(find.text('Appium / WDA'), findsNothing);
    expect(find.text('手机'), findsOneWidget);
    expect(find.text('会话'), findsOneWidget);
    expect(find.textContaining('127.0.0.1'), findsNothing);
    expect(find.textContaining('/Users/example'), findsNothing);
    expect(
      find.textContaining('0123456789ABCDEF0123456789ABCDEF'),
      findsNothing,
    );

    await tester.tap(find.byTooltip('复制'));
    await tester.pumpAndSettle();

    expect(copiedText(), contains('通道：应用 -> 本机驱动 -> 手机'));
    expect(copiedText(), contains('协议：本机驱动'));
    expect(copiedText(), isNot(contains('Appium / WDA')));
    expect(copiedText(), contains('消息：'));
    expect(copiedText(), isNot(contains('127.0.0.1')));
    expect(copiedText(), isNot(contains('/Users/example')));
    expect(copiedText(), isNot(contains('0123456789ABCDEF0123456789ABCDEF')));
  });
}
