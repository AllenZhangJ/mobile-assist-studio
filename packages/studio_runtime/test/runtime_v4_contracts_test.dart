import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

// V4 Runtime 合同回归。
// 这些测试只验证模型和 fake 探测，不连接真实设备或 Python。
void main() {
  test('initial snapshot exposes idle mobile runtime summary', () {
    final snapshot = StudioRuntimeSnapshot.initial();

    expect(snapshot.mobileRuntime.platform, MobilePlatform.unknown);
    expect(snapshot.mobileRuntime.resourceState, MobileResourceState.idle);
    expect(snapshot.mobileRuntime.capabilities.supportsCoreActions, isFalse);
    expect(snapshot.mobileRuntime.device, isNull);
  });

  test('mobile capability report identifies core action support', () {
    final capabilities = MobileDriverCapabilityReport.none.copyWith(
      platform: MobilePlatform.android,
      screenshot: true,
      tap: true,
      swipe: true,
      input: true,
    );

    expect(capabilities.platform, MobilePlatform.android);
    expect(capabilities.supportsCoreActions, isTrue);
    expect(capabilities.pageSource, isFalse);
  });

  test('target resolution separates matched and low confidence results', () {
    final matched = TargetResolutionResult.matched(
      point: const ViewportPoint(x: 10, y: 20),
      confidence: 0.91,
      evidenceRef: 'runs/demo/evidence.json',
    );
    final low = TargetResolutionResult.lowConfidence(confidence: 0.42);

    expect(matched.canContinue, isTrue);
    expect(matched.point?.x, 10);
    expect(matched.evidenceRef, isNotNull);
    expect(low.canContinue, isFalse);
    expect(low.status, TargetResolutionStatus.lowConfidence);
  });

  test(
    'python sidecar probe reports ready and partial package states',
    () async {
      final readyProbe = PythonSidecarProbe(
        runner: (executable, arguments) async {
          expect(executable, 'python3');
          return ProcessResult(1, 0, 'airtest=1\npyxelator=1\n', '');
        },
      );
      final partialProbe = PythonSidecarProbe(
        runner: (executable, arguments) async {
          return ProcessResult(2, 0, 'airtest=1\npyxelator=0\n', '');
        },
      );

      final ready = await readyProbe.check();
      final partial = await partialProbe.check();

      expect(ready.status, PythonSidecarStatus.ready);
      expect(ready.supportsPackage('airtest'), isTrue);
      expect(ready.supportsPackage('pyxelator'), isTrue);
      expect(partial.status, PythonSidecarStatus.partial);
      expect(partial.supportsPackage('airtest'), isTrue);
      expect(partial.supportsPackage('pyxelator'), isFalse);
    },
  );

  test('python sidecar probe hides executable path when unavailable', () async {
    final probe = PythonSidecarProbe(
      runner: (executable, arguments) async => ProcessResult(3, 1, '', 'fail'),
    );

    final report = await probe.check(executable: '/private/tool/python3');

    expect(report.status, PythonSidecarStatus.unavailable);
    expect(report.executableLabel, 'python3');
    expect(report.packages, isEmpty);
  });

  test(
    'ai tool registry keeps dangerous runtime actions behind confirmation',
    () {
      final registry = AiToolRegistry.v4Default;

      expect(registry.toolById('readCurrentScreenSummary')?.canAutoRun, isTrue);
      expect(registry.toolById('proposeWorkflowDraft')?.canAutoRun, isTrue);
      expect(registry.toolById('runWorkflow')?.canAutoRun, isFalse);
      expect(
        registry.toolById('runWorkflow')?.risk,
        AiToolRisk.requiresConfirmation,
      );
    },
  );
}
