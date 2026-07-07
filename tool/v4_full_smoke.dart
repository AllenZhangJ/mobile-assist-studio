import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:studio_runtime/studio_runtime.dart';

// V4 full smoke 编排 iOS 与 Android 完整真机冒烟，并始终生成汇总留档。
// 它只调用既有 Dart smoke 入口，不引入 Node 中间层，也不直接操作设备。
Future<void> main(List<String> args) async {
  final options = _FullSmokeOptions.parse(args);
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }
  if (options.skipIos && options.skipAndroid) {
    _fail('至少需要保留一个平台 smoke。');
  }
  if (!options.dryRun && !options.confirmActions) {
    _fail('完整冒烟会真实 Tap / Swipe / Input；请加 --confirm-actions 确认。');
  }

  final timestamp = DateTime.now().toUtc();
  final steps = _buildSteps(options);
  if (options.dryRun) {
    _printDryRun(steps, options);
    return;
  }

  await options.outDir.create(recursive: true);
  final resources = _FullSmokeManagedResources();
  String? failureMessage;
  try {
    final preparation = options.autoPrepare
        ? await _runAutoPreparation(options, resources)
        : _FullSmokePreparation.skipped();
    final preflight = options.skipPreflight
        ? _FullSmokePreflight.skipped()
        : await _runPreflight(options);
    final results = <_FullSmokeResult>[];

    if (preflight.hasBlockers || preparation.hasBlockers) {
      await _tryWriteAndroidPreflightFromFullSmoke(
        options: options,
        timestamp: timestamp,
        preparation: preparation,
        preflight: preflight,
      );
      final report = await _writeFullSmokeReport(
        outDir: options.outDir,
        timestamp: timestamp,
        preparation: preparation,
        preflight: preflight,
        results: const <_FullSmokeResult>[],
      );
      stdout
        ..writeln(
          '\nFull smoke report: ${_redactText(report.markdownFile.path)}',
        )
        ..writeln('Full smoke json: ${_redactText(report.jsonFile.path)}');
      final blockers = _uniqueStrings(<String>[
        ...preparation.blockerNames,
        ...preflight.blockerNames,
      ]);
      failureMessage = 'V4 full smoke 前置准备未通过：${blockers.join('、')}。';
    } else {
      for (final step in steps) {
        results.add(await _runStep(step, options.stepTimeout));
      }

      final report = await _writeFullSmokeReport(
        outDir: options.outDir,
        timestamp: timestamp,
        preparation: preparation,
        preflight: preflight,
        results: results,
      );
      stdout
        ..writeln(
          '\nFull smoke report: ${_redactText(report.markdownFile.path)}',
        )
        ..writeln('Full smoke json: ${_redactText(report.jsonFile.path)}');

      final failed = results.where((result) => result.exitCode != 0).toList();
      if (failed.isNotEmpty) {
        failureMessage =
            'V4 full smoke 未完成：${failed.map((item) => item.step.name).join('、')}。';
      }
    }
  } finally {
    await resources.stopAll();
  }
  if (failureMessage != null) {
    _fail(failureMessage);
  }
}

// 自动准备本机驱动和必要的 iOS 本机隧道。
// 该步骤只托管本次 smoke 自己启动的进程，不接管外部服务。
Future<_FullSmokePreparation> _runAutoPreparation(
  _FullSmokeOptions options,
  _FullSmokeManagedResources resources,
) async {
  final items = <_FullSmokePreparationItem>[];
  StudioProjectConfig config;
  try {
    config = StudioProjectConfig.discover();
    items.add(
      const _FullSmokePreparationItem(
        name: '项目配置',
        ok: true,
        detail: '已读取本地项目配置',
        nextStep: '-',
      ),
    );
  } on StudioProjectConfigDiscoveryException catch (error) {
    return _FullSmokePreparation(
      items: <_FullSmokePreparationItem>[
        _FullSmokePreparationItem(
          name: '项目配置',
          ok: false,
          detail: '${error.summary} ${error.nextStep}',
          nextStep: error.nextStep,
        ),
      ],
    );
  } on Object catch (error) {
    return _FullSmokePreparation(
      items: <_FullSmokePreparationItem>[
        _FullSmokePreparationItem(
          name: '项目配置',
          ok: false,
          detail: _redactText('$error'),
          nextStep: '确认配置文件可读后重试。',
        ),
      ],
    );
  }

  final driverCheck = await _checkAppiumDriversForSmoke(config, options);
  items.add(driverCheck);
  if (driverCheck.ok) {
    items.add(await _prepareAppiumForSmoke(config, options, resources));
  }
  if (driverCheck.ok &&
      !options.skipIos &&
      config.deviceSession.requiresAppiumTunnel) {
    items.add(await _prepareIosTunnelForSmoke(config, options, resources));
  } else if (driverCheck.ok && !options.skipIos) {
    items.add(
      const _FullSmokePreparationItem(
        name: 'iOS 隧道',
        ok: true,
        detail: '当前绑定手机无需本机隧道',
        nextStep: '-',
      ),
    );
  }
  if (!options.skipAndroid) {
    items.add(await _prepareAndroidForSmoke(options));
  }

  return _FullSmokePreparation(items: items);
}

// 检查当前 Appium 可见的平台 driver，避免到创建 session 时才发现缺失。
Future<_FullSmokePreparationItem> _checkAppiumDriversForSmoke(
  StudioProjectConfig config,
  _FullSmokeOptions options,
) async {
  final requiredDrivers = <String>[
    if (!options.skipIos) 'xcuitest',
    if (!options.skipAndroid) 'uiautomator2',
  ];
  if (requiredDrivers.isEmpty) {
    return const _FullSmokePreparationItem(
      name: '驱动组件',
      ok: true,
      detail: '无需平台 driver',
      nextStep: '-',
    );
  }

  final projectDirectory = _projectDirectoryForConfig(config);
  final result = await _runShortProcess(
    config.appiumProcess.executable,
    const ['driver', 'list', '--installed'],
    timeout: options.preflightTimeout,
    workingDirectory: projectDirectory.path,
    environment: config.appiumProcess.environment,
  );
  if (result.exitCode != 0) {
    return _FullSmokePreparationItem(
      name: '驱动组件',
      ok: false,
      detail: _shortProcessIssue(result),
      nextStep: '确认 Appium 可运行，并安装 iOS / Android 平台 driver。',
    );
  }

  final installed = _installedAppiumDriverNames(
    '${result.stdout}\n${result.stderr}',
  );
  final missing = requiredDrivers
      .where((driver) => !installed.contains(driver))
      .toList(growable: false);
  if (missing.isNotEmpty) {
    return _FullSmokePreparationItem(
      name: '驱动组件',
      ok: false,
      detail: '缺少 ${missing.join('、')}',
      nextStep: '运行 npm install 后重试，或检查 package.json 的 Appium driver 依赖。',
    );
  }

  return _FullSmokePreparationItem(
    name: '驱动组件',
    ok: true,
    detail: '已安装 ${requiredDrivers.join('、')}',
    nextStep: '-',
  );
}

// 准备 Appium 主服务；已有外部服务时只复用，不停止。
Future<_FullSmokePreparationItem> _prepareAppiumForSmoke(
  StudioProjectConfig config,
  _FullSmokeOptions options,
  _FullSmokeManagedResources resources,
) async {
  final statusUri = Uri(
    scheme: 'http',
    host: config.appiumServer.host,
    port: config.appiumServer.port,
    path: '/status',
  );
  final existing = await _probeHttpJson(
    statusUri,
    timeout: options.preflightTimeout,
  );
  if (existing.reachable && existing.ready == true) {
    return const _FullSmokePreparationItem(
      name: 'Appium',
      ok: true,
      detail: '已复用外部驱动服务',
      nextStep: '-',
    );
  }

  final manager = AppiumProcessManager(config: config.appiumProcess);
  resources.appium = manager;
  try {
    await manager.start();
    final ready = await _waitForHttpReady(
      statusUri,
      timeout: options.appiumPrepareTimeout,
      interval: const Duration(milliseconds: 300),
    );
    if (!ready) {
      return const _FullSmokePreparationItem(
        name: 'Appium',
        ok: false,
        detail: '驱动启动后仍未就绪',
        nextStep: '检查驱动安装、端口占用和 XCUITest driver 后重试。',
      );
    }
    return const _FullSmokePreparationItem(
      name: 'Appium',
      ok: true,
      detail: '已启动本次 smoke 托管驱动',
      nextStep: '-',
    );
  } on Object catch (error) {
    return _FullSmokePreparationItem(
      name: 'Appium',
      ok: false,
      detail: _redactText('$error'),
      nextStep: '确认驱动工具可用后重试。',
    );
  }
}

// 准备 iOS 18+ 所需的 XCUITest 本机隧道。
// 密码只从 stdin 或终端提示读取一行并写入 sudo stdin，不写入报告。
Future<_FullSmokePreparationItem> _prepareIosTunnelForSmoke(
  StudioProjectConfig config,
  _FullSmokeOptions options,
  _FullSmokeManagedResources resources,
) async {
  final udid = config.deviceSession.udid;
  if (udid == null) {
    return const _FullSmokePreparationItem(
      name: 'iOS 隧道',
      ok: false,
      detail: '手机绑定缺失',
      nextStep: '先在 Mac App 点连接设备，或更新本地项目配置。',
    );
  }

  final tunnelConfig = AppiumTunnelProcessConfig(
    appiumExecutable: config.appiumProcess.executable,
    workingDirectory: _projectDirectoryForConfig(config).path,
    environment: config.appiumProcess.environment,
    udid: udid,
  );
  final existing = await _readTunnelDevices(tunnelConfig);
  if (existing.contains(udid)) {
    return const _FullSmokePreparationItem(
      name: 'iOS 隧道',
      ok: true,
      detail: '已复用外部本机隧道',
      nextStep: '-',
    );
  }

  if (!options.adminPasswordStdin && !options.adminPasswordPrompt) {
    return const _FullSmokePreparationItem(
      name: 'iOS 隧道',
      ok: false,
      detail: '缺少启动隧道所需的本机密码',
      nextStep: '用 Mac App 点连接设备，或使用 --admin-password-prompt 后重试。',
    );
  }

  final password = options.adminPasswordPrompt
      ? await _readAdminPasswordFromPrompt()
      : await _readAdminPasswordFromStdin();
  final manager = AppiumTunnelProcessManager(config: tunnelConfig);
  resources.tunnel = manager;
  try {
    await manager.start(adminPassword: password);
    return const _FullSmokePreparationItem(
      name: 'iOS 隧道',
      ok: true,
      detail: '已启动本次 smoke 托管隧道',
      nextStep: '-',
    );
  } on Object catch (error) {
    return _FullSmokePreparationItem(
      name: 'iOS 隧道',
      ok: false,
      detail: _redactText('$error'),
      nextStep: '解锁手机，点允许；若失败请重试密码。',
    );
  }
}

// 准备 Android ADB 可见性。
// 这里只启动 ADB server 并检查授权状态，不创建 Appium 会话、不执行设备动作。
Future<_FullSmokePreparationItem> _prepareAndroidForSmoke(
  _FullSmokeOptions options,
) async {
  final startServer = await _runShortProcess('adb', const [
    'start-server',
  ], timeout: options.preflightTimeout);
  if (startServer.exitCode != 0) {
    return _FullSmokePreparationItem(
      name: 'Android 手机',
      ok: false,
      detail: _shortProcessIssue(startServer),
      nextStep: '确认 ADB 已安装并可运行，再连接一台已开启 USB 调试的手机。',
    );
  }

  final android = await _probeAndroidDevices(options.preflightTimeout);
  if (android.available && android.ready == 1) {
    return const _FullSmokePreparationItem(
      name: 'Android 手机',
      ok: true,
      detail: '已发现一台已授权 Android 手机',
      nextStep: '-',
    );
  }
  if (android.ready > 1) {
    return _FullSmokePreparationItem(
      name: 'Android 手机',
      ok: false,
      detail:
          '可用 ${android.ready}，未授权 ${android.unauthorized}，离线 ${android.offline}',
      nextStep: '只保留一台已授权 Android 手机后重试。',
    );
  }
  if (android.unauthorized > 0) {
    return _FullSmokePreparationItem(
      name: 'Android 手机',
      ok: false,
      detail:
          '可用 ${android.ready}，未授权 ${android.unauthorized}，离线 ${android.offline}',
      nextStep: '在 Android 手机上允许 USB 调试后重试。',
    );
  }
  if (android.offline > 0) {
    return _FullSmokePreparationItem(
      name: 'Android 手机',
      ok: false,
      detail:
          '可用 ${android.ready}，未授权 ${android.unauthorized}，离线 ${android.offline}',
      nextStep: '重插数据线并保持 Android 手机亮屏。',
    );
  }
  return _FullSmokePreparationItem(
    name: 'Android 手机',
    ok: false,
    detail:
        android.detail ??
        '可用 ${android.ready}，未授权 ${android.unauthorized}，离线 ${android.offline}',
    nextStep: '连接一台开启 USB 调试的 Android 手机，并在手机上允许调试。',
  );
}

// 等待 HTTP ready，供自动准备后的 Appium 服务复核。
Future<bool> _waitForHttpReady(
  Uri uri, {
  required Duration timeout,
  required Duration interval,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!DateTime.now().isAfter(deadline)) {
    final probe = await _probeHttpJson(
      uri,
      timeout: const Duration(seconds: 1),
    );
    if (probe.reachable && probe.ready == true) return true;
    if (interval > Duration.zero) {
      await Future<void>.delayed(interval);
    }
  }
  return false;
}

// 从 tunnel registry 读取设备集合；失败按空集合处理。
Future<Set<String>> _readTunnelDevices(AppiumTunnelProcessConfig config) async {
  try {
    return await defaultAppiumTunnelRegistryReader(config);
  } on Object {
    return const <String>{};
  }
}

// 从 stdin 读取一次性本机密码。
// 调用方不得打印返回值，也不得把它写入任何报告。
Future<String> _readAdminPasswordFromStdin() async {
  final line = await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .first;
  return line.trimRight();
}

// 从终端提示读取一次性本机密码，支持终端时关闭回显。
Future<String> _readAdminPasswordFromPrompt() async {
  stdout.write('Mac 密码: ');
  final canHideInput = stdin.hasTerminal;
  final previousEchoMode = canHideInput ? stdin.echoMode : true;
  if (canHideInput) stdin.echoMode = false;
  try {
    return await _readAdminPasswordFromStdin();
  } finally {
    if (canHideInput) stdin.echoMode = previousEchoMode;
    stdout.writeln();
  }
}

// 根据配置文件位置推导项目目录。
Directory _projectDirectoryForConfig(StudioProjectConfig config) {
  final configFile = File(config.sourcePath);
  final configDirectory = configFile.parent;
  return configDirectory.path.endsWith('/config')
      ? configDirectory.parent
      : Directory.current;
}

// 根据选项生成稳定的执行步骤，两个平台失败互不阻断，最后仍跑完成审计。
List<_FullSmokeStep> _buildSteps(_FullSmokeOptions options) {
  final steps = <_FullSmokeStep>[
    if (!options.skipIos)
      _FullSmokeStep(
        name: 'iOS 完整冒烟',
        executable: 'fvm',
        arguments: [
          'dart',
          'run',
          'tool/v4_ios_smoke.dart',
          '--out-dir',
          _platformOutDir(options.outDir, 'ios'),
          '--workflow-basic',
          '--allow-actions',
        ],
        workingDirectory: 'packages/studio_runtime',
      ),
    if (!options.skipAndroid)
      _FullSmokeStep(
        name: 'Android 完整冒烟',
        executable: 'fvm',
        arguments: [
          'dart',
          'run',
          'tool/v4_android_smoke.dart',
          '--out-dir',
          _platformOutDir(options.outDir, 'android'),
          '--workflow-basic',
          '--allow-actions',
        ],
        workingDirectory: 'packages/studio_runtime',
      ),
    _FullSmokeStep(
      name: '完整门禁审计',
      executable: 'fvm',
      arguments: [
        'dart',
        'run',
        'tool/v4_smoke_readiness.dart',
        '--out-dir',
        options.outDir.path,
        '--require-complete',
      ],
    ),
  ];
  return steps;
}

// 子 smoke 工具从 packages/studio_runtime 运行，默认输出目录需要相对回到根目录。
String _platformOutDir(Directory outDir, String platform) {
  final base = _trimTrailingSlash(outDir.path);
  if (base.startsWith('/')) return '$base/$platform';
  return '../../$base/$platform';
}

// 去掉路径尾部斜线，保持命令展示和文件拼接稳定。
String _trimTrailingSlash(String value) {
  var result = value.trim();
  while (result.length > 1 && result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result.isEmpty ? '.' : result;
}

// 只读前置检查，避免现场条件不足时进入真实动作。
Future<_FullSmokePreflight> _runPreflight(_FullSmokeOptions options) async {
  final needsAppium = !options.skipIos || !options.skipAndroid;
  final items = <_FullSmokePreflightItem>[];

  final appium = needsAppium
      ? await _probeHttpJson(
          Uri(scheme: 'http', host: '127.0.0.1', port: 4723, path: '/status'),
          timeout: options.preflightTimeout,
        )
      : const _HttpProbe(reachable: true, ready: true);
  if (needsAppium) {
    items.add(
      _FullSmokePreflightItem(
        name: 'Appium',
        ok: appium.reachable && appium.ready == true,
        detail: appium.statusLabel,
        nextStep: appium.reachable
            ? '确认 4723 服务 ready 后重试。'
            : '先在 Mac App 点“连接设备”，或启动本机 Appium 后重试。',
      ),
    );
  }

  if (!options.skipIos) {
    final ios = await _probeIosDevices(options.preflightTimeout);
    final tunnel = await _probeHttpJson(
      Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: 42314,
        path: '/remotexpc/tunnels',
      ),
      timeout: options.preflightTimeout,
    );
    items
      ..add(
        _FullSmokePreflightItem(
          name: 'iOS 手机',
          ok: ios.available,
          detail: ios.detail ?? '可用 ${ios.connected}，不可用 ${ios.unavailable}',
          nextStep: '连接并解锁一台 USB iPhone，再点 Mac App 的“连接设备”。',
        ),
      )
      ..add(
        _FullSmokePreflightItem(
          name: 'iOS 隧道',
          ok: tunnel.reachable && (tunnel.count ?? 0) > 0,
          detail: tunnel.count == null
              ? tunnel.statusLabel
              : '隧道数量 ${tunnel.count}',
          nextStep: '在 Mac App 点“连接设备”，输入 Mac 密码，并在手机提示时点允许。',
        ),
      );
  }

  if (!options.skipAndroid) {
    final android = await _probeAndroidDevices(options.preflightTimeout);
    items.add(
      _FullSmokePreflightItem(
        name: 'Android 手机',
        ok: android.available,
        detail:
            android.detail ??
            '可用 ${android.ready}，未授权 ${android.unauthorized}，离线 ${android.offline}',
        nextStep: '连接一台已开启 USB 调试的 Android 手机，并在手机上允许调试。',
      ),
    );
  }

  return _FullSmokePreflight(items: items);
}

// Android 纳入 full smoke 时，同步写一份 Android preflight，便于 readiness/acceptance 索引最新阻断。
Future<void> _tryWriteAndroidPreflightFromFullSmoke({
  required _FullSmokeOptions options,
  required DateTime timestamp,
  required _FullSmokePreparation preparation,
  required _FullSmokePreflight preflight,
}) async {
  if (options.skipAndroid) return;
  try {
    await _writeAndroidPreflightFromFullSmoke(
      outDir: Directory('${options.outDir.path}/android'),
      timestamp: timestamp,
      preparation: preparation,
      preflight: preflight,
    );
  } on Object catch (error) {
    stdout.writeln('Android 前置诊断留档失败：${_redactText('$error')}');
  }
}

// 把 full smoke 的 Appium/Android 准备项转换成 Android smoke preflight 同构报告。
Future<void> _writeAndroidPreflightFromFullSmoke({
  required Directory outDir,
  required DateTime timestamp,
  required _FullSmokePreparation preparation,
  required _FullSmokePreflight preflight,
}) async {
  final checks = _androidPreflightChecksFromFullSmoke(preparation, preflight);
  final ready = checks.every((check) => check.ok);
  final blockers = checks
      .where((check) => !check.ok)
      .map((check) => check.name)
      .toList(growable: false);
  final nextSteps = checks
      .where((check) => !check.ok && check.nextStep != '-')
      .map((check) => check.nextStep)
      .toSet()
      .toList(growable: false);
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'kind': 'v4AndroidSmokePreflight',
    'timestamp': timestamp.toIso8601String(),
    'source': 'full-smoke',
    'completion': <String, Object?>{
      'ready': ready,
      'label': ready ? '可运行' : '有阻断',
      'blockers': blockers,
    },
    'request': <String, Object?>{
      'allowActions': true,
      'workflowBasic': true,
      'source': 'full-smoke',
    },
    'checks': checks.map((check) => check.toJsonObject()).toList(),
    'nextSteps': nextSteps.isEmpty
        ? const <String>['继续运行 Android smoke。']
        : nextSteps,
  };
  const encoder = JsonEncoder.withIndent('  ');
  await outDir.create(recursive: true);
  final base =
      '${outDir.path}/ANDROID_SMOKE_PREFLIGHT_${_safeTimestamp(timestamp)}';
  await File(
    '$base.json',
  ).writeAsString('${encoder.convert(payload)}\n', flush: true);
  await File('$base.md').writeAsString(
    _androidPreflightMarkdown(timestamp, payload, checks),
    flush: true,
  );
}

// 从 full smoke 的多段准备结果中抽取 Android smoke 语义的两类检查。
List<_AndroidPreflightCheck> _androidPreflightChecksFromFullSmoke(
  _FullSmokePreparation preparation,
  _FullSmokePreflight preflight,
) {
  final driverItems = <_SmokeCheckView>[
    if (_preparationItem(preparation, '驱动组件') case final item?)
      _SmokeCheckView.fromPreparation(item),
    if (_preparationItem(preparation, 'Appium') case final item?)
      _SmokeCheckView.fromPreparation(item),
    if (_preflightItem(preflight, 'Appium') case final item?)
      _SmokeCheckView.fromPreflight(item),
  ];
  final androidItems = <_SmokeCheckView>[
    if (_preparationItem(preparation, 'Android 手机') case final item?)
      _SmokeCheckView.fromPreparation(item),
    if (_preflightItem(preflight, 'Android 手机') case final item?)
      _SmokeCheckView.fromPreflight(item),
  ];
  return <_AndroidPreflightCheck>[
    _combinedAndroidPreflightCheck(
      name: '驱动',
      items: driverItems,
      readyDetail: '已就绪',
      fallbackNextStep: '先运行 full smoke 自动准备驱动，或在 Mac App 点连接设备。',
    ),
    _combinedAndroidPreflightCheck(
      name: '安卓手机',
      items: androidItems,
      readyDetail: '已发现一台已授权 Android 手机',
      fallbackNextStep: '连接一台已开启 USB 调试的 Android 手机，并在手机上允许调试。',
    ),
  ];
}

// 合并同一语义下的多个检查来源，任何来源阻断都会进入阻断态。
_AndroidPreflightCheck _combinedAndroidPreflightCheck({
  required String name,
  required List<_SmokeCheckView> items,
  required String readyDetail,
  required String fallbackNextStep,
}) {
  final firstBlocker = _firstBlockingSmokeCheck(items);
  if (firstBlocker != null) {
    return _AndroidPreflightCheck(
      name: name,
      ok: false,
      detail: firstBlocker.detail,
      nextStep: firstBlocker.nextStep,
    );
  }
  if (items.isEmpty) {
    return _AndroidPreflightCheck(
      name: name,
      ok: false,
      detail: '未执行检查',
      nextStep: fallbackNextStep,
    );
  }
  return _AndroidPreflightCheck(
    name: name,
    ok: true,
    detail: readyDetail,
    nextStep: '-',
  );
}

// 返回第一个阻断检查；没有阻断时返回 null。
_SmokeCheckView? _firstBlockingSmokeCheck(List<_SmokeCheckView> items) {
  for (final item in items) {
    if (!item.ok) return item;
  }
  return null;
}

// 生成 Android preflight Markdown，与 Android smoke CLI 的报告结构保持一致。
String _androidPreflightMarkdown(
  DateTime timestamp,
  Map<String, Object?> payload,
  List<_AndroidPreflightCheck> checks,
) {
  final completion = payload['completion'] as Map<String, Object?>;
  final request = payload['request'] as Map<String, Object?>;
  final nextSteps = (payload['nextSteps'] as List<Object?>)
      .map((step) => step.toString())
      .toList(growable: false);
  final buffer = StringBuffer()
    ..writeln('# V4 Android Smoke Preflight')
    ..writeln()
    ..writeln('- 时间：${timestamp.toIso8601String()}')
    ..writeln('- 来源：full smoke')
    ..writeln('- 结果：${completion['label']}')
    ..writeln('- 动作：${request['allowActions'] == true ? '允许' : '未允许'}')
    ..writeln('- 流程：${request['workflowBasic'] == true ? '基础流程' : '仅会话截图'}')
    ..writeln()
    ..writeln('## 检查')
    ..writeln()
    ..writeln('| 项目 | 状态 | 说明 | 下一步 |')
    ..writeln('|---|---|---|---|');
  for (final check in checks) {
    buffer.writeln(
      '| ${check.name} | ${check.ok ? '通过' : '阻断'} | ${check.detail} | ${check.nextStep} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('## 下一步')
    ..writeln();
  for (final step in nextSteps) {
    buffer.writeln('- $step');
  }
  return buffer.toString();
}

// 按名称读取自动准备项；不存在时返回 null。
_FullSmokePreparationItem? _preparationItem(
  _FullSmokePreparation preparation,
  String name,
) {
  for (final item in preparation.items) {
    if (item.name == name) return item;
  }
  return null;
}

// 按名称读取前置检查项；不存在时返回 null。
_FullSmokePreflightItem? _preflightItem(
  _FullSmokePreflight preflight,
  String name,
) {
  for (final item in preflight.items) {
    if (item.name == name) return item;
  }
  return null;
}

// 探测 HTTP JSON 端点，保持短超时，避免 preflight 卡住。
Future<_HttpProbe> _probeHttpJson(Uri uri, {required Duration timeout}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    final body = await utf8.decodeStream(response).timeout(timeout);
    final decoded = _safeJsonDecode(body);
    return _HttpProbe(
      reachable: true,
      statusCode: response.statusCode,
      ready: _jsonLooksReady(decoded),
      count: _jsonTunnelCount(decoded),
    );
  } on Object {
    return const _HttpProbe(reachable: false);
  } finally {
    client.close(force: true);
  }
}

// 探测当前 iOS 设备数量，只保留状态统计，不写设备标识。
Future<_IosProbe> _probeIosDevices(Duration timeout) async {
  final result = await _runShortProcess('xcrun', const [
    'devicectl',
    'list',
    'devices',
  ], timeout: timeout);
  if (result.exitCode != 0) {
    return _IosProbe(available: false, detail: _shortProcessIssue(result));
  }
  final lines = result.stdout
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  final deviceLines = lines
      .where((line) => line.contains('iPhone') || line.contains('iPad'))
      .toList(growable: false);
  final connected = deviceLines
      .where(
        (line) => line.contains(' connected ') || line.contains(' available '),
      )
      .length;
  final unavailable = deviceLines.length - connected;
  return _IosProbe(
    available: connected > 0,
    connected: connected,
    unavailable: unavailable < 0 ? 0 : unavailable,
  );
}

// 探测当前 Android 设备数量，只保留状态统计，不写 serial。
Future<_AndroidProbe> _probeAndroidDevices(Duration timeout) async {
  final result = await _runShortProcess('adb', const [
    'devices',
  ], timeout: timeout);
  if (result.exitCode != 0) {
    return _AndroidProbe(available: false, detail: _shortProcessIssue(result));
  }
  var ready = 0;
  var unauthorized = 0;
  var offline = 0;
  for (final line in result.stdout.split('\n').skip(1)) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    switch (parts[1]) {
      case 'device':
        ready += 1;
      case 'unauthorized':
        unauthorized += 1;
      case 'offline':
        offline += 1;
    }
  }
  return _AndroidProbe(
    available: ready > 0,
    ready: ready,
    unauthorized: unauthorized,
    offline: offline,
  );
}

// 执行短命令并裁剪输出，用于 preflight 只读探测。
Future<_ProcessProbe> _runShortProcess(
  String executable,
  List<String> arguments, {
  required Duration timeout,
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  try {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: {
        ...Platform.environment,
        ...?environment,
        'DART_SUPPRESS_ANALYTICS': 'true',
        'FLUTTER_SUPPRESS_ANALYTICS': 'true',
      },
    ).timeout(timeout);
    return _ProcessProbe(
      exitCode: result.exitCode,
      stdout: _redactText('${result.stdout}'),
      stderr: _redactText('${result.stderr}'),
    );
  } on TimeoutException {
    return const _ProcessProbe(exitCode: 124, stderr: 'timeout');
  } on Object catch (error) {
    return _ProcessProbe(exitCode: 1, stderr: _redactText('$error'));
  }
}

// 从 appium driver list --installed 输出中提取 driver 名称。
Set<String> _installedAppiumDriverNames(String output) {
  final names = <String>{};
  for (final line in output.split(RegExp(r'\r?\n'))) {
    final match = RegExp(r'-\s+([a-zA-Z0-9_-]+)@').firstMatch(line.trim());
    if (match == null) continue;
    final name = match.group(1)?.trim();
    if (name != null && name.isNotEmpty) names.add(name);
  }
  return names;
}

// 执行单个步骤并捕获输出，超时也会形成可写入报告的结果。
Future<_FullSmokeResult> _runStep(_FullSmokeStep step, Duration timeout) async {
  final startedAt = DateTime.now().toUtc();
  stdout.writeln('\n== ${step.name} ==');
  stdout.writeln(_redactText(step.commandLine));

  try {
    final process = await Process.start(
      step.executable,
      step.arguments,
      workingDirectory: step.workingDirectory,
      environment: {
        ...Platform.environment,
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

    var timedOut = false;
    var exitCode = 0;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      exitCode = 124;
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
        try {
          await process.exitCode.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          // SIGKILL 后仍未结算时不再阻塞 full smoke 汇总。
        }
      }
    }
    await _awaitOutputFlush(stdoutDone, stderrDone);

    final finishedAt = DateTime.now().toUtc();
    final result = _FullSmokeResult(
      step: step,
      exitCode: exitCode,
      stdoutText: _redactText(stdoutBuffer.toString()),
      stderrText: _redactText(_stderrWithTimeoutNote(stderrBuffer, timedOut)),
      startedAt: startedAt,
      finishedAt: finishedAt,
      timedOut: timedOut,
    );
    stdout.writeln('${step.name}：${result.statusLabel}');
    return result;
  } on ProcessException catch (error) {
    final finishedAt = DateTime.now().toUtc();
    stdout.writeln('${step.name}：启动失败');
    return _FullSmokeResult(
      step: step,
      exitCode: 127,
      stdoutText: '',
      stderrText: _redactText(error.message),
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
  }
}

// 等待输出流关闭；进程已结束后仍给极短缓冲时间，避免报告丢尾部错误。
Future<void> _awaitOutputFlush(
  Future<void> stdoutDone,
  Future<void> stderrDone,
) async {
  try {
    await Future.wait([
      stdoutDone,
      stderrDone,
    ]).timeout(const Duration(seconds: 2));
  } on Object {
    // 输出收尾失败不应覆盖主进程结果；报告会保留已收集内容。
  }
}

// 超时时在 stderr 摘要里明确写入由编排器终止，便于现场复盘。
String _stderrWithTimeoutNote(StringBuffer buffer, bool timedOut) {
  final stderrText = buffer.toString();
  if (!timedOut) return stderrText;
  final note = 'step timeout; process terminated by V4 full smoke runner';
  if (stderrText.trim().isEmpty) return note;
  return '$note\n$stderrText';
}

// 保留顺序去重，避免同一阻断在自动准备和前置检查中重复展示。
List<String> _uniqueStrings(Iterable<String> values) {
  final seen = <String>{};
  return values.where(seen.add).toList(growable: false);
}

// dry-run 只展示将要执行的命令，用于本地确认和 CI 语法检查。
void _printDryRun(List<_FullSmokeStep> steps, _FullSmokeOptions options) {
  stdout.writeln('V4 full smoke dry-run');
  stdout.writeln('- 自动准备: ${options.autoPrepare ? '启用' : '跳过'}');
  if (options.autoPrepare &&
      !options.skipIos &&
      !options.adminPasswordStdin &&
      !options.adminPasswordPrompt) {
    stdout.writeln(
      '- iOS 隧道密码: 未读取，需要 Mac App 已连接或改用 password-prompt / password-stdin 入口',
    );
  }
  if (options.autoPrepare && !options.skipAndroid) {
    stdout.writeln('- Android 准备: 启动 ADB server 并检查唯一已授权手机');
  }
  for (final step in steps) {
    stdout.writeln('- ${step.name}: ${_redactText(step.commandLine)}');
  }
}

// 写入 full smoke 汇总报告，调用方负责按结果决定退出码。
Future<_FullSmokeReportFiles> _writeFullSmokeReport({
  required Directory outDir,
  required DateTime timestamp,
  required _FullSmokePreparation preparation,
  required _FullSmokePreflight preflight,
  required List<_FullSmokeResult> results,
}) async {
  final reportBase = '${outDir.path}/FULL_SMOKE_${_safeTimestamp(timestamp)}';
  final markdownFile = File('$reportBase.md');
  final jsonFile = File('$reportBase.json');
  await markdownFile.writeAsString(
    _summaryMarkdown(
      timestamp: timestamp,
      preparation: preparation,
      preflight: preflight,
      results: results,
    ),
    flush: true,
  );
  await jsonFile.writeAsString(
    _summaryJsonString(
      timestamp: timestamp,
      preparation: preparation,
      preflight: preflight,
      results: results,
    ),
    flush: true,
  );
  return _FullSmokeReportFiles(markdownFile: markdownFile, jsonFile: jsonFile);
}

// 生成本地 Markdown 汇总，保留失败原因但脱敏路径、设备号和 session。
String _summaryMarkdown({
  required DateTime timestamp,
  required _FullSmokePreparation preparation,
  required _FullSmokePreflight preflight,
  required List<_FullSmokeResult> results,
}) {
  final buffer = StringBuffer()
    ..writeln('# V4 Full Smoke')
    ..writeln()
    ..writeln('- 时间：${timestamp.toIso8601String()}')
    ..writeln('- 动作：真实 Tap / Swipe / Input + 基础 Project DSL workflow')
    ..writeln('- 自动准备：${preparation.statusLabel}')
    ..writeln('- 前置检查：${preflight.statusLabel}')
    ..writeln()
    ..writeln('## 自动准备')
    ..writeln();
  if (preparation.skipped) {
    buffer.writeln('- 已跳过自动准备。');
  } else {
    buffer
      ..writeln('| 项目 | 结果 | 说明 | 下一步 |')
      ..writeln('|---|---|---|---|');
    for (final item in preparation.items) {
      buffer.writeln(
        '| ${item.name} | ${item.ok ? '通过' : '阻断'} | ${item.detail} | ${item.ok ? '-' : item.nextStep} |',
      );
    }
  }
  buffer
    ..writeln()
    ..writeln('## 前置检查')
    ..writeln();
  if (preflight.skipped) {
    buffer.writeln('- 已跳过前置检查。');
  } else {
    buffer
      ..writeln('| 项目 | 结果 | 说明 | 下一步 |')
      ..writeln('|---|---|---|---|');
    for (final item in preflight.items) {
      buffer.writeln(
        '| ${item.name} | ${item.ok ? '通过' : '阻断'} | ${item.detail} | ${item.ok ? '-' : item.nextStep} |',
      );
    }
  }
  buffer
    ..writeln()
    ..writeln('## 执行步骤')
    ..writeln()
    ..writeln('| 步骤 | 结果 | 退出码 | 耗时 |')
    ..writeln('|---|---|---:|---:|');
  if (results.isEmpty) {
    buffer.writeln('| 未执行 | 前置检查未通过 | 0 | 0s |');
  } else {
    for (final result in results) {
      buffer.writeln(
        '| ${result.step.name} | ${result.statusLabel} | ${result.exitCode} | ${result.duration.inSeconds}s |',
      );
    }
  }
  buffer.writeln();

  for (final result in results) {
    buffer
      ..writeln('## ${result.step.name}')
      ..writeln()
      ..writeln('- 命令：`${_redactText(result.step.commandLine)}`')
      ..writeln('- 开始：${result.startedAt.toIso8601String()}')
      ..writeln('- 结束：${result.finishedAt.toIso8601String()}')
      ..writeln('- 结果：${result.statusLabel}')
      ..writeln();
    _writeOutputBlock(buffer, 'stdout', result.stdoutText);
    _writeOutputBlock(buffer, 'stderr', result.stderrText);
  }
  return buffer.toString();
}

// 生成机器可读的 full smoke JSON，输出同样经过脱敏和裁剪。
String _summaryJsonString({
  required DateTime timestamp,
  required _FullSmokePreparation preparation,
  required _FullSmokePreflight preflight,
  required List<_FullSmokeResult> results,
}) {
  final failed = results.where((result) => result.exitCode != 0).toList();
  final complete =
      !preparation.hasBlockers &&
      !preflight.hasBlockers &&
      results.isNotEmpty &&
      failed.isEmpty;
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'kind': 'v4FullSmoke',
    'timestamp': timestamp.toIso8601String(),
    'completion': <String, Object?>{
      'complete': complete,
      'label': complete
          ? '完整通过'
          : preparation.hasBlockers || preflight.hasBlockers
          ? '前置检查阻断'
          : '执行未完成',
      'failedSteps': failed.map((result) => result.step.name).toList(),
    },
    'preparation': preparation.toJsonObject(),
    'preflight': preflight.toJsonObject(),
    'steps': results.map((result) => result.toJsonObject()).toList(),
  };
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert(payload)}\n';
}

// 写入裁剪后的输出块，避免报告被长日志淹没。
void _writeOutputBlock(StringBuffer buffer, String title, String value) {
  final trimmed = _shortBlock(value);
  if (trimmed.isEmpty) return;
  buffer
    ..writeln('### $title')
    ..writeln()
    ..writeln('```text')
    ..writeln(trimmed.replaceAll('```', '` ` `'))
    ..writeln('```')
    ..writeln();
}

// 裁剪长输出，保留开头和结尾，便于定位失败。
String _shortBlock(String value, {int limit = 2200}) {
  final trimmed = value.trim();
  if (trimmed.length <= limit) return trimmed;
  final head = trimmed.substring(0, limit ~/ 2);
  final tail = trimmed.substring(trimmed.length - (limit ~/ 2));
  return '$head\n...\n$tail';
}

// 安全 JSON 解析，失败时返回 null。
Object? _safeJsonDecode(String body) {
  try {
    return jsonDecode(body);
  } on Object {
    return null;
  }
}

// 判断 Appium status 是否 ready。
bool? _jsonLooksReady(Object? decoded) {
  if (decoded is! Map) return null;
  final value = decoded['value'];
  if (value is Map && value['ready'] is bool) return value['ready'] as bool;
  if (decoded['ready'] is bool) return decoded['ready'] as bool;
  return null;
}

// 读取 XCUITest tunnel registry 里的隧道数量。
int? _jsonTunnelCount(Object? decoded) {
  if (decoded is! Map) return null;
  final tunnels = decoded['tunnels'];
  if (tunnels is Map) return tunnels.length;
  return null;
}

// 裁剪进程问题说明，避免报告过长。
String _shortProcessIssue(_ProcessProbe result) {
  final raw = result.stderr.trim().isEmpty ? result.stdout : result.stderr;
  if (raw.trim().isEmpty) return 'exit ${result.exitCode}';
  final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 120) return compact;
  return '${compact.substring(0, 120)}...';
}

// 脱敏本机路径、长设备号和 UUID。
String _redactText(String value) {
  return value
      .replaceAll(RegExp(r'/Users/[^/\s]+'), '<home>')
      .replaceAll(RegExp(r'/private/tmp/[^\s`)]+'), '<tmp>')
      .replaceAll(RegExp(r'/tmp/[^\s`)]+'), '<tmp>')
      .replaceAll(RegExp(r'/var/folders/[^\s`)]+'), '<tmp>')
      .replaceAll(RegExp(r'/private/var/folders/[^\s`)]+'), '<tmp>')
      .replaceAll(
        RegExp(
          r'[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}',
        ),
        '<device-id>',
      )
      .replaceAll(RegExp(r'\b[0-9A-Fa-f]{24,}\b'), '<device-id>');
}

// 生成文件名安全时间戳。
String _safeTimestamp(DateTime value) {
  return value.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
}

// full smoke 前置检查集合。
final class _FullSmokePreflight {
  const _FullSmokePreflight({required this.items, this.skipped = false});

  factory _FullSmokePreflight.skipped() {
    return const _FullSmokePreflight(
      items: <_FullSmokePreflightItem>[],
      skipped: true,
    );
  }

  final List<_FullSmokePreflightItem> items;
  final bool skipped;

  bool get hasBlockers => !skipped && items.any((item) => !item.ok);

  Iterable<String> get blockerNames sync* {
    for (final item in items) {
      if (!item.ok) yield item.name;
    }
  }

  String get statusLabel {
    if (skipped) return '已跳过';
    return hasBlockers ? '有阻断' : '通过';
  }

  // 转成机器可读前置检查结果。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'skipped': skipped,
      'status': statusLabel,
      'hasBlockers': hasBlockers,
      'blockers': blockerNames.toList(),
      'items': items.map((item) => item.toJsonObject()).toList(),
    };
  }
}

// full smoke 自动准备集合。
final class _FullSmokePreparation {
  const _FullSmokePreparation({required this.items, this.skipped = false});

  factory _FullSmokePreparation.skipped() {
    return const _FullSmokePreparation(
      items: <_FullSmokePreparationItem>[],
      skipped: true,
    );
  }

  final List<_FullSmokePreparationItem> items;
  final bool skipped;

  bool get hasBlockers => !skipped && items.any((item) => !item.ok);

  Iterable<String> get blockerNames sync* {
    for (final item in items) {
      if (!item.ok) yield item.name;
    }
  }

  String get statusLabel {
    if (skipped) return '已跳过';
    return hasBlockers ? '有阻断' : '通过';
  }

  // 转成机器可读自动准备结果。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'skipped': skipped,
      'status': statusLabel,
      'hasBlockers': hasBlockers,
      'blockers': blockerNames.toList(),
      'items': items.map((item) => item.toJsonObject()).toList(),
    };
  }
}

// full smoke 自动准备单项。
final class _FullSmokePreparationItem {
  const _FullSmokePreparationItem({
    required this.name,
    required this.ok,
    required this.detail,
    required this.nextStep,
  });

  final String name;
  final bool ok;
  final String detail;
  final String nextStep;

  // 转成机器可读自动准备单项。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'name': name,
      'ok': ok,
      'detail': detail,
      'nextStep': ok ? null : nextStep,
    };
  }
}

// full smoke 托管资源集合，只释放本工具启动的进程。
final class _FullSmokeManagedResources {
  AppiumProcessManager? appium;
  AppiumTunnelProcessManager? tunnel;

  // 停止本次 full smoke 自动准备启动的进程。
  Future<void> stopAll() async {
    await tunnel?.stop();
    await appium?.stop();
  }
}

// full smoke 前置检查单项。
final class _FullSmokePreflightItem {
  const _FullSmokePreflightItem({
    required this.name,
    required this.ok,
    required this.detail,
    required this.nextStep,
  });

  final String name;
  final bool ok;
  final String detail;
  final String nextStep;

  // 转成机器可读前置检查单项。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'name': name,
      'ok': ok,
      'detail': detail,
      'nextStep': ok ? null : nextStep,
    };
  }
}

// full smoke 报告文件集合。
final class _FullSmokeReportFiles {
  const _FullSmokeReportFiles({
    required this.markdownFile,
    required this.jsonFile,
  });

  final File markdownFile;
  final File jsonFile;
}

// HTTP 探测结果。
final class _HttpProbe {
  const _HttpProbe({
    required this.reachable,
    this.statusCode,
    this.ready,
    this.count,
  });

  final bool reachable;
  final int? statusCode;
  final bool? ready;
  final int? count;

  String get statusLabel {
    if (!reachable) return '不可达';
    if (ready != null) return ready! ? '就绪' : '未就绪';
    if (count != null) return count! > 0 ? '有隧道' : '无隧道';
    return statusCode == null ? '未知' : 'HTTP $statusCode';
  }
}

// iOS 设备探测结果。
final class _IosProbe {
  const _IosProbe({
    required this.available,
    this.connected = 0,
    this.unavailable = 0,
    this.detail,
  });

  final bool available;
  final int connected;
  final int unavailable;
  final String? detail;
}

// Android 设备探测结果。
final class _AndroidProbe {
  const _AndroidProbe({
    required this.available,
    this.ready = 0,
    this.unauthorized = 0,
    this.offline = 0,
    this.detail,
  });

  final bool available;
  final int ready;
  final int unauthorized;
  final int offline;
  final String? detail;
}

// Android preflight 同构报告中的单项检查。
final class _AndroidPreflightCheck {
  const _AndroidPreflightCheck({
    required this.name,
    required this.ok,
    required this.detail,
    required this.nextStep,
  });

  final String name;
  final bool ok;
  final String detail;
  final String nextStep;

  // 转成 Android smoke preflight 兼容的机器可读结构。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'name': name,
      'ok': ok,
      'status': ok ? '通过' : '阻断',
      'detail': detail,
      'nextStep': nextStep,
    };
  }
}

// full smoke 准备项和前置项的统一只读视图。
final class _SmokeCheckView {
  const _SmokeCheckView({
    required this.ok,
    required this.detail,
    required this.nextStep,
  });

  factory _SmokeCheckView.fromPreparation(_FullSmokePreparationItem item) {
    return _SmokeCheckView(
      ok: item.ok,
      detail: item.detail,
      nextStep: item.ok ? '-' : item.nextStep,
    );
  }

  factory _SmokeCheckView.fromPreflight(_FullSmokePreflightItem item) {
    return _SmokeCheckView(
      ok: item.ok,
      detail: item.detail,
      nextStep: item.ok ? '-' : item.nextStep,
    );
  }

  final bool ok;
  final String detail;
  final String nextStep;
}

// 进程探测结果。
final class _ProcessProbe {
  const _ProcessProbe({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

// V4 full smoke 参数。
final class _FullSmokeOptions {
  const _FullSmokeOptions({
    required this.outDir,
    required this.stepTimeout,
    required this.preflightTimeout,
    required this.appiumPrepareTimeout,
    required this.confirmActions,
    required this.autoPrepare,
    required this.adminPasswordStdin,
    required this.adminPasswordPrompt,
    required this.skipIos,
    required this.skipAndroid,
    required this.skipPreflight,
    required this.dryRun,
    required this.help,
  });

  final Directory outDir;
  final Duration stepTimeout;
  final Duration preflightTimeout;
  final Duration appiumPrepareTimeout;
  final bool confirmActions;
  final bool autoPrepare;
  final bool adminPasswordStdin;
  final bool adminPasswordPrompt;
  final bool skipIos;
  final bool skipAndroid;
  final bool skipPreflight;
  final bool dryRun;
  final bool help;

  // 解析命令行参数。
  static _FullSmokeOptions parse(List<String> args) {
    var outDir = Directory('recordings/v4-smoke');
    var stepTimeoutSeconds = 300;
    var preflightTimeoutSeconds = 4;
    var appiumPrepareTimeoutSeconds = 15;
    var confirmActions = false;
    var autoPrepare = false;
    var adminPasswordStdin = false;
    var adminPasswordPrompt = false;
    var skipIos = false;
    var skipAndroid = false;
    var skipPreflight = false;
    var dryRun = false;
    var help = false;

    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      switch (arg) {
        case '--help':
        case '-h':
          help = true;
        case '--out-dir':
          outDir = Directory(_nextValue(args, index, arg));
          index += 1;
        case '--step-timeout':
          stepTimeoutSeconds = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--preflight-timeout':
          preflightTimeoutSeconds = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--appium-prepare-timeout':
          appiumPrepareTimeoutSeconds = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--confirm-actions':
          confirmActions = true;
        case '--auto-prepare':
          autoPrepare = true;
        case '--admin-password-stdin':
          adminPasswordStdin = true;
        case '--admin-password-prompt':
          adminPasswordPrompt = true;
        case '--skip-ios':
          skipIos = true;
        case '--skip-android':
          skipAndroid = true;
        case '--skip-preflight':
          skipPreflight = true;
        case '--dry-run':
          dryRun = true;
        default:
          throw ArgumentError('未知参数：$arg');
      }
    }
    if (adminPasswordPrompt && adminPasswordStdin) {
      throw ArgumentError(
        '--admin-password-prompt 和 --admin-password-stdin 不能同时使用。',
      );
    }

    return _FullSmokeOptions(
      outDir: outDir,
      stepTimeout: Duration(seconds: stepTimeoutSeconds),
      preflightTimeout: Duration(seconds: preflightTimeoutSeconds),
      appiumPrepareTimeout: Duration(seconds: appiumPrepareTimeoutSeconds),
      confirmActions: confirmActions,
      autoPrepare: autoPrepare,
      adminPasswordStdin: adminPasswordStdin,
      adminPasswordPrompt: adminPasswordPrompt,
      skipIos: skipIos,
      skipAndroid: skipAndroid,
      skipPreflight: skipPreflight,
      dryRun: dryRun,
      help: help,
    );
  }
}

// 命令行参数读取 helper。
String _nextValue(List<String> args, int index, String name) {
  if (index + 1 >= args.length) {
    throw ArgumentError('$name 缺少参数值。');
  }
  return args[index + 1];
}

// 单个 full smoke 执行步骤。
final class _FullSmokeStep {
  const _FullSmokeStep({
    required this.name,
    required this.executable,
    required this.arguments,
    this.workingDirectory,
  });

  final String name;
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;

  String get commandLine {
    final command = [executable, ...arguments].join(' ');
    if (workingDirectory == null) return command;
    return 'cd $workingDirectory && $command';
  }

  // 转成机器可读步骤定义，命令仅用于审计展示。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{'name': name, 'command': _redactText(commandLine)};
  }
}

// 单个步骤的脱敏执行结果。
final class _FullSmokeResult {
  const _FullSmokeResult({
    required this.step,
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
    required this.startedAt,
    required this.finishedAt,
    this.timedOut = false,
  });

  final _FullSmokeStep step;
  final int exitCode;
  final String stdoutText;
  final String stderrText;
  final DateTime startedAt;
  final DateTime finishedAt;
  final bool timedOut;

  Duration get duration => finishedAt.difference(startedAt);

  String get statusLabel {
    if (timedOut) return '超时';
    return exitCode == 0 ? '通过' : '失败';
  }

  // 转成机器可读步骤结果，长输出只保留裁剪后的预览。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'step': step.toJsonObject(),
      'status': statusLabel,
      'exitCode': exitCode,
      'timedOut': timedOut,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'stdoutPreview': _shortBlock(stdoutText),
      'stderrPreview': _shortBlock(stderrText),
    };
  }
}

// 统一失败出口，保证本机和 CI 中表现一致。
Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

const _usage = '''
V4 full smoke

用法：
  fvm dart run tool/v4_full_smoke.dart --confirm-actions [选项]

选项：
  --out-dir <path>          结果目录，默认 recordings/v4-smoke
  --step-timeout <seconds>  单个平台 smoke 超时，默认 300
  --preflight-timeout <s>   单项前置检查超时，默认 4
  --appium-prepare-timeout <s>
                          自动等待驱动就绪超时，默认 15
  --confirm-actions         确认执行真实 Tap / Swipe / Input
  --auto-prepare            先自动准备本机驱动和必要隧道
  --admin-password-stdin    从 stdin 读取一次性 Mac 密码用于启动隧道
  --admin-password-prompt   从终端隐藏输入一次性 Mac 密码用于启动隧道
  --skip-ios                跳过 iOS 完整冒烟
  --skip-android            跳过 Android 完整冒烟
  --skip-preflight          跳过只读前置检查
  --dry-run                 只展示命令，不执行
  --help                    查看帮助
''';
