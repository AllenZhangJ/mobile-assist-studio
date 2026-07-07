import 'dart:async';
import 'dart:convert';
import 'dart:io';

// V4 smoke artifact contract 使用临时 fixture 验证 readiness / full smoke 留档结构。
// 它不启动 Appium、不请求 sudo、不创建手机会话，也不执行任何设备动作。
Future<void> main() async {
  final tempDir = await Directory.systemTemp.createTemp(
    'ias-v4-smoke-contract-',
  );
  try {
    await _seedFullSmokeFixture(tempDir);
    final result = await _runReadiness(tempDir);
    if (result.exitCode != 0) {
      _fail('readiness 合同生成失败：${_shortText(result.stderr)}');
    }

    final artifacts = await _loadGeneratedArtifacts(tempDir);
    _assertReadinessJson(artifacts.json);
    _assertReadinessMarkdown(artifacts.markdown);
    _assertNoSensitiveText(artifacts.allText);
    await _assertReadinessNextStepStateContracts();
    await _assertReadinessNextStepSanitizer();

    await _seedArchiveFixture(tempDir);
    final archiveResult = await _runArchive(tempDir);
    if (archiveResult.exitCode != 0) {
      _fail('archive 合同生成失败：${_shortText(archiveResult.stderr)}');
    }
    final archive = await _loadArchiveArtifacts(tempDir);
    _assertArchiveJson(archive.json);
    _assertArchiveMarkdown(archive.markdown);
    _assertNoSensitiveText(archive.allText);

    final finalArchive = await _runArchiveFinal(tempDir);
    _expect(
      finalArchive.exitCode == 2,
      'archive final 在 fixture 未完整时必须返回 2，实际 ${finalArchive.exitCode}。',
    );
    _expect(
      finalArchive.stderr.contains('Android 平台') &&
          finalArchive.stderr.contains('iOS 平台') &&
          finalArchive.stderr.contains('full smoke'),
      'archive final 必须提示平台 run 和 full smoke 缺口。',
    );

    final acceptance = await _runFinalAcceptance(tempDir);
    _expect(
      acceptance.exitCode == 0,
      'acceptance audit 在 fixture 下应成功留档，实际 ${acceptance.exitCode}。',
    );
    final acceptanceArtifacts = await _loadAcceptanceArtifacts(tempDir);
    _assertAcceptanceJson(acceptanceArtifacts.json);
    _assertAcceptanceMarkdown(
      acceptanceArtifacts.markdown,
      acceptanceArtifacts.json,
    );
    _assertNoSensitiveText(acceptanceArtifacts.allText);
    await _assertPackageSmokeScripts();

    final finalAcceptance = await _runFinalAcceptance(
      tempDir,
      requireComplete: true,
    );
    _expect(
      finalAcceptance.exitCode == 2,
      'acceptance final 在 fixture 未完整时必须返回 2，实际 ${finalAcceptance.exitCode}。',
    );
    _expect(
      finalAcceptance.stderr.contains('最终验收尚未通过') &&
          finalAcceptance.stderr.contains('完成审计') &&
          finalAcceptance.stderr.contains('归档终验') &&
          finalAcceptance.stderr.contains('终验门禁缺口') &&
          finalAcceptance.stderr.contains('iOS smoke') &&
          finalAcceptance.stderr.contains(
            'npm run v4:ios-smoke:full:password-prompt',
          ) &&
          finalAcceptance.stderr.contains('Android smoke') &&
          finalAcceptance.stderr.contains('npm run v4:android-smoke:full') &&
          finalAcceptance.stderr.contains(
            'npm run v4:smoke:full:password-prompt',
          ) &&
          finalAcceptance.stderr.contains('现场补验清单') &&
          finalAcceptance.stderr.contains('当前 iOS') &&
          finalAcceptance.stderr.contains('当前 Android') &&
          finalAcceptance.stderr.contains('先补齐单平台 smoke'),
      'acceptance final 必须提示最终验收缺口、现场补验清单和可执行门禁命令。',
    );
    _assertAcceptanceFinalStderrChecklistContract(
      finalAcceptance.stderr,
      _listAt(acceptanceArtifacts.json, 'fieldChecklist'),
    );
    final currentGit = await _currentGitRevision();
    final completeDir = Directory('${tempDir.path}/complete-current');
    await _seedCompleteSmokeFixture(
      completeDir,
      fullSmokeGit: currentGit,
      platformGit: currentGit,
    );
    final completeReadiness = await _runReadiness(
      completeDir,
      requireComplete: true,
    );
    _expect(
      completeReadiness.exitCode == 0,
      '当前提交完整 fixture 的 readiness final 应返回 0，实际 ${completeReadiness.exitCode}。',
    );
    final completeArtifacts = await _loadGeneratedArtifacts(completeDir);
    _assertCompleteReadinessJson(completeArtifacts.json);
    _assertNoSensitiveText(completeArtifacts.allText);
    final completeArchiveFinal = await _runArchiveFinal(completeDir);
    _expect(
      completeArchiveFinal.exitCode == 0,
      '当前提交完整 fixture 的 archive final 应返回 0，实际 ${completeArchiveFinal.exitCode}。',
    );

    final corruptLatestDir = Directory(
      '${tempDir.path}/complete-with-corrupt-latest-full-smoke',
    );
    await _seedCompleteSmokeFixture(
      corruptLatestDir,
      fullSmokeGit: currentGit,
      platformGit: currentGit,
    );
    await _seedCorruptLatestFullSmokeReport(corruptLatestDir);
    final corruptLatestReadiness = await _runReadiness(
      corruptLatestDir,
      requireComplete: true,
    );
    _expect(
      corruptLatestReadiness.exitCode == 0,
      '最新 full smoke JSON 损坏时 readiness 应回退到最近有效报告。',
    );
    final corruptLatestArchiveFinal = await _runArchiveFinal(corruptLatestDir);
    _expect(
      corruptLatestArchiveFinal.exitCode == 0,
      '最新 full smoke JSON 损坏时 archive final 应回退到最近有效报告。',
    );

    final corruptLatestAcceptanceDir = Directory(
      '${tempDir.path}/acceptance-with-corrupt-latest-generated-reports',
    );
    await _seedFullSmokeFixture(corruptLatestAcceptanceDir);
    await _seedArchiveFixture(corruptLatestAcceptanceDir);
    await _seedCorruptLatestGeneratedReports(corruptLatestAcceptanceDir);
    final corruptLatestAcceptance = await _runFinalAcceptance(
      corruptLatestAcceptanceDir,
    );
    _expect(
      corruptLatestAcceptance.exitCode == 0,
      '最新 readiness / archive JSON 损坏时 acceptance audit 应回退到最近有效报告。',
    );
    final corruptLatestAcceptanceArtifacts = await _loadAcceptanceArtifacts(
      corruptLatestAcceptanceDir,
    );
    _assertAcceptanceJson(corruptLatestAcceptanceArtifacts.json);

    final singlePlatformFullDir = Directory(
      '${tempDir.path}/complete-single-platform-full-smoke',
    );
    await _seedCompleteSmokeFixture(
      singlePlatformFullDir,
      fullSmokeGit: currentGit,
      platformGit: currentGit,
      includeAndroidFullSmokeStep: false,
    );
    final singlePlatformReadiness = await _runReadiness(
      singlePlatformFullDir,
      requireComplete: true,
    );
    _expect(
      singlePlatformReadiness.exitCode == 2,
      'full smoke 缺少 Android 步骤时 readiness final 必须返回 2。',
    );
    final singlePlatformArchiveFinal = await _runArchiveFinal(
      singlePlatformFullDir,
    );
    _expect(
      singlePlatformArchiveFinal.exitCode == 2 &&
          singlePlatformArchiveFinal.stderr.contains('full smoke'),
      'full smoke 缺少 Android 步骤时 archive final 必须拒绝完整通过。',
    );
    final singlePlatformAcceptance = await _runFinalAcceptance(
      singlePlatformFullDir,
      requireComplete: true,
    );
    _expect(
      singlePlatformAcceptance.exitCode == 2 &&
          singlePlatformAcceptance.stderr.contains('Full smoke'),
      'full smoke 缺少 Android 步骤时 acceptance final 必须输出 Full smoke 缺口。',
    );

    final mismatchDir = Directory('${tempDir.path}/complete-old-full-smoke');
    await _seedCompleteSmokeFixture(
      mismatchDir,
      fullSmokeGit: _differentGit(currentGit),
      platformGit: currentGit,
    );
    final mismatchReadiness = await _runReadiness(
      mismatchDir,
      requireComplete: true,
    );
    _expect(
      mismatchReadiness.exitCode == 2,
      '旧提交 full smoke 的 readiness final 必须返回 2，实际 ${mismatchReadiness.exitCode}。',
    );
    final mismatchArchiveFinal = await _runArchiveFinal(mismatchDir);
    _expect(
      mismatchArchiveFinal.exitCode == 2 &&
          mismatchArchiveFinal.stderr.contains('不属于当前提交'),
      '旧提交 full smoke 的 archive final 必须提示不属于当前提交。',
    );

    final platformMismatchDir = Directory(
      '${tempDir.path}/complete-old-platform-runs',
    );
    await _seedCompleteSmokeFixture(
      platformMismatchDir,
      fullSmokeGit: currentGit,
      platformGit: _differentGit(currentGit),
    );
    final platformMismatchArchiveFinal = await _runArchiveFinal(
      platformMismatchDir,
    );
    _expect(
      platformMismatchArchiveFinal.exitCode == 2 &&
          platformMismatchArchiveFinal.stderr.contains('iOS 平台') &&
          platformMismatchArchiveFinal.stderr.contains('Android 平台') &&
          platformMismatchArchiveFinal.stderr.contains('当前提交完整通过'),
      '旧提交平台 run 的 archive final 必须提示平台 smoke 不属于当前提交完整通过。',
    );

    final detachedScreenshotDir = Directory(
      '${tempDir.path}/complete-detached-screenshots',
    );
    await _seedCompleteSmokeFixture(
      detachedScreenshotDir,
      fullSmokeGit: currentGit,
      platformGit: currentGit,
      writePlatformScreenshots: false,
    );
    final detachedScreenshotReadiness = await _runReadiness(
      detachedScreenshotDir,
      requireComplete: true,
    );
    _expect(
      detachedScreenshotReadiness.exitCode == 2,
      '只有全局截图、平台 run 缺少同 run 截图文件时 readiness final 必须拒绝通过。',
    );
    final detachedScreenshotAcceptance = await _runFinalAcceptance(
      detachedScreenshotDir,
      requireComplete: true,
    );
    _expect(
      detachedScreenshotAcceptance.exitCode == 2 &&
          detachedScreenshotAcceptance.stderr.contains('iOS smoke') &&
          detachedScreenshotAcceptance.stderr.contains('Android smoke') &&
          detachedScreenshotAcceptance.stderr.contains('截图缺文件'),
      '平台 run 缺少同 run 截图文件时 acceptance final 必须输出平台 smoke 缺口。',
    );
    final detachedScreenshotArchiveFinal = await _runArchiveFinal(
      detachedScreenshotDir,
    );
    _expect(
      detachedScreenshotArchiveFinal.exitCode == 2 &&
          detachedScreenshotArchiveFinal.stderr.contains('iOS 平台') &&
          detachedScreenshotArchiveFinal.stderr.contains('Android 平台') &&
          detachedScreenshotArchiveFinal.stderr.contains('当前提交完整通过'),
      '只有全局截图、平台 run 缺少同 run 截图文件时 archive final 必须拒绝通过。',
    );
    stdout.writeln('V4 smoke artifact contract passed');
  } finally {
    await tempDir.delete(recursive: true);
  }
}

// 断言 npm 单平台 full smoke 入口复用 full smoke 编排器，保留自动准备能力。
Future<void> _assertPackageSmokeScripts() async {
  final packageFile = File('package.json');
  _expect(await packageFile.exists(), '必须存在 package.json。');
  final decoded = jsonDecode(await packageFile.readAsString());
  _expect(decoded is Map, 'package.json 必须是 JSON 对象。');
  final packageJson = Map<String, Object?>.from(decoded as Map);
  final scripts = _mapAt(packageJson, 'scripts');
  final devDependencies = _mapAt(packageJson, 'devDependencies');
  _expect(
    devDependencies['appium-xcuitest-driver'] is String,
    'package.json 必须固定 Appium XCUITest driver。',
  );
  _expect(
    devDependencies['appium-uiautomator2-driver'] is String,
    'package.json 必须固定 Appium UiAutomator2 driver。',
  );
  await _assertFullSmokeDriverProbe();
  await _assertFullSmokePreflightStateContracts();
  await _assertFinalAcceptanceNextStepSanitizer();
  _assertFullSmokeScript(
    scripts,
    name: 'v4:ios-smoke:full',
    requiredSkipFlag: '--skip-android',
  );
  _assertFullSmokeScript(
    scripts,
    name: 'v4:ios-smoke:full:password-prompt',
    requiredSkipFlag: '--skip-android',
    requiresPasswordPrompt: true,
  );
  _assertFullSmokeScript(
    scripts,
    name: 'v4:ios-smoke:full:password-stdin',
    requiredSkipFlag: '--skip-android',
    requiresPasswordStdin: true,
  );
  _assertFullSmokeScript(
    scripts,
    name: 'v4:android-smoke:full',
    requiredSkipFlag: '--skip-ios',
  );
  _assertFullSmokeScript(
    scripts,
    name: 'v4:smoke:full:password-prompt',
    requiredSkipFlag: '',
    requiresPasswordPrompt: true,
  );
}

// 断言 final acceptance 生成端会过滤 nextSteps 中的非白名单命令。
Future<void> _assertFinalAcceptanceNextStepSanitizer() async {
  final sourceFile = File('tool/v4_final_acceptance.dart');
  _expect(await sourceFile.exists(), '必须存在 final acceptance 生成器。');
  final source = await sourceFile.readAsString();
  _expect(
    source.contains('_safeAcceptanceInstructionText') &&
        source.contains('命令已过滤') &&
        source.contains('_allowedAcceptanceCommands.contains(command)'),
    'final acceptance 生成端必须过滤 nextSteps 中的非白名单命令。',
  );
}

// 断言单条 full smoke 脚本包含自动准备、动作确认和单平台跳过参数。
void _assertFullSmokeScript(
  Map<String, Object?> scripts, {
  required String name,
  required String requiredSkipFlag,
  bool requiresPasswordStdin = false,
  bool requiresPasswordPrompt = false,
}) {
  final command = scripts[name]?.toString() ?? '';
  _expect(
    command.contains('tool/v4_full_smoke.dart'),
    '$name 必须使用 full smoke 编排器。',
  );
  _expect(command.contains('--confirm-actions'), '$name 必须显式确认真实动作。');
  _expect(command.contains('--auto-prepare'), '$name 必须自动准备本机环境。');
  if (requiredSkipFlag.isNotEmpty) {
    _expect(
      command.contains(requiredSkipFlag),
      '$name 必须包含 $requiredSkipFlag。',
    );
  }
  if (requiresPasswordStdin) {
    _expect(
      command.contains('--admin-password-stdin'),
      '$name 必须通过 stdin 一次性读取本机密码。',
    );
  }
  if (requiresPasswordPrompt) {
    _expect(
      command.contains('--admin-password-prompt'),
      '$name 必须通过终端提示读取本机密码。',
    );
  }
}

// 断言平台 driver 探测同时解析 stdout / stderr，兼容 Appium CLI 的实际输出流。
Future<void> _assertFullSmokeDriverProbe() async {
  final sourceFile = File('tool/v4_full_smoke.dart');
  _expect(await sourceFile.exists(), '必须存在 full smoke 编排器。');
  final source = await sourceFile.readAsString();
  _expect(
    source.contains(r'${result.stdout}\n${result.stderr}'),
    '平台 driver 探测必须同时解析 stdout 和 stderr。',
  );
  _expect(
    source.contains('_readAdminPasswordFromPrompt') &&
        source.contains(
          '--admin-password-prompt 和 --admin-password-stdin 不能同时使用',
        ),
    'full smoke 必须支持隐藏输入密码，并阻止 prompt / stdin 同时启用。',
  );
  _expect(
    source.contains('ANDROID_SMOKE_PREFLIGHT_') &&
        source.contains("'source': 'full-smoke'"),
    'full smoke 的 Android 前置阻断必须同步生成 Android preflight 留档。',
  );
  _expect(
    source.contains('_probeIosUsbMux') &&
        source.contains('available: count == 1') &&
        source.contains('available: ready == 1'),
    'full smoke preflight 必须同时按唯一 iOS USB 和唯一 Android 手机判定可用。',
  );
}

// 断言 full smoke 执行入口也会在真实动作前拦截多设备状态。
Future<void> _assertFullSmokePreflightStateContracts() async {
  final tempDir = await Directory.systemTemp.createTemp(
    'ias-v4-full-smoke-state-',
  );
  try {
    await _assertFullSmokePreflightState(
      tempDir,
      name: 'ios-multi-usb',
      arguments: const <String>['--skip-android'],
      adbDevicesOutput: 'List of devices attached\n\n',
      usbmuxOutput: '[{"ConnectionType":"USB"},{"ConnectionType":"USB"}]',
      checkName: 'iOS USB',
      expectedDetail: 'USB 2',
      expectedNextStep: '只连接一台 iPhone，解锁并信任后重试。',
    );
    await _assertFullSmokePreflightState(
      tempDir,
      name: 'android-multi-ready',
      arguments: const <String>['--skip-ios'],
      adbDevicesOutput:
          'List of devices attached\nFAKE001\tdevice\nFAKE002\tdevice\n',
      usbmuxOutput: '[]',
      checkName: 'Android 手机',
      expectedDetail: '可用 2，未授权 0，离线 0',
      expectedNextStep: '只保留一台已授权 Android 手机后重试。',
    );
  } finally {
    await tempDir.delete(recursive: true);
  }
}

// 运行 full smoke preflight fixture，并校验指定检查项阻断。
Future<void> _assertFullSmokePreflightState(
  Directory rootDir, {
  required String name,
  required List<String> arguments,
  required String adbDevicesOutput,
  required String usbmuxOutput,
  required String checkName,
  required String expectedDetail,
  required String expectedNextStep,
}) async {
  final binDir = Directory('${rootDir.path}/bin-$name');
  await _writeFakeProbeCommands(
    binDir,
    adbDevicesOutput: adbDevicesOutput,
    usbmuxOutput: usbmuxOutput,
  );
  final outDir = Directory('${rootDir.path}/out-$name');
  final result = await _runFullSmoke(
    outDir,
    arguments: arguments,
    environment: <String, String>{
      'PATH': '${binDir.path}:${Platform.environment['PATH'] ?? ''}',
    },
  );
  _expect(
    result.exitCode == 1,
    'full smoke 状态 fixture $name 必须在前置检查返回 1，实际 ${result.exitCode}。',
  );
  _expect(result.stderr.contains('V4 full smoke 前置准备未通过'), '$name 必须输出前置阻断。');

  final artifacts = await _loadFullSmokeArtifacts(outDir);
  final preflight = _mapAt(artifacts.json, 'preflight');
  final checks = _listAt(preflight, 'items').map(_mapFrom).toList();
  final item = checks.firstWhere(
    (check) => check['name'] == checkName,
    orElse: () => const <String, Object?>{},
  );
  _expect(item.isNotEmpty, '$name 必须包含 $checkName 检查项。');
  _expect(item['ok'] == false, '$name 的 $checkName 必须为阻断。');
  _expect(item['detail'] == expectedDetail, '$name 的 $checkName detail 不正确。');
  _expect(
    item['nextStep'] == expectedNextStep,
    '$name 的 $checkName nextStep 不正确。',
  );
}

// 断言 readiness 对 Android 现场状态给出可执行、状态驱动的下一步。
Future<void> _assertReadinessNextStepStateContracts() async {
  final tempDir = await Directory.systemTemp.createTemp(
    'ias-v4-readiness-state-',
  );
  try {
    await _assertIosReadinessState(
      tempDir,
      name: 'ios-none',
      usbmuxOutput: '[]',
      usbDevices: 0,
      available: false,
      expectedTexts: const <String>[
        '未发现 USB iPhone',
        '先插线、解锁并信任',
        'npm run v4:ios-smoke:full:password-prompt',
      ],
    );
    await _assertIosReadinessState(
      tempDir,
      name: 'ios-single',
      usbmuxOutput: '[{"ConnectionType":"USB"}]',
      usbDevices: 1,
      available: true,
      expectedTexts: const <String>[
        '运行 `npm run v4:ios-smoke:full:password-prompt`',
        '按提示输入 Mac 密码',
      ],
    );
    await _assertIosReadinessState(
      tempDir,
      name: 'ios-multi',
      usbmuxOutput: '[{"ConnectionType":"USB"},{"ConnectionType":"USB"}]',
      usbDevices: 2,
      available: false,
      expectedTexts: const <String>[
        '发现多台 USB iPhone',
        '只连接一台 iPhone',
        'npm run v4:ios-smoke:full:password-prompt',
      ],
    );
    await _assertAndroidReadinessState(
      tempDir,
      name: 'none',
      adbDevicesOutput: 'List of devices attached\n\n',
      ready: 0,
      unauthorized: 0,
      offline: 0,
      available: false,
      expectedTexts: const <String>[
        '未发现 Android 手机',
        '开启 USB 调试',
        'npm run v4:android-smoke:full',
      ],
    );
    await _assertAndroidReadinessState(
      tempDir,
      name: 'unauthorized',
      adbDevicesOutput: 'List of devices attached\nFAKE001\tunauthorized\n',
      ready: 0,
      unauthorized: 1,
      offline: 0,
      available: false,
      expectedTexts: const <String>[
        '手机未授权',
        '允许 USB 调试',
        'npm run v4:android-smoke:full',
      ],
    );
    await _assertAndroidReadinessState(
      tempDir,
      name: 'offline',
      adbDevicesOutput: 'List of devices attached\nFAKE001\toffline\n',
      ready: 0,
      unauthorized: 0,
      offline: 1,
      available: false,
      expectedTexts: const <String>[
        '手机离线',
        '重插数据线',
        'npm run v4:android-smoke:full',
      ],
    );
    await _assertAndroidReadinessState(
      tempDir,
      name: 'single-ready',
      adbDevicesOutput: 'List of devices attached\nFAKE001\tdevice\n',
      ready: 1,
      unauthorized: 0,
      offline: 0,
      available: true,
      expectedTexts: const <String>['当前手机可用', 'npm run v4:android-smoke:full'],
    );
    await _assertAndroidReadinessState(
      tempDir,
      name: 'multi-ready',
      adbDevicesOutput:
          'List of devices attached\nFAKE001\tdevice\nFAKE002\tdevice\n',
      ready: 2,
      unauthorized: 0,
      offline: 0,
      available: false,
      expectedTexts: const <String>[
        '发现多台可用手机',
        '只保留一台 USB 手机',
        'npm run v4:android-smoke:full',
      ],
    );
  } finally {
    await tempDir.delete(recursive: true);
  }
}

// 用 fake usbmux 输出生成 readiness，校验 iOS USB 单设备边界。
Future<void> _assertIosReadinessState(
  Directory rootDir, {
  required String name,
  required String usbmuxOutput,
  required int usbDevices,
  required bool available,
  required List<String> expectedTexts,
}) async {
  final binDir = Directory('${rootDir.path}/bin-$name');
  await _writeFakeProbeCommands(
    binDir,
    adbDevicesOutput: 'List of devices attached\n\n',
    usbmuxOutput: usbmuxOutput,
  );
  final outDir = Directory('${rootDir.path}/out-$name');
  final result = await _runReadiness(
    outDir,
    environment: <String, String>{
      'PATH': '${binDir.path}:${Platform.environment['PATH'] ?? ''}',
    },
  );
  _expect(
    result.exitCode == 0,
    'readiness iOS 状态 fixture $name 应生成成功，实际 ${result.exitCode}：${_shortText(result.stderr)}',
  );

  final artifacts = await _loadGeneratedArtifacts(outDir);
  final localState = _mapAt(artifacts.json, 'localState');
  final iosUsbMux = _mapAt(localState, 'iosUsbMux');
  _expect(
    iosUsbMux['usbDevices'] == usbDevices,
    '$name usbDevices 计数应为 $usbDevices。',
  );
  _expect(
    iosUsbMux['available'] == available,
    '$name iOS USB available 状态不正确。',
  );

  final nextSteps = _stringList(artifacts.json['nextSteps']).join('\n');
  for (final text in expectedTexts) {
    _expect(nextSteps.contains(text), '$name 下一步必须包含：$text');
  }
  _assertNoSensitiveText(artifacts.allText);
}

// 用 fake adb 输出生成 readiness，校验机器可读状态和用户下一步一致。
Future<void> _assertAndroidReadinessState(
  Directory rootDir, {
  required String name,
  required String adbDevicesOutput,
  required int ready,
  required int unauthorized,
  required int offline,
  required bool available,
  required List<String> expectedTexts,
}) async {
  final binDir = Directory('${rootDir.path}/bin-$name');
  await _writeFakeProbeCommands(binDir, adbDevicesOutput: adbDevicesOutput);
  final outDir = Directory('${rootDir.path}/out-$name');
  final result = await _runReadiness(
    outDir,
    environment: <String, String>{
      'PATH': '${binDir.path}:${Platform.environment['PATH'] ?? ''}',
    },
  );
  _expect(
    result.exitCode == 0,
    'readiness 状态 fixture $name 应生成成功，实际 ${result.exitCode}：${_shortText(result.stderr)}',
  );

  final artifacts = await _loadGeneratedArtifacts(outDir);
  final localState = _mapAt(artifacts.json, 'localState');
  final android = _mapAt(localState, 'androidDevice');
  _expect(android['ready'] == ready, '$name ready 计数应为 $ready。');
  _expect(
    android['unauthorized'] == unauthorized,
    '$name unauthorized 计数应为 $unauthorized。',
  );
  _expect(android['offline'] == offline, '$name offline 计数应为 $offline。');
  _expect(android['available'] == available, '$name available 状态不正确。');

  final nextSteps = _stringList(artifacts.json['nextSteps']).join('\n');
  for (final text in expectedTexts) {
    _expect(nextSteps.contains(text), '$name 下一步必须包含：$text');
  }
  _assertNoSensitiveText(artifacts.allText);
}

// 写入 fake 探测命令，确保合同测试不依赖真实手机或本机工具状态。
Future<void> _writeFakeProbeCommands(
  Directory binDir, {
  required String adbDevicesOutput,
  String usbmuxOutput = '[]',
}) async {
  await binDir.create(recursive: true);
  await _writeFakeExecutable(File('${binDir.path}/git'), '''
#!/bin/sh
if [ "\$1" = "rev-parse" ]; then
  echo abc1234
  exit 0
fi
exit 0
''');
  await _writeFakeExecutable(File('${binDir.path}/xcrun'), '''
#!/bin/sh
if [ "\$1" = "devicectl" ]; then
  cat <<'EOF'
Name        Identifier   State
---------   ----------   -----
EOF
  exit 0
fi
exit 0
''');
  await _writeFakeExecutable(File('${binDir.path}/pymobiledevice3'), '''
#!/bin/sh
if [ "\$1" = "usbmux" ]; then
  cat <<'EOF'
$usbmuxOutput
EOF
  exit 0
fi
exit 0
''');
  await _writeFakeExecutable(File('${binDir.path}/adb'), '''
#!/bin/sh
cat <<'EOF'
$adbDevicesOutput
EOF
''');
}

// 写入可执行脚本，并显式设置执行权限。
Future<void> _writeFakeExecutable(File file, String content) async {
  await file.writeAsString(content.trimLeft(), flush: true);
  final chmod = await Process.run('chmod', <String>['+x', file.path]);
  _expect(chmod.exitCode == 0, '无法设置 fake 命令执行权限：${file.path}');
}

// 写入最小 full smoke fixture，用于验证 readiness 能索引最近编排报告。
Future<void> _seedFullSmokeFixture(Directory outDir) async {
  await outDir.create(recursive: true);
  final timestamp = DateTime.utc(2026);
  final git = await _currentGitRevision();
  final base = '${outDir.path}/FULL_SMOKE_2026-01-01T00-00-00-000000Z';
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'kind': 'v4FullSmoke',
    'timestamp': timestamp.toIso8601String(),
    'git': git,
    'completion': <String, Object?>{
      'complete': false,
      'label': '前置检查阻断',
      'failedSteps': <String>[],
    },
    'preparation': <String, Object?>{
      'skipped': false,
      'status': '有阻断',
      'hasBlockers': true,
      'blockers': <String>['自动准备', 'iOS 隧道', 'Android 准备'],
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'name': '自动准备',
          'ok': false,
          'detail': '缺少密码',
          'nextStep': '输入密码后重试。',
        },
        <String, Object?>{
          'name': 'iOS 隧道',
          'ok': false,
          'detail': '缺少密码',
          'nextStep': '通过终端提示一次性传入密码后重试。',
        },
        <String, Object?>{
          'name': 'Android 准备',
          'ok': false,
          'detail': '未授权',
          'nextStep': '允许 USB 调试后重试。',
        },
      ],
    },
    'preflight': <String, Object?>{
      'skipped': false,
      'status': '有阻断',
      'hasBlockers': true,
      'blockers': <String>['Appium', 'Android 手机'],
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'name': 'Appium',
          'ok': false,
          'detail': '不可达',
          'nextStep': '先连接设备。',
        },
        <String, Object?>{
          'name': 'Android 手机',
          'ok': false,
          'detail': '未就绪',
          'nextStep': '连接一台已授权手机。',
        },
      ],
    },
    'steps': <Object?>[],
  };
  const encoder = JsonEncoder.withIndent('  ');
  await File('$base.json').writeAsString('${encoder.convert(payload)}\n');
  await File('$base.md').writeAsString('# V4 Full Smoke\n\n- 前置检查：有阻断\n');
  final iosRunDir = Directory(
    '${outDir.path}/ios/run-2026-01-01T00-00-00-000000Z',
  );
  await iosRunDir.create(recursive: true);
  await File('${iosRunDir.path}/metadata.json').writeAsString(
    '${encoder.convert(<String, Object?>{'workflowName': 'V4 Smoke', 'startedAt': timestamp.toIso8601String()})}\n',
  );
  await File('${iosRunDir.path}/finished.json').writeAsString(
    '${encoder.convert(<String, Object?>{'status': 'failed', 'finishedAt': timestamp.toIso8601String()})}\n',
  );
  final iosEvents = <Map<String, Object?>>[
    <String, Object?>{'type': 'smokeStart', 'actionsAllowed': true, 'git': git},
    <String, Object?>{'type': 'smokeWorkflowStart'},
    <String, Object?>{'type': 'smokeAction', 'action': 'tap'},
    <String, Object?>{'type': 'smokeFailure', 'message': 'WDA 会话失败'},
  ];
  await File(
    '${iosRunDir.path}/events.jsonl',
  ).writeAsString('${iosEvents.map(jsonEncode).join('\n')}\n');
  final androidDir = Directory('${outDir.path}/android');
  await androidDir.create(recursive: true);
  final preflightPayload = <String, Object?>{
    'schemaVersion': 1,
    'kind': 'v4AndroidSmokePreflight',
    'timestamp': timestamp.toIso8601String(),
    'git': git,
    'completion': <String, Object?>{
      'ready': false,
      'label': '有阻断',
      'blockers': <String>['驱动'],
    },
    'request': <String, Object?>{'allowActions': true, 'workflowBasic': true},
    'checks': <Map<String, Object?>>[
      <String, Object?>{
        'name': '驱动',
        'ok': false,
        'status': '阻断',
        'detail': '不可达',
        'nextStep': '先连接设备。',
      },
      <String, Object?>{
        'name': '安卓手机',
        'ok': true,
        'status': '通过',
        'detail': 'Pixel 9 ZY22...CDEF',
        'nextStep': '-',
        'ready': 1,
        'unauthorized': 0,
        'offline': 0,
      },
    ],
    'nextSteps': <String>['先连接设备，切勿运行 `rm -rf /tmp/ias-bad`。'],
  };
  await File(
    '${androidDir.path}/ANDROID_SMOKE_PREFLIGHT_2026-01-01T00-00-00-000000Z.json',
  ).writeAsString('${encoder.convert(preflightPayload)}\n');
  await Directory('${androidDir.path}/diagnostics').create(recursive: true);
}

// 写入 archive fixture，只放虚拟截图文件，不读取或生成真实隐私图片。
Future<void> _seedArchiveFixture(Directory outDir) async {
  await File(
    '${outDir.path}/studio-ui-fixture.png',
  ).writeAsBytes(<int>[0x89, 0x50, 0x4E, 0x47]);
}

// 写入当前提交完整 smoke fixture，验证严格门禁存在可通过路径。
Future<void> _seedCompleteSmokeFixture(
  Directory outDir, {
  required String fullSmokeGit,
  required String platformGit,
  bool writePlatformScreenshots = true,
  bool includeAndroidFullSmokeStep = true,
}) async {
  await outDir.create(recursive: true);
  final timestamp = DateTime.utc(2026, 1, 2);
  const encoder = JsonEncoder.withIndent('  ');
  final base = '${outDir.path}/FULL_SMOKE_2026-01-02T00-00-00-000000Z';
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'kind': 'v4FullSmoke',
    'timestamp': timestamp.toIso8601String(),
    'git': fullSmokeGit,
    'completion': <String, Object?>{
      'complete': true,
      'label': '完整通过',
      'failedSteps': <String>[],
    },
    'preparation': <String, Object?>{
      'skipped': false,
      'status': '通过',
      'hasBlockers': false,
      'blockers': <String>[],
      'items': <Map<String, Object?>>[],
    },
    'preflight': <String, Object?>{
      'skipped': false,
      'status': '通过',
      'hasBlockers': false,
      'blockers': <String>[],
      'items': <Map<String, Object?>>[],
    },
    'steps': <Map<String, Object?>>[
      <String, Object?>{
        'step': <String, Object?>{'name': 'iOS smoke'},
        'status': '通过',
      },
      if (includeAndroidFullSmokeStep)
        <String, Object?>{
          'step': <String, Object?>{'name': 'Android smoke'},
          'status': '通过',
        },
    ],
  };
  await File('$base.json').writeAsString('${encoder.convert(payload)}\n');
  await File('$base.md').writeAsString('# V4 Full Smoke\n\n- 完成：完整通过\n');
  await File(
    '${outDir.path}/studio-ui-fixture.png',
  ).writeAsBytes(<int>[0x89, 0x50, 0x4E, 0x47]);
  await _seedCompletePlatformRun(
    Directory('${outDir.path}/ios/run-2026-01-02T00-00-00-000000Z'),
    git: platformGit,
    timestamp: timestamp,
    writeScreenshotFile: writePlatformScreenshots,
  );
  await _seedCompletePlatformRun(
    Directory('${outDir.path}/android/run-2026-01-02T00-00-00-000000Z'),
    git: platformGit,
    timestamp: timestamp,
    writeScreenshotFile: writePlatformScreenshots,
  );
}

// 写入一份文件名更新但内容损坏的 full smoke 报告，验证读取逻辑能回退。
Future<void> _seedCorruptLatestFullSmokeReport(Directory outDir) async {
  await File(
    '${outDir.path}/FULL_SMOKE_2026-01-03T00-00-00-000000Z.json',
  ).writeAsString('{bad-json\n');
}

// 写入未来时间戳但内容损坏的生成报告，验证 final acceptance 能回退读取。
Future<void> _seedCorruptLatestGeneratedReports(Directory outDir) async {
  await File(
    '${outDir.path}/SMOKE_READINESS_2999-01-01T00-00-00-000000Z.json',
  ).writeAsString('{bad-json\n');
  final archiveDir = Directory('${outDir.path}/archives');
  await archiveDir.create(recursive: true);
  await File(
    '${archiveDir.path}/SMOKE_ARCHIVE_2999-01-01T00-00-00-000000Z.json',
  ).writeAsString('{bad-json\n');
}

// 写入单个平台完整 smoke run，覆盖截图、动作、workflow 和日志事件。
Future<void> _seedCompletePlatformRun(
  Directory runDir, {
  required String git,
  required DateTime timestamp,
  bool writeScreenshotFile = true,
}) async {
  await runDir.create(recursive: true);
  if (writeScreenshotFile) {
    final screenshotDir = Directory('${runDir.path}/screenshots');
    await screenshotDir.create(recursive: true);
    await File(
      '${screenshotDir.path}/smoke-initial.png',
    ).writeAsBytes(<int>[0x89, 0x50, 0x4E, 0x47]);
  }
  const encoder = JsonEncoder.withIndent('  ');
  await File('${runDir.path}/metadata.json').writeAsString(
    '${encoder.convert(<String, Object?>{'workflowName': 'V4 Smoke', 'startedAt': timestamp.toIso8601String(), 'git': git})}\n',
  );
  await File('${runDir.path}/finished.json').writeAsString(
    '${encoder.convert(<String, Object?>{'status': 'success', 'finishedAt': timestamp.toIso8601String(), 'git': git})}\n',
  );
  final events = <Map<String, Object?>>[
    <String, Object?>{'type': 'smokeStart', 'actionsAllowed': true, 'git': git},
    <String, Object?>{
      'type': 'smokeScreenshot',
      'screenshot': 'screenshots/smoke-initial.png',
    },
    <String, Object?>{'type': 'smokeWorkflowStart'},
    <String, Object?>{'type': 'smokeAction', 'action': 'tap'},
    <String, Object?>{'type': 'smokeAction', 'action': 'swipe'},
    <String, Object?>{'type': 'smokeAction', 'action': 'input'},
    <String, Object?>{'type': 'smokeWorkflowStep', 'action': 'tap'},
    <String, Object?>{'type': 'smokeLogs'},
  ];
  await File(
    '${runDir.path}/events.jsonl',
  ).writeAsString('${events.map(jsonEncode).join('\n')}\n');
}

// 当前短提交号用于 fixture 绑定 smoke 留档版本；失败时使用 unknown。
Future<String> _currentGitRevision() async {
  try {
    final result = await Process.run('git', const [
      'rev-parse',
      '--short',
      'HEAD',
    ]).timeout(const Duration(seconds: 4));
    if (result.exitCode != 0) return 'unknown';
    final value = '${result.stdout}'.trim();
    return value.isEmpty ? 'unknown' : value;
  } on Object {
    return 'unknown';
  }
}

// 生成一个确定不同于当前提交的短 hash，用于验证旧证据不能通过门禁。
String _differentGit(String currentGit) {
  const first = 'deadbee';
  if (currentGit.toLowerCase() != first) return first;
  return 'badcafe';
}

// 调用现有 readiness 工具端到端生成报告，保持合同覆盖真实 CLI 输出。
Future<_ProcessResult> _runReadiness(
  Directory outDir, {
  bool requireComplete = false,
  Map<String, String>? environment,
}) async {
  return _runDartTool(<String>[
    'tool/v4_smoke_readiness.dart',
    '--out-dir',
    outDir.path,
    '--timeout',
    '1',
    if (requireComplete) '--require-complete',
  ], environment: environment);
}

// 调用 full smoke 编排器，只跑前置检查 fixture，不连接真实设备。
Future<_ProcessResult> _runFullSmoke(
  Directory outDir, {
  required List<String> arguments,
  Map<String, String>? environment,
}) async {
  return _runDartTool(<String>[
    'tool/v4_full_smoke.dart',
    '--confirm-actions',
    '--out-dir',
    outDir.path,
    '--preflight-timeout',
    '1',
    ...arguments,
  ], environment: environment);
}

// 调用现有 archive 工具端到端生成本地索引。
Future<_ProcessResult> _runArchive(Directory outDir) async {
  return _runDartTool(<String>[
    'tool/v4_smoke_archive.dart',
    '--out-dir',
    outDir.path,
    '--archive-dir',
    '${outDir.path}/archives',
    '--timeout',
    '1',
  ]);
}

// 调用 archive final 严格门禁，验证未完整 fixture 不会误通过。
Future<_ProcessResult> _runArchiveFinal(Directory outDir) async {
  return _runDartTool(<String>[
    'tool/v4_smoke_archive.dart',
    '--out-dir',
    outDir.path,
    '--archive-dir',
    '${outDir.path}/archives-final',
    '--timeout',
    '1',
    '--require-complete',
    '--require-screenshot',
    '--require-platform-runs',
  ]);
}

// 调用最终验收工具，验证统一审计报告和严格门禁。
Future<_ProcessResult> _runFinalAcceptance(
  Directory outDir, {
  bool requireComplete = false,
}) async {
  return _runDartTool(<String>[
    'tool/v4_final_acceptance.dart',
    '--out-dir',
    outDir.path,
    '--archive-dir',
    '${outDir.path}/archives',
    '--report-dir',
    '${outDir.path}/acceptance',
    '--probe-timeout',
    '1',
    '--step-timeout',
    '20',
    if (requireComplete) '--require-complete',
  ]);
}

// 启动 Dart 工具并设置统一超时，合同不依赖真实设备。
Future<_ProcessResult> _runDartTool(
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    arguments,
    environment: <String, String>{
      ...Platform.environment,
      if (environment != null) ...environment,
      'DART_SUPPRESS_ANALYTICS': 'true',
      'FLUTTER_SUPPRESS_ANALYTICS': 'true',
    },
  );
  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();
  final stdoutDone = process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .listen(stdoutBuffer.write)
      .asFuture<void>();
  final stderrDone = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .listen(stderrBuffer.write)
      .asFuture<void>();

  var exitCode = 0;
  try {
    exitCode = await process.exitCode.timeout(const Duration(seconds: 20));
  } on TimeoutException {
    process.kill(ProcessSignal.sigterm);
    exitCode = 124;
  }
  await _settleOutput(stdoutDone, stderrDone);
  return _ProcessResult(
    exitCode: exitCode,
    stdout: stdoutBuffer.toString(),
    stderr: stderrBuffer.toString(),
  );
}

// 等待子进程输出收尾，避免合同偶发丢失尾部错误。
Future<void> _settleOutput(
  Future<void> stdoutDone,
  Future<void> stderrDone,
) async {
  try {
    await Future.wait(<Future<void>>[
      stdoutDone,
      stderrDone,
    ]).timeout(const Duration(seconds: 2));
  } on Object {
    // 输出收尾失败时，合同仍以 exit code 和已收集文本为准。
  }
}

// 读取 readiness 生成的最新 JSON 和 Markdown。
Future<_ReadinessArtifacts> _loadGeneratedArtifacts(Directory outDir) async {
  final jsonFiles = await _matchingFiles(
    outDir,
    RegExp(r'^SMOKE_READINESS_.*\.json$'),
  );
  final markdownFiles = await _matchingFiles(
    outDir,
    RegExp(r'^SMOKE_READINESS_.*\.md$'),
  );
  _expect(
    jsonFiles.length == 1,
    'readiness JSON 数量应为 1，实际 ${jsonFiles.length}',
  );
  _expect(
    markdownFiles.length == 1,
    'readiness Markdown 数量应为 1，实际 ${markdownFiles.length}',
  );

  final jsonText = await jsonFiles.single.readAsString();
  final markdown = await markdownFiles.single.readAsString();
  final decoded = jsonDecode(jsonText);
  _expect(decoded is Map, 'readiness JSON 必须是对象。');
  return _ReadinessArtifacts(
    json: Map<String, Object?>.from(decoded as Map),
    markdown: markdown,
    allText: '$jsonText\n$markdown',
  );
}

// 读取 full smoke 生成的最新 JSON 和 Markdown。
Future<_FullSmokeArtifacts> _loadFullSmokeArtifacts(Directory outDir) async {
  final jsonFiles = await _matchingFiles(
    outDir,
    RegExp(r'^FULL_SMOKE_.*\.json$'),
  );
  final markdownFiles = await _matchingFiles(
    outDir,
    RegExp(r'^FULL_SMOKE_.*\.md$'),
  );
  _expect(
    jsonFiles.length == 1,
    'full smoke JSON 数量应为 1，实际 ${jsonFiles.length}',
  );
  _expect(
    markdownFiles.length == 1,
    'full smoke Markdown 数量应为 1，实际 ${markdownFiles.length}',
  );

  final jsonText = await jsonFiles.single.readAsString();
  final markdown = await markdownFiles.single.readAsString();
  final decoded = jsonDecode(jsonText);
  _expect(decoded is Map, 'full smoke JSON 必须是对象。');
  return _FullSmokeArtifacts(
    json: Map<String, Object?>.from(decoded as Map),
    markdown: markdown,
    allText: '$jsonText\n$markdown',
  );
}

// 读取 archive 生成的最新 JSON 和 Markdown。
Future<_ArchiveArtifacts> _loadArchiveArtifacts(Directory outDir) async {
  final archiveDir = Directory('${outDir.path}/archives');
  final jsonFiles = await _matchingFiles(
    archiveDir,
    RegExp(r'^SMOKE_ARCHIVE_.*\.json$'),
  );
  final markdownFiles = await _matchingFiles(
    archiveDir,
    RegExp(r'^SMOKE_ARCHIVE_.*\.md$'),
  );
  _expect(jsonFiles.length == 1, 'archive JSON 数量应为 1，实际 ${jsonFiles.length}');
  _expect(
    markdownFiles.length == 1,
    'archive Markdown 数量应为 1，实际 ${markdownFiles.length}',
  );

  final jsonText = await jsonFiles.single.readAsString();
  final markdown = await markdownFiles.single.readAsString();
  final decoded = jsonDecode(jsonText);
  _expect(decoded is Map, 'archive JSON 必须是对象。');
  return _ArchiveArtifacts(
    json: Map<String, Object?>.from(decoded as Map),
    markdown: markdown,
    allText: '$jsonText\n$markdown',
  );
}

// 读取 final acceptance 生成的最新 JSON 和 Markdown。
Future<_AcceptanceArtifacts> _loadAcceptanceArtifacts(Directory outDir) async {
  final acceptanceDir = Directory('${outDir.path}/acceptance');
  final jsonFiles = await _matchingFiles(
    acceptanceDir,
    RegExp(r'^FINAL_ACCEPTANCE_.*\.json$'),
  );
  final markdownFiles = await _matchingFiles(
    acceptanceDir,
    RegExp(r'^FINAL_ACCEPTANCE_.*\.md$'),
  );
  _expect(
    jsonFiles.length == 1,
    'acceptance JSON 数量应为 1，实际 ${jsonFiles.length}',
  );
  _expect(
    markdownFiles.length == 1,
    'acceptance Markdown 数量应为 1，实际 ${markdownFiles.length}',
  );

  final jsonText = await jsonFiles.single.readAsString();
  final markdown = await markdownFiles.single.readAsString();
  final decoded = jsonDecode(jsonText);
  _expect(decoded is Map, 'acceptance JSON 必须是对象。');
  return _AcceptanceArtifacts(
    json: Map<String, Object?>.from(decoded as Map),
    markdown: markdown,
    allText: '$jsonText\n$markdown',
  );
}

// 列出目录下文件名匹配的文件，并按文件名排序。
Future<List<File>> _matchingFiles(Directory dir, RegExp pattern) async {
  final files = <File>[];
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (pattern.hasMatch(name)) files.add(entity);
  }
  files.sort(
    (left, right) =>
        left.uri.pathSegments.last.compareTo(right.uri.pathSegments.last),
  );
  return files;
}

// 断言 readiness JSON 的稳定合同字段，覆盖批次、状态、证据和下一步。
void _assertReadinessJson(Map<String, Object?> json) {
  _expect(json['schemaVersion'] == 1, 'schemaVersion 必须为 1。');
  _expect(json['kind'] == 'v4SmokeReadiness', 'kind 必须为 v4SmokeReadiness。');

  final completion = _mapAt(json, 'completion');
  _expect(
    completion['complete'] == false,
    'fixture 下 completion.complete 必须为 false。',
  );
  _expect(
    completion['label'] is String && '${completion['label']}'.isNotEmpty,
    'completion.label 必须存在。',
  );

  final localState = _mapAt(json, 'localState');
  for (final key in <String>[
    'appium',
    'iosTunnel',
    'iosDevice',
    'iosUsbMux',
    'androidDevice',
  ]) {
    _expect(localState[key] is Map, 'localState.$key 必须存在。');
  }
  final iosUsbMux = _mapAt(localState, 'iosUsbMux');
  _expect(
    iosUsbMux.containsKey('toolAvailable') &&
        iosUsbMux.containsKey('usbDevices'),
    'localState.iosUsbMux 必须保留工具状态和 USB 数量。',
  );

  final batches = _listAt(json, 'batches');
  _expect(batches.length == 9, 'batches 必须包含 Batch 0-8。');
  _expect(
    batches.any((item) => _mapFrom(item)['name'] == 'Batch 0 真源治理'),
    'batches 必须包含 Batch 0。',
  );
  _expect(
    batches.any((item) => _mapFrom(item)['name'] == 'Batch 8 AI / MCP Core'),
    'batches 必须包含 Batch 8。',
  );

  final artifacts = _mapAt(json, 'artifacts');
  _expect(artifacts['fullSmokeReports'] == 1, 'fullSmokeReports 必须索引 fixture。');
  _expect(artifacts['iosRuns'] == 1, 'readiness 必须只统计 run-* iOS smoke 目录。');
  _expect(
    artifacts['androidRuns'] == 0,
    'readiness 不得把 Android 普通诊断目录计作 smoke run。',
  );
  _expect(
    artifacts['androidPreflightReports'] == 1,
    'androidPreflightReports 必须索引 Android 前置诊断。',
  );
  final latestAndroidPreflight = _mapAt(artifacts, 'latestAndroidPreflight');
  _expect(
    latestAndroidPreflight['label'] == '有阻断',
    'latestAndroidPreflight.label 必须保留阻断状态。',
  );
  _expect(
    _stringList(latestAndroidPreflight['blockers']).contains('驱动'),
    'latestAndroidPreflight.blockers 必须包含驱动。',
  );
  final androidPreflightNextSteps = _stringList(
    latestAndroidPreflight['nextSteps'],
  ).join('\n');
  _expect(
    androidPreflightNextSteps.contains('命令已过滤') &&
        !androidPreflightNextSteps.contains('rm -rf'),
    'latestAndroidPreflight.nextSteps 必须过滤非白名单命令。',
  );
  final latestFullSmoke = _mapAt(artifacts, 'latestFullSmoke');
  _expect(latestFullSmoke['git'] is String, 'latestFullSmoke 必须保留提交号。');
  _expect(
    latestFullSmoke['label'] == '前置检查阻断',
    'latestFullSmoke.label 必须保留阻断状态。',
  );
  _expect(
    latestFullSmoke['preflightStatus'] == '有阻断',
    'latestFullSmoke.preflightStatus 必须保留前置状态。',
  );
  _expect(latestFullSmoke['stepCount'] == 0, '前置阻断时 stepCount 必须为 0。');
  final blockers = _stringList(latestFullSmoke['blockers']);
  _expect(blockers.contains('自动准备'), 'latestFullSmoke.blockers 必须包含自动准备。');
  _expect(blockers.contains('iOS 隧道'), 'latestFullSmoke.blockers 必须包含 iOS 隧道。');
  _expect(
    blockers.contains('Android 准备'),
    'latestFullSmoke.blockers 必须包含 Android 准备。',
  );
  _expect(blockers.contains('Appium'), 'latestFullSmoke.blockers 必须包含 Appium。');
  _expect(
    blockers.contains('Android 手机'),
    'latestFullSmoke.blockers 必须包含 Android 手机。',
  );
  final latestIos = _mapAt(artifacts, 'latestIos');
  _expect(latestIos['git'] is String, 'latestIos 必须保留提交号。');
  _expect(
    latestIos['status'] == 'failed' && latestIos['fullPassed'] == false,
    'latestIos 必须保留最近失败且未完整通过的状态。',
  );
  _expect(
    '${latestIos['summary']}'.contains('失败'),
    'latestIos.summary 必须包含失败摘要。',
  );

  final nextSteps = _listAt(json, 'nextSteps');
  _expect(nextSteps.isNotEmpty, 'nextSteps 必须给出下一步。');
  final nextStepText = nextSteps.map((step) => '$step').join('\n');
  _assertCommandBackticksAreWhitelisted(
    nextSteps.map((step) => '$step'),
    'readiness nextSteps',
  );
  _expect(
    nextStepText.contains('v4:ios-smoke:full:password-prompt') &&
        nextStepText.contains('USB iPhone') &&
        nextStepText.contains('v4:android-smoke:full') &&
        nextStepText.contains('未发现 Android 手机') &&
        nextStepText.contains('开启 USB 调试'),
    'readiness nextSteps 必须给出 iOS 密码版命令和 Android 状态驱动命令。',
  );
}

// 断言 readiness 生成端会过滤 nextSteps 中的非白名单命令。
Future<void> _assertReadinessNextStepSanitizer() async {
  final sourceFile = File('tool/v4_smoke_readiness.dart');
  _expect(await sourceFile.exists(), '必须存在 readiness 生成器。');
  final source = await sourceFile.readAsString();
  _expect(
    source.contains('_safeReadinessInstructionText') &&
        source.contains('_allowedReadinessCommands.contains(command)') &&
        source.contains('命令已过滤'),
    'readiness 生成端必须过滤 nextSteps 中的非白名单命令。',
  );
}

// 断言完整 fixture 的 readiness 严格门禁能成功闭环。
void _assertCompleteReadinessJson(Map<String, Object?> json) {
  final git = json['git']?.toString();
  _expect(git != null && git.isNotEmpty, '完整 readiness 必须保留当前提交号。');
  final completion = _mapAt(json, 'completion');
  _expect(completion['complete'] == true, '完整 fixture 必须通过 completion。');
  _expect(
    completion['latestIosFullPassed'] == true &&
        completion['latestAndroidFullPassed'] == true &&
        completion['latestFullSmokeComplete'] == true,
    '完整 fixture 必须同时满足 iOS、Android 和 full smoke 完整通过。',
  );
  _expect(
    completion['latestIosMatchesCurrentGit'] == true &&
        completion['latestAndroidMatchesCurrentGit'] == true &&
        completion['latestFullSmokeMatchesCurrentGit'] == true,
    '完整 fixture 必须全部属于当前提交。',
  );
  final artifacts = _mapAt(json, 'artifacts');
  final latestIos = _mapAt(artifacts, 'latestIos');
  final latestAndroid = _mapAt(artifacts, 'latestAndroid');
  _expect(
    latestIos['git'] == git &&
        latestAndroid['git'] == git &&
        _mapAt(artifacts, 'latestFullSmoke')['git'] == git,
    '完整 fixture 的三类 smoke 证据必须绑定同一当前提交。',
  );
  _expect(
    latestIos['screenshotFileCount'] == 1 &&
        latestAndroid['screenshotFileCount'] == 1,
    '完整 fixture 的平台 smoke 必须保留同 run 截图文件计数。',
  );
  final batches = _listAt(json, 'batches').map(_mapFrom).toList();
  _expect(
    batches.any(
      (batch) =>
          batch['name'] == 'Batch 2 双平台 smoke' &&
          batch['status'] == '已完成完整 smoke 留档',
    ),
    'Batch 2 必须在当前提交完整 smoke 后显示完成。',
  );
}

// 断言 Markdown 留档包含人类复盘需要的 full smoke 索引区。
void _assertReadinessMarkdown(String markdown) {
  for (final text in <String>[
    '# V4 Smoke Readiness',
    '最近 full smoke',
    'Android 前置诊断',
    'Full smoke 报告',
    '## 批次验收索引',
    '## 下一步',
  ]) {
    _expect(markdown.contains(text), 'Markdown 必须包含：$text');
  }
}

// 断言 archive JSON 的稳定合同字段，覆盖截图、报告和自排除。
void _assertArchiveJson(Map<String, Object?> json) {
  _expect(json['schemaVersion'] == 1, 'archive schemaVersion 必须为 1。');
  _expect(json['kind'] == 'v4SmokeArchive', 'archive kind 必须正确。');

  final summary = _mapAt(json, 'summary');
  _expect(summary['readinessReports'] == 1, 'archive 必须索引 readiness JSON。');
  _expect(summary['fullSmokeReports'] == 1, 'archive 必须索引 full smoke JSON。');
  _expect(summary['screenshots'] == 1, 'archive 必须索引截图。');
  _expect(summary['iosRuns'] == 1, 'fixture 下 iOS run 必须为 1。');
  _expect(summary['androidRuns'] == 0, 'fixture 下 Android run 必须为 0。');

  final latestFullSmoke = _mapAt(summary, 'latestFullSmoke');
  _expect(latestFullSmoke['git'] is String, 'archive latestFullSmoke 必须保留提交号。');
  _expect(
    latestFullSmoke['label'] == '前置检查阻断',
    'archive latestFullSmoke.label 必须保留阻断状态。',
  );
  final blockers = _stringList(latestFullSmoke['blockers']);
  _expect(blockers.contains('自动准备'), 'archive blockers 必须包含自动准备。');
  _expect(blockers.contains('iOS 隧道'), 'archive blockers 必须包含 iOS 隧道。');
  _expect(blockers.contains('Android 准备'), 'archive blockers 必须包含 Android 准备。');
  _expect(blockers.contains('Appium'), 'archive blockers 必须包含 Appium。');
  final latestIosSmoke = _mapAt(summary, 'latestIosSmoke');
  _expect(latestIosSmoke['git'] is String, 'archive latestIosSmoke 必须保留提交号。');
  _expect(
    latestIosSmoke['fullPassed'] == false &&
        '${latestIosSmoke['summary']}'.contains('无截图'),
    'archive latestIosSmoke 必须保留未完整通过状态。',
  );

  final warnings = _stringList(json['warnings']);
  _expect(warnings.isNotEmpty, 'archive 必须保留当前缺口提醒。');
  _expect(
    warnings.any(
          (warning) =>
              warning.contains('iOS 平台') && warning.contains('当前提交完整通过'),
        ) &&
        warnings.any((warning) => warning.contains('Android 平台')),
    'archive 必须提示 iOS 平台 run 未完整和缺少 Android 平台 run。',
  );

  final artifacts = _listAt(json, 'artifacts');
  _expect(artifacts.length >= 5, 'archive 必须索引 fixture 文件。');
  _expect(
    artifacts.every((item) {
      final path = _mapFrom(item)['relativePath']?.toString() ?? '';
      return !path.startsWith('archives/');
    }),
    'archive 不得把自身输出目录纳入索引。',
  );
}

// 断言 archive Markdown 包含最终人工复盘需要的区域。
void _assertArchiveMarkdown(String markdown) {
  for (final text in <String>[
    '# V4 Smoke Archive',
    '## 汇总',
    '## 最近报告',
    'iOS smoke',
    'Android smoke',
    '## 截图索引',
    '## 提醒',
  ]) {
    _expect(markdown.contains(text), 'Archive Markdown 必须包含：$text');
  }
}

// 断言 final acceptance JSON 覆盖统一验收步骤和失败摘要。
void _assertAcceptanceJson(Map<String, Object?> json) {
  _expect(json['schemaVersion'] == 1, 'acceptance schemaVersion 必须为 1。');
  _expect(json['kind'] == 'v4FinalAcceptance', 'acceptance kind 必须正确。');

  final completion = _mapAt(json, 'completion');
  _expect(completion['auditOk'] == true, 'acceptance auditOk 必须为 true。');
  _expect(
    completion['complete'] == false,
    'fixture 下 acceptance complete 必须为 false。',
  );
  final failures = _stringList(completion['failures']);
  _expect(
    failures.any((failure) => failure.contains('完成审计')) &&
        failures.any((failure) => failure.contains('归档终验')),
    'acceptance 必须保留两个最终门禁失败摘要。',
  );
  final gitStatus = _mapAt(json, 'gitStatus');
  _expect(json['git'] is String, 'acceptance 必须保留短提交号。');
  _expect(
    gitStatus['revision'] is String,
    'acceptance gitStatus 必须保留 revision。',
  );
  _expect(gitStatus['branch'] is String, 'acceptance gitStatus 必须保留 branch。');
  _expect(gitStatus.containsKey('dirty'), 'acceptance gitStatus 必须保留 dirty。');
  _expect(gitStatus['worktree'] is String, 'acceptance gitStatus 必须保留工作区状态。');
  _expect(gitStatus.containsKey('synced'), 'acceptance gitStatus 必须保留 synced。');
  _expect(gitStatus['ahead'] is int, 'acceptance gitStatus 必须保留 ahead 数字。');
  _expect(gitStatus['behind'] is int, 'acceptance gitStatus 必须保留 behind 数字。');
  _expect(gitStatus['remote'] is String, 'acceptance gitStatus 必须保留远端状态。');
  final gateGaps = _listAt(json, 'gateGaps');
  _expect(gateGaps.isNotEmpty, 'acceptance 必须生成结构化终验门禁缺口。');
  _assertAcceptanceCommandsAreWhitelisted(gateGaps, 'gateGaps');
  _expect(
    gateGaps.any(
          (gap) =>
              _mapFrom(gap)['title'] == 'iOS smoke' &&
              '${_mapFrom(gap)['current']}'.contains('iOS 当前状态') &&
              '${_mapFrom(gap)['current']}'.contains('iOS 最近未完整通过') &&
              _mapFrom(gap)['command'] ==
                  'npm run v4:ios-smoke:full:password-prompt',
        ) &&
        gateGaps.any(
          (gap) =>
              _mapFrom(gap)['title'] == 'Android smoke' &&
              '${_mapFrom(gap)['current']}'.contains('Android 当前状态') &&
              '${_mapFrom(gap)['current']}'.contains(
                '未发现 Android 平台 smoke run',
              ) &&
              _mapFrom(gap)['command'] == 'npm run v4:android-smoke:full',
        ) &&
        gateGaps.any(
          (gap) =>
              _mapFrom(gap)['title'] == 'Full smoke' &&
              '${_mapFrom(gap)['required']}'.contains('当前提交') &&
              _mapFrom(gap)['command'] ==
                  'npm run v4:smoke:full:password-prompt',
        ),
    'acceptance gateGaps 必须包含 iOS、Android 和密码版 full smoke 缺口。',
  );
  final nextSteps = _stringList(json['nextSteps']);
  _assertAcceptanceNextStepCommandsAreWhitelisted(nextSteps);
  _expect(
    nextSteps.any((step) => step.contains('v4:ios-smoke:full')) &&
        nextSteps.any((step) => step.contains('USB iPhone')) &&
        nextSteps.any(
          (step) => step.contains('v4:ios-smoke:full:password-prompt'),
        ) &&
        nextSteps.any((step) => step.contains('v4:android-smoke:full')) &&
        nextSteps.any((step) => step.contains('当前未发现 Android 手机')) &&
        nextSteps.any((step) => step.contains('v4:smoke:full')) &&
        nextSteps.any(
          (step) => step.contains('v4:smoke:full:password-prompt'),
        ) &&
        nextSteps.any((step) => step.contains('v4:acceptance-final')),
    'acceptance nextSteps 必须给出 iOS 隧道、Android、密码版 full smoke 和终验命令。',
  );
  final fieldChecklist = _listAt(json, 'fieldChecklist');
  _expect(fieldChecklist.length >= 4, 'acceptance 必须给出现场补验清单。');
  _assertAcceptanceFieldChecklistContract(fieldChecklist);
  final checklistMaps = fieldChecklist.map(_mapFrom).toList(growable: false);
  _expect(
    checklistMaps.any(
          (item) =>
              item['command'] == 'npm run v4:ios-smoke:full:password-prompt',
        ) &&
        checklistMaps.any(
          (item) => item['command'] == 'npm run v4:android-smoke:full',
        ) &&
        checklistMaps.any(
          (item) => item['command'] == 'npm run v4:smoke:full:password-prompt',
        ) &&
        checklistMaps.any(
          (item) => item['command'] == 'npm run v4:acceptance-final',
        ),
    'acceptance 现场补验清单必须包含 iOS、Android、密码版全量和终验命令。',
  );
  _expect(
    checklistMaps.any(
          (item) =>
              item['command'] == 'npm run v4:ios-smoke:full:password-prompt' &&
              ('${item['proof']}'.contains('当前 iOS') ||
                  '${item['proof']}'.contains('USB iPhone')),
        ) &&
        checklistMaps.any(
          (item) =>
              item['command'] == 'npm run v4:android-smoke:full' &&
              '${item['proof']}'.contains('当前 Android'),
        ) &&
        checklistMaps.any(
          (item) =>
              item['command'] == 'npm run v4:smoke:full:password-prompt' &&
              '${item['proof']}'.contains('单平台 smoke'),
        ),
    'acceptance 现场补验清单必须把当前平台状态写入 iOS / Android / full smoke 通过标准。',
  );

  final evidence = _mapAt(json, 'evidence');
  final readiness = _mapAt(evidence, 'readiness');
  final localState = _mapAt(readiness, 'localState');
  _expect(
    localState['androidDevice'] is Map,
    'acceptance evidence 必须嵌入 Android 本机状态。',
  );
  _expect(
    localState['iosUsbMux'] is Map,
    'acceptance evidence 必须嵌入 iOS USB 本机状态。',
  );
  final batches = _listAt(readiness, 'batches');
  _expect(batches.length == 9, 'acceptance evidence 必须嵌入 Batch 0-8。');
  _expect(
    batches.any((item) => _mapFrom(item)['name'] == 'Batch 0 真源治理') &&
        batches.any(
          (item) => _mapFrom(item)['name'] == 'Batch 8 AI / MCP Core',
        ),
    'acceptance evidence 必须嵌入首尾批次。',
  );
  final readinessArtifacts = _mapAt(readiness, 'artifacts');
  _expect(
    readinessArtifacts['androidPreflightReports'] == 1,
    'acceptance evidence 必须嵌入 Android 前置诊断数量。',
  );
  _expect(
    _mapAt(readinessArtifacts, 'latestAndroidPreflight')['label'] == '有阻断',
    'acceptance evidence 必须嵌入最近 Android 前置诊断。',
  );
  _expect(
    _mapAt(readinessArtifacts, 'latestIos')['fullPassed'] == false,
    'acceptance evidence 必须嵌入最近 iOS 未完整通过状态。',
  );
  _expect(
    _mapAt(readinessArtifacts, 'latestIos')['git'] is String,
    'acceptance evidence 必须嵌入最近 iOS 提交号。',
  );
  final archive = _mapAt(evidence, 'archive');
  final counts = _mapAt(archive, 'counts');
  _expect(counts['screenshots'] == 1, 'acceptance evidence 必须嵌入截图数量。');
  _expect(counts['iosRuns'] == 1, 'fixture 下 iOS 运行数量必须为 1。');
  _expect(counts['androidRuns'] == 0, 'fixture 下 Android 运行数量必须为 0。');
  final screenshotArtifacts = _listAt(archive, 'screenshotArtifacts');
  _expect(screenshotArtifacts.length == 1, 'acceptance evidence 必须嵌入截图索引。');
  _expect(
    _mapFrom(screenshotArtifacts.single)['relativePath'] ==
        'studio-ui-fixture.png',
    'acceptance 截图索引必须保留脱敏相对路径。',
  );

  final steps = _listAt(json, 'steps');
  _expect(steps.length == 4, 'acceptance 必须包含 4 个固定步骤。');
}

const _allowedReportCommands = <String>{
  'npm run v4:ios-smoke:full',
  'npm run v4:ios-smoke:full:password-prompt',
  'npm run v4:android-smoke:full',
  'npm run v4:smoke:full',
  'npm run v4:smoke:full:password-prompt',
  'npm run v4:smoke-readiness',
  'npm run v4:smoke-archive',
  'npm run v4:acceptance-audit',
  'npm run v4:acceptance-final',
};

// 断言可见文本中的反引号命令只能来自白名单。
void _assertCommandBackticksAreWhitelisted(
  Iterable<String> steps,
  String field,
) {
  final pattern = RegExp(r'`([^`]+)`');
  for (final step in steps) {
    for (final match in pattern.allMatches(step)) {
      final command = match.group(1)?.trim();
      _expect(
        command != null && _allowedReportCommands.contains(command),
        '$field 不得输出非白名单命令：$command',
      );
    }
  }
}

// 断言最终验收 nextSteps 中的反引号命令也只能来自白名单。
void _assertAcceptanceNextStepCommandsAreWhitelisted(List<String> steps) {
  _assertCommandBackticksAreWhitelisted(steps, 'acceptance nextSteps');
}

// 断言最终验收 JSON 只输出项目内安全 smoke / 终验命令。
void _assertAcceptanceCommandsAreWhitelisted(
  List<Object?> items,
  String field,
) {
  for (final item in items) {
    final command = _mapFrom(item)['command'];
    if (command == null) continue;
    _expect(
      command is String && _allowedReportCommands.contains(command),
      'acceptance $field 不得输出非白名单命令：$command',
    );
  }
}

// 断言现场补验清单保持稳定路线：正序、无重复，执行项必须有安全命令。
void _assertAcceptanceFieldChecklistContract(List<Object?> items) {
  _assertAcceptanceCommandsAreWhitelisted(items, 'fieldChecklist');
  final seenOrders = <int>{};
  final nonCommandTitles = <String>{'清代码', '推远端', '保留报告'};
  var expectedOrder = 1;
  for (final item in items) {
    final map = _mapFrom(item);
    final order = map['order'];
    _expect(
      order is int && order > 0,
      'acceptance fieldChecklist 的 order 必须是正整数：$order',
    );
    _expect(
      seenOrders.add(order as int),
      'acceptance fieldChecklist 的 order 不得重复：$order',
    );
    _expect(
      order == expectedOrder,
      'acceptance fieldChecklist 必须按 1,2,3 连续正序输出，当前 $order，期望 $expectedOrder。',
    );
    expectedOrder += 1;

    final title = map['title'];
    _expect(
      title is String && title.trim().isNotEmpty,
      'acceptance fieldChecklist 必须有短标题。',
    );
    final command = map['command'];
    if (!nonCommandTitles.contains((title as String).trim())) {
      _expect(
        command is String && _allowedReportCommands.contains(command),
        'acceptance fieldChecklist 执行项必须携带白名单命令：$title / $command',
      );
    }
  }
}

// 断言 final acceptance Markdown 包含人工复盘区域。
void _assertAcceptanceMarkdown(String markdown, Map<String, Object?> json) {
  for (final text in <String>[
    '# V4 Final Acceptance',
    '- 工作区：',
    '- 远端：',
    '## 步骤',
    '## 结论',
    '## 现场摘要',
    '### 批次验收',
    'Batch 0 真源治理',
    'Batch 8 AI / MCP Core',
    'Android 手机',
    'iOS USB',
    'Android smoke 前置诊断',
    '最近完整冒烟',
    '留档数量',
    '截图留档',
    'studio-ui-fixture.png',
    '## 终验门禁',
    'Android smoke',
    'Full smoke',
    '## 现场补验清单',
    '通过标准',
    '## 下一步',
    '完成审计',
    '归档终验',
    'v4:ios-smoke:full',
    'v4:ios-smoke:full:password-prompt',
    'v4:android-smoke:full',
    'v4:smoke:full',
    'v4:smoke:full:password-prompt',
    'v4:acceptance-final',
  ]) {
    _expect(markdown.contains(text), 'Acceptance Markdown 必须包含：$text');
  }
  _assertAcceptanceMarkdownChecklistContract(
    markdown,
    _listAt(json, 'fieldChecklist'),
  );
}

// 断言人类阅读的 Markdown 现场清单也保持和 JSON 一致的安全路线。
void _assertAcceptanceMarkdownChecklistContract(
  String markdown,
  List<Object?> jsonItems,
) {
  final rows = _acceptanceMarkdownChecklistRows(markdown);
  _expect(rows.length >= 4, 'Acceptance Markdown 必须输出现场补验清单表格。');
  final nonCommandTitles = <String>{'清代码', '推远端', '保留报告'};
  final seenOrders = <int>{};
  var expectedOrder = 1;
  for (final row in rows) {
    _expect(row.order > 0, 'Acceptance Markdown 现场清单 order 必须为正。');
    _expect(
      seenOrders.add(row.order),
      'Acceptance Markdown 现场清单 order 不得重复：${row.order}',
    );
    _expect(
      row.order == expectedOrder,
      'Acceptance Markdown 现场清单必须连续正序，当前 ${row.order}，期望 $expectedOrder。',
    );
    expectedOrder += 1;
    _expect(row.title.isNotEmpty, 'Acceptance Markdown 现场清单标题不能为空。');
    _expect(row.proof.isNotEmpty, 'Acceptance Markdown 现场清单通过标准不能为空。');

    if (row.command != null) {
      _expect(
        _allowedReportCommands.contains(row.command),
        'Acceptance Markdown 现场清单不得输出非白名单命令：${row.command}',
      );
    }
    if (!nonCommandTitles.contains(row.title)) {
      _expect(
        row.command != null && _allowedReportCommands.contains(row.command),
        'Acceptance Markdown 执行项必须携带白名单命令：${row.title} / ${row.command}',
      );
    }
  }

  final jsonMaps = jsonItems.map(_mapFrom).toList(growable: false);
  _expect(
    rows.length == jsonMaps.length,
    'Acceptance Markdown 现场清单必须和 JSON fieldChecklist 行数一致。',
  );
  for (var index = 0; index < rows.length; index += 1) {
    final row = rows[index];
    final json = jsonMaps[index];
    _expect(
      row.order == json['order'],
      'Acceptance Markdown 第 ${index + 1} 行顺序必须和 JSON 一致。',
    );
    _expect(
      row.title == json['title'],
      'Acceptance Markdown 第 ${index + 1} 行标题必须和 JSON 一致。',
    );
    _expect(
      row.command == json['command'],
      'Acceptance Markdown 第 ${index + 1} 行命令必须和 JSON 一致。',
    );
    _expect(
      row.proof == json['proof'],
      'Acceptance Markdown 第 ${index + 1} 行通过标准必须和 JSON 一致。',
    );
  }
}

// 断言 acceptance-final 终端错误输出也给出同一条安全现场路线。
void _assertAcceptanceFinalStderrChecklistContract(
  String stderr,
  List<Object?> jsonItems,
) {
  final rows = _acceptanceFinalStderrChecklistRows(stderr);
  _expect(rows.length >= 4, 'acceptance-final stderr 必须输出现场补验清单。');
  final nonCommandTitles = <String>{'清代码', '推远端', '保留报告'};
  final seenOrders = <int>{};
  var expectedOrder = 1;
  for (final row in rows) {
    _expect(row.order > 0, 'acceptance-final stderr 现场清单 order 必须为正。');
    _expect(
      seenOrders.add(row.order),
      'acceptance-final stderr 现场清单 order 不得重复：${row.order}',
    );
    _expect(
      row.order == expectedOrder,
      'acceptance-final stderr 现场清单必须连续正序，当前 ${row.order}，期望 $expectedOrder。',
    );
    expectedOrder += 1;
    _expect(row.title.isNotEmpty, 'acceptance-final stderr 现场清单标题不能为空。');
    _expect(row.proof.isNotEmpty, 'acceptance-final stderr 通过标准不能为空。');
    if (!nonCommandTitles.contains(row.title)) {
      _expect(
        row.command != null && _allowedReportCommands.contains(row.command),
        'acceptance-final stderr 执行项必须携带白名单命令：${row.title} / ${row.command}',
      );
    }
  }

  final jsonMaps = jsonItems.map(_mapFrom).toList(growable: false);
  _expect(
    rows.length == jsonMaps.length,
    'acceptance-final stderr 现场清单必须和 JSON fieldChecklist 行数一致。',
  );
  for (var index = 0; index < rows.length; index += 1) {
    final row = rows[index];
    final json = jsonMaps[index];
    _expect(
      row.order == json['order'],
      'acceptance-final stderr 第 ${index + 1} 行顺序必须和 JSON 一致。',
    );
    _expect(
      row.title == json['title'],
      'acceptance-final stderr 第 ${index + 1} 行标题必须和 JSON 一致。',
    );
    _expect(
      row.command == json['command'],
      'acceptance-final stderr 第 ${index + 1} 行命令必须和 JSON 一致。',
    );
    _expect(
      row.proof == json['proof'],
      'acceptance-final stderr 第 ${index + 1} 行通过标准必须和 JSON 一致。',
    );
  }
}

// 提取现场补验清单表格，供 Markdown 自身合同和 JSON 一致性合同复用。
List<({String? command, int order, String proof, String title})>
_acceptanceMarkdownChecklistRows(String markdown) {
  final section = _markdownSection(markdown, '## 现场补验清单');
  final rows = <({String? command, int order, String proof, String title})>[];
  for (final line in section.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|')) continue;
    final cells = _markdownTableCells(trimmed);
    if (cells.length < 4 ||
        cells.first == '顺序' ||
        cells.first.contains('---')) {
      continue;
    }
    final order = int.tryParse(cells[0]);
    _expect(order != null, 'Acceptance Markdown 现场清单顺序必须是数字：${cells[0]}');
    rows.add((
      order: order!,
      title: cells[1],
      command: _markdownCommand(cells[2]),
      proof: cells[3],
    ));
  }
  return rows;
}

// 提取终端 stderr 的现场补验清单，避免 CLI 现场路线和报告路线漂移。
List<({String? command, int order, String proof, String title})>
_acceptanceFinalStderrChecklistRows(String stderr) {
  final section = _plainTextSection(stderr, '现场补验清单：');
  final rows = <({String? command, int order, String proof, String title})>[];
  final pattern = RegExp(r'^-\s+(\d+)\.\s+([^：]+)：([^；]+)；通过标准：(.+)$');
  for (final line in section.split('\n')) {
    final match = pattern.firstMatch(line.trim());
    if (match == null) continue;
    final command = match.group(3)?.trim();
    rows.add((
      order: int.parse(match.group(1)!),
      title: match.group(2)!.trim(),
      command: command == null || command == '无需命令' ? null : command,
      proof: match.group(4)!.trim(),
    ));
  }
  return rows;
}

// 截取指定 Markdown 二级标题到下一个二级标题之间的正文。
String _markdownSection(String markdown, String heading) {
  final start = markdown.indexOf(heading);
  _expect(start >= 0, 'Markdown 必须包含章节：$heading');
  final rest = markdown.substring(start + heading.length);
  final nextHeading = RegExp(r'\n##\s+').firstMatch(rest);
  return nextHeading == null ? rest : rest.substring(0, nextHeading.start);
}

// 截取普通文本中指定标题到下一段二级语义标题之间的正文。
String _plainTextSection(String text, String heading) {
  final start = text.indexOf(heading);
  _expect(start >= 0, '文本必须包含章节：$heading');
  final rest = text.substring(start + heading.length);
  final nextHeading = RegExp(r'\n[^-\s].+：').firstMatch(rest);
  return nextHeading == null ? rest : rest.substring(0, nextHeading.start);
}

// 解析简单 Markdown 表格行，保留单元格内文本供合同断言使用。
List<String> _markdownTableCells(String line) {
  final normalized = line.endsWith('|')
      ? line.substring(0, line.length - 1)
      : line;
  return normalized
      .substring(1)
      .split('|')
      .map((cell) => cell.trim())
      .toList(growable: false);
}

// 提取 Markdown 表格里的反引号命令；短横线代表无需命令。
String? _markdownCommand(String cell) {
  final match = RegExp(r'`([^`]+)`').firstMatch(cell);
  return match?.group(1)?.trim();
}

// 扫描生成文本，防止合同 fixture 或 readiness 输出泄露真实本机信息。
void _assertNoSensitiveText(String text) {
  final patterns = <RegExp>[
    RegExp(r'/Users/[^/\s]+'),
    RegExp(r'/private/tmp/[^\s`)]+'),
    RegExp(r'/tmp/[^\s`)]+'),
    RegExp(r'/var/folders/[^\s`)]+'),
    RegExp(r'/private/var/folders/[^\s`)]+'),
    RegExp(
      r'[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}',
    ),
    RegExp(r'\b[0-9A-Fa-f]{24,}\b'),
  ];
  for (final pattern in patterns) {
    _expect(!pattern.hasMatch(text), '生成留档包含未脱敏内容：$pattern');
  }
}

// 从 Map 中读取嵌套对象，缺失时让合同失败。
Map<String, Object?> _mapAt(Map<String, Object?> json, String key) {
  final value = json[key];
  _expect(value is Map, '$key 必须是对象。');
  return Map<String, Object?>.from(value as Map);
}

// 从 Map 中读取列表，缺失时让合同失败。
List<Object?> _listAt(Map<String, Object?> json, String key) {
  final value = json[key];
  _expect(value is List, '$key 必须是列表。');
  return List<Object?>.from(value as List);
}

// 将动态值转为对象；类型错误时返回空对象供断言失败定位。
Map<String, Object?> _mapFrom(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  return const <String, Object?>{};
}

// 将动态列表转为字符串列表，便于检查 blocker 等稳定字段。
List<String> _stringList(Object? value) {
  if (value is! Iterable) return const <String>[];
  return value.map((item) => item?.toString() ?? '').toList(growable: false);
}

// 合同断言 helper，失败时用中文说明直接退出。
void _expect(bool condition, String message) {
  if (condition) return;
  _fail(message);
}

// 裁剪子进程错误，避免终端被长日志淹没。
String _shortText(String value, {int limit = 600}) {
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= limit) return compact;
  return '${compact.substring(0, limit)}...';
}

// 统一失败出口。
Never _fail(String message) {
  stderr.writeln('V4 smoke artifact contract failed: $message');
  exit(1);
}

// 子进程结果摘要。
final class _ProcessResult {
  const _ProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

// readiness 生成物集合。
final class _ReadinessArtifacts {
  const _ReadinessArtifacts({
    required this.json,
    required this.markdown,
    required this.allText,
  });

  final Map<String, Object?> json;
  final String markdown;
  final String allText;
}

// full smoke 生成物集合。
final class _FullSmokeArtifacts {
  const _FullSmokeArtifacts({
    required this.json,
    required this.markdown,
    required this.allText,
  });

  final Map<String, Object?> json;
  final String markdown;
  final String allText;
}

// archive 生成物集合。
final class _ArchiveArtifacts {
  const _ArchiveArtifacts({
    required this.json,
    required this.markdown,
    required this.allText,
  });

  final Map<String, Object?> json;
  final String markdown;
  final String allText;
}

// final acceptance 生成物集合。
final class _AcceptanceArtifacts {
  const _AcceptanceArtifacts({
    required this.json,
    required this.markdown,
    required this.allText,
  });

  final Map<String, Object?> json;
  final String markdown;
  final String allText;
}
