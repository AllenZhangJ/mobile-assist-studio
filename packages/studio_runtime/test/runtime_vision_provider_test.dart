import 'dart:convert';
import 'dart:io';

import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

import 'support/runtime_test_harness.dart';

// V4 Vision provider 回归测试。
// 用例只跑小尺寸 PNG fixture，不连接设备、不启动 Python。
void main() {
  test(
    'pyxelator fixture provider matches image target from screenshot',
    () async {
      final screenshot = fixturePngBase64(
        width: 5,
        height: 5,
        colorAt: (x, y) => x >= 1 && x <= 2 && y >= 1 && y <= 2
            ? const [255, 0, 0]
            : const [0, 0, 0],
      );
      final template = fixturePngBase64(
        width: 2,
        height: 2,
        colorAt: (x, y) => const [255, 0, 0],
      );
      final provider = const PyxelatorFixtureVisionProvider();
      final result = await provider.resolve(
        TargetResolutionRequest(
          target: _imageTarget(template),
          platform: MobilePlatform.ios,
          capabilities: MobileDriverCapabilityReport.none,
          screenshotBase64: screenshot,
          confidenceThreshold: 0.99,
        ),
      );

      expect(result.status, TargetResolutionStatus.matched);
      expect(result.point?.x, 2);
      expect(result.point?.y, 2);
      expect(result.region?.x, 1);
      expect(result.region?.y, 1);
      expect(result.confidence, 1);
      expect(result.evidenceRef, 'vision://pyxelator-fixture');
    },
  );

  test('pyxelator fixture provider reports low confidence safely', () async {
    final screenshot = fixturePngBase64(width: 4, height: 4);
    final template = fixturePngBase64(
      width: 2,
      height: 2,
      colorAt: (x, y) => const [0, 0, 255],
    );
    final provider = const PyxelatorFixtureVisionProvider();
    final result = await provider.resolve(
      TargetResolutionRequest(
        target: _imageTarget(template),
        platform: MobilePlatform.android,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: screenshot,
        confidenceThreshold: 0.99,
      ),
    );

    expect(result.status, TargetResolutionStatus.lowConfidence);
    expect(result.canContinue, isFalse);
    expect(result.confidence, lessThan(0.99));
  });

  test('pyxelator fixture provider refuses oversized local matching', () async {
    final screenshot = fixturePngBase64(width: 4, height: 4);
    final template = fixturePngBase64(width: 2, height: 2);
    final provider = const PyxelatorFixtureVisionProvider(maxOperations: 1);
    final result = await provider.resolve(
      TargetResolutionRequest(
        target: _imageTarget(template),
        platform: MobilePlatform.ios,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: screenshot,
        confidenceThreshold: 0.8,
      ),
    );

    expect(result.status, TargetResolutionStatus.unsupported);
    expect(result.message, contains('视觉服务'));
  });

  test('airtest fixture provider returns visual assertion match', () async {
    final screenshot = fixturePngBase64(
      width: 3,
      height: 3,
      colorAt: (x, y) =>
          x == 1 && y == 1 ? const [40, 200, 80] : const [0, 0, 0],
    );
    final template = fixturePngBase64(
      width: 1,
      height: 1,
      colorAt: (x, y) => const [40, 200, 80],
    );
    final provider = const AirtestFixtureVisionProvider();
    final result = await provider.resolve(
      TargetResolutionRequest(
        target: _imageTarget(template),
        platform: MobilePlatform.ios,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: screenshot,
        confidenceThreshold: 0.99,
      ),
    );

    expect(result.status, TargetResolutionStatus.matched);
    expect(result.evidenceRef, 'vision://airtest-fixture');
    expect(result.point?.x, 2);
    expect(result.point?.y, 2);
  });

  test('region provider resolves center point without device action', () async {
    const provider = RegionTargetProvider();
    final result = await provider.resolve(
      const TargetResolutionRequest(
        target: RuntimeTargetDefinition(
          id: 'pay_area',
          kind: RuntimeTargetKind.region,
          label: '支付区',
          payload: <String, Object?>{
            'x': 10,
            'y': 20,
            'width': 30,
            'height': 40,
          },
        ),
        platform: MobilePlatform.ios,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: '',
        confidenceThreshold: 0.8,
      ),
    );

    expect(result.status, TargetResolutionStatus.matched);
    expect(result.point?.x, 25);
    expect(result.point?.y, 40);
    expect(result.region?.width, 30);
    expect(result.evidenceRef, 'vision://region');
  });

  test('selector provider resolves element center from source', () async {
    const provider = SelectorTargetProvider();
    final result = await provider.resolve(
      const TargetResolutionRequest(
        target: RuntimeTargetDefinition(
          id: 'login_button',
          kind: RuntimeTargetKind.selector,
          label: '登录按钮',
          payload: <String, Object?>{'selector': 'label=登录'},
        ),
        platform: MobilePlatform.ios,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: '',
        confidenceThreshold: 0.8,
        sourceXml:
            '<AppiumAUT><XCUIElementTypeButton label="登录" x="10" y="20" width="100" height="40" /></AppiumAUT>',
      ),
    );

    expect(result.status, TargetResolutionStatus.matched);
    expect(result.point?.x, 60);
    expect(result.point?.y, 40);
    expect(result.region?.width, 100);
    expect(result.evidenceRef, 'vision://selector-source');
  });

  test('selector provider refuses missing source safely', () async {
    const provider = SelectorTargetProvider();
    final result = await provider.resolve(
      const TargetResolutionRequest(
        target: RuntimeTargetDefinition(
          id: 'login_button',
          kind: RuntimeTargetKind.selector,
          label: '登录按钮',
          payload: <String, Object?>{'selector': '登录'},
        ),
        platform: MobilePlatform.android,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: '',
        confidenceThreshold: 0.8,
      ),
    );

    expect(result.status, TargetResolutionStatus.unsupported);
    expect(result.message, '界面结构缺失。');
  });

  test('text provider resolves visible text from source', () async {
    const provider = TextTargetProvider();
    final result = await provider.resolve(
      const TargetResolutionRequest(
        target: RuntimeTargetDefinition(
          id: 'pay_text',
          kind: RuntimeTargetKind.text,
          label: '支付文案',
          payload: <String, Object?>{'query': '立即支付'},
        ),
        platform: MobilePlatform.android,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: '',
        confidenceThreshold: 0.8,
        sourceXml:
            '<hierarchy><node text="立即支付" bounds="[30,40][150,84]" /></hierarchy>',
      ),
    );

    expect(result.status, TargetResolutionStatus.matched);
    expect(result.point?.x, 90);
    expect(result.point?.y, 62);
    expect(result.evidenceRef, 'vision://text-source');
  });

  test('python ocr text provider maps matched result', () async {
    final screenshot = fixturePngBase64(width: 4, height: 4);
    final client = PythonVisionSidecarClient(
      runner: (executable, script, inputJson, timeout) async {
        final input = jsonDecode(inputJson) as Map<String, Object?>;
        expect(script, contains('image_to_data'));
        expect(input['query'], '立即支付');
        expect(input['screenshotBase64'], screenshot);
        return PythonSidecarRunResult(
          exitCode: 0,
          stdout: jsonEncode(<String, Object?>{
            'status': 'matched',
            'message': '已找到目标。',
            'x': 10,
            'y': 20,
            'centerX': 60,
            'centerY': 40,
            'width': 100,
            'height': 40,
            'confidence': 0.93,
            'evidenceRef': 'vision://python-ocr',
          }),
          stderr: '',
        );
      },
    );
    final provider = PythonOcrTextProvider(client: client);

    final result = await provider.resolve(
      TargetResolutionRequest(
        target: _textTarget('立即支付'),
        platform: MobilePlatform.android,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: screenshot,
        confidenceThreshold: 0.8,
      ),
    );

    expect(provider.id, 'python-ocr');
    expect(result.status, TargetResolutionStatus.matched);
    expect(result.point?.x, 60);
    expect(result.point?.y, 40);
    expect(result.region?.width, 100);
    expect(result.confidence, 0.93);
    expect(result.evidenceRef, 'vision://python-ocr');
  });

  test('python-enabled resolver falls back from source miss to OCR', () async {
    final screenshot = fixturePngBase64(width: 4, height: 4);
    var ocrCalled = false;
    final client = PythonVisionSidecarClient(
      runner: (executable, script, inputJson, timeout) async {
        final input = jsonDecode(inputJson) as Map<String, Object?>;
        ocrCalled = true;
        expect(input['query'], '继续');
        return PythonSidecarRunResult(
          exitCode: 0,
          stdout: jsonEncode(<String, Object?>{
            'status': 'matched',
            'x': 30,
            'y': 40,
            'centerX': 70,
            'centerY': 60,
            'width': 80,
            'height': 40,
            'confidence': 0.91,
            'evidenceRef': 'vision://python-ocr',
          }),
          stderr: '',
        );
      },
    );
    final resolver = CompositeTargetResolver.v4WithPython(client: client);

    final result = await resolver.resolve(
      TargetResolutionRequest(
        target: _textTarget('继续'),
        platform: MobilePlatform.ios,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: screenshot,
        confidenceThreshold: 0.8,
        sourceXml:
            '<AppiumAUT><XCUIElementTypeButton label="取消" x="10" y="20" width="100" height="40" /></AppiumAUT>',
      ),
    );

    expect(ocrCalled, isTrue);
    expect(result.status, TargetResolutionStatus.matched);
    expect(result.evidenceRef, 'vision://python-ocr');
  });

  test(
    'python-enabled resolver keeps source miss when OCR is unavailable',
    () async {
      final screenshot = fixturePngBase64(width: 4, height: 4);
      final client = PythonVisionSidecarClient(
        runner: (executable, script, inputJson, timeout) async {
          return PythonSidecarRunResult(
            exitCode: 0,
            stdout: jsonEncode(<String, Object?>{
              'status': 'unsupported',
              'message': 'OCR 视觉包不可用。',
              'evidenceRef': 'vision://python-ocr',
            }),
            stderr: '',
          );
        },
      );
      final resolver = CompositeTargetResolver.v4WithPython(client: client);

      final result = await resolver.resolve(
        TargetResolutionRequest(
          target: _textTarget('继续'),
          platform: MobilePlatform.ios,
          capabilities: MobileDriverCapabilityReport.none,
          screenshotBase64: screenshot,
          confidenceThreshold: 0.8,
          sourceXml:
              '<AppiumAUT><XCUIElementTypeButton label="取消" x="10" y="20" width="100" height="40" /></AppiumAUT>',
        ),
      );

      expect(result.status, TargetResolutionStatus.notMatched);
      expect(result.evidenceRef, 'vision://text-source');
    },
  );

  test('python sidecar provider maps matched template result', () async {
    final screenshot = fixturePngBase64(width: 3, height: 3);
    final template = fixturePngBase64(width: 1, height: 1);
    final client = PythonVisionSidecarClient(
      runner: (executable, script, inputJson, timeout) async {
        final input = jsonDecode(inputJson) as Map<String, Object?>;
        expect(executable, 'python3');
        expect(script, contains('read_png'));
        expect(input['screenshotBase64'], screenshot);
        expect(input['templateBase64'], template);
        return PythonSidecarRunResult(
          exitCode: 0,
          stdout: jsonEncode(<String, Object?>{
            'status': 'matched',
            'message': '已找到目标。',
            'x': 1,
            'y': 1,
            'centerX': 2,
            'centerY': 2,
            'width': 1,
            'height': 1,
            'confidence': 1,
          }),
          stderr: '',
        );
      },
    );
    final provider = PythonSidecarVisionProvider(client: client);

    final result = await provider.resolve(
      TargetResolutionRequest(
        target: _imageTarget(template),
        platform: MobilePlatform.ios,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: screenshot,
        confidenceThreshold: 0.99,
      ),
    );

    expect(result.status, TargetResolutionStatus.matched);
    expect(result.point?.x, 2);
    expect(result.point?.y, 2);
    expect(result.region?.x, 1);
    expect(result.confidence, 1);
    expect(result.evidenceRef, 'vision://python-sidecar');
  });

  test('python sidecar provider maps low confidence safely', () async {
    final screenshot = fixturePngBase64(width: 3, height: 3);
    final template = fixturePngBase64(width: 1, height: 1);
    final client = PythonVisionSidecarClient(
      runner: (executable, script, inputJson, timeout) async {
        return PythonSidecarRunResult(
          exitCode: 0,
          stdout: jsonEncode(<String, Object?>{
            'status': 'lowConfidence',
            'message': '目标置信度不足。',
            'confidence': 0.42,
          }),
          stderr: '',
        );
      },
    );
    final provider = PythonSidecarVisionProvider(client: client);

    final result = await provider.resolve(
      TargetResolutionRequest(
        target: _imageTarget(template),
        platform: MobilePlatform.android,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: screenshot,
        confidenceThreshold: 0.99,
      ),
    );

    expect(result.status, TargetResolutionStatus.lowConfidence);
    expect(result.canContinue, isFalse);
    expect(result.confidence, 0.42);
    expect(result.evidenceRef, 'vision://python-sidecar');
  });

  test(
    'python sidecar builtin backend matches template when available',
    () async {
      final python = await Process.run('python3', const ['--version']);
      if (python.exitCode != 0) return;
      final screenshot = fixturePngBase64(
        width: 4,
        height: 4,
        colorAt: (x, y) =>
            x == 2 && y == 1 ? const [250, 40, 20] : const [0, 0, 0],
      );
      final template = fixturePngBase64(
        width: 1,
        height: 1,
        colorAt: (x, y) => const [250, 40, 20],
      );

      final result =
          await const PythonVisionSidecarClient(
            timeout: Duration(seconds: 4),
          ).locateTemplate(
            screenshotBase64: screenshot,
            templateBase64: template,
            confidenceThreshold: 0.99,
            backend: PythonVisionBackend.builtin,
          );

      expect(result['status'], 'matched');
      expect(result['centerX'], 3);
      expect(result['centerY'], 2);
      expect(result['evidenceRef'], 'vision://python-builtin');
    },
  );

  test('pyxelator sidecar provider passes backend safely', () async {
    final screenshot = fixturePngBase64(width: 3, height: 3);
    final template = fixturePngBase64(width: 1, height: 1);
    final client = PythonVisionSidecarClient(
      runner: (executable, script, inputJson, timeout) async {
        final input = jsonDecode(inputJson) as Map<String, Object?>;
        expect(input['backend'], 'pyxelator');
        expect(script, contains('locate_with_pyxelator'));
        return PythonSidecarRunResult(
          exitCode: 0,
          stdout: jsonEncode(<String, Object?>{
            'status': 'matched',
            'x': 0,
            'y': 0,
            'centerX': 1,
            'centerY': 1,
            'width': 1,
            'height': 1,
            'confidence': 1,
            'evidenceRef': 'vision://pyxelator-sidecar',
          }),
          stderr: '',
        );
      },
    );
    final provider = PythonSidecarVisionProvider(
      client: client,
      backend: PythonVisionBackend.pyxelator,
    );

    final result = await provider.resolve(
      TargetResolutionRequest(
        target: _imageTarget(template),
        platform: MobilePlatform.ios,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: screenshot,
        confidenceThreshold: 0.8,
      ),
    );

    expect(provider.id, 'pyxelator-sidecar');
    expect(result.status, TargetResolutionStatus.matched);
    expect(result.evidenceRef, 'vision://pyxelator-sidecar');
  });

  test('python-enabled resolver falls back to builtin backend', () async {
    final screenshot = fixturePngBase64(width: 3, height: 3);
    final template = fixturePngBase64(width: 1, height: 1);
    final backends = <String>[];
    final client = PythonVisionSidecarClient(
      runner: (executable, script, inputJson, timeout) async {
        final input = jsonDecode(inputJson) as Map<String, Object?>;
        final backend = input['backend']?.toString() ?? '';
        backends.add(backend);
        if (backend != 'builtin') {
          return PythonSidecarRunResult(
            exitCode: 0,
            stdout: jsonEncode(<String, Object?>{
              'status': 'unsupported',
              'message': '$backend 不可用。',
            }),
            stderr: '',
          );
        }
        return PythonSidecarRunResult(
          exitCode: 0,
          stdout: jsonEncode(<String, Object?>{
            'status': 'matched',
            'x': 0,
            'y': 0,
            'centerX': 1,
            'centerY': 1,
            'width': 1,
            'height': 1,
            'confidence': 1,
            'evidenceRef': 'vision://python-builtin',
          }),
          stderr: '',
        );
      },
    );
    final resolver = CompositeTargetResolver.v4WithPython(client: client);

    final result = await resolver.resolve(
      TargetResolutionRequest(
        target: _imageTarget(template),
        platform: MobilePlatform.ios,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: screenshot,
        confidenceThreshold: 0.8,
      ),
    );

    expect(backends, ['pyxelator', 'airtest', 'builtin']);
    expect(result.status, TargetResolutionStatus.matched);
    expect(result.evidenceRef, 'vision://python-builtin');
  });

  test('python-enabled resolver prefers sidecar for image targets', () async {
    final screenshot = fixturePngBase64(width: 3, height: 3);
    final template = fixturePngBase64(width: 1, height: 1);
    var called = false;
    final client = PythonVisionSidecarClient(
      runner: (executable, script, inputJson, timeout) async {
        called = true;
        return PythonSidecarRunResult(
          exitCode: 0,
          stdout: jsonEncode(<String, Object?>{
            'status': 'matched',
            'x': 0,
            'y': 0,
            'centerX': 1,
            'centerY': 1,
            'width': 1,
            'height': 1,
            'confidence': 1,
          }),
          stderr: '',
        );
      },
    );
    final resolver = CompositeTargetResolver.v4WithPython(client: client);

    final result = await resolver.resolve(
      TargetResolutionRequest(
        target: _imageTarget(template),
        platform: MobilePlatform.ios,
        capabilities: MobileDriverCapabilityReport.none,
        screenshotBase64: screenshot,
        confidenceThreshold: 0.8,
      ),
    );

    expect(called, isTrue);
    expect(result.status, TargetResolutionStatus.matched);
    expect(result.evidenceRef, 'vision://python-sidecar');
  });
}

RuntimeTargetDefinition _imageTarget(String templateBase64) {
  return RuntimeTargetDefinition(
    id: 'login_button',
    kind: RuntimeTargetKind.image,
    label: '登录按钮',
    payload: <String, Object?>{
      'imageRef': 'targets/login-button.png',
      'imageBase64': templateBase64,
    },
  );
}

RuntimeTargetDefinition _textTarget(String query) {
  return RuntimeTargetDefinition(
    id: 'text_target',
    kind: RuntimeTargetKind.text,
    label: query,
    payload: <String, Object?>{'query': query},
  );
}
