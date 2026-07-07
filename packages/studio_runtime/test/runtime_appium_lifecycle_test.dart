// ignore_for_file: unused_import, unnecessary_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime Appium 进程、依赖探测和连接等待回归。
// 每个文件只覆盖一个 Runtime 子域，保持失败定位清晰。
void main() {
  test('AppiumProcessManager starts once and stops safely', () async {
    final fake = FakeProcessHandle(pid: 4242);
    var starts = 0;
    Map<String, String>? observedEnvironment;
    final manager = AppiumProcessManager(
      starter: (executable, arguments, {environment}) async {
        starts += 1;
        observedEnvironment = environment;
        expect(executable, 'appium');
        expect(arguments, contains('--address'));
        expect(arguments, contains('127.0.0.1'));
        return fake;
      },
    );

    expect(await manager.start(), 4242);
    expect(await manager.start(), 4242);
    expect(starts, 1);
    expect(manager.isRunning, isTrue);
    expect(
      observedEnvironment,
      containsPair('APPIUM_XCUITEST_PREFER_DEVICECTL', 'true'),
    );

    await manager.stop();

    expect(fake.killed, isTrue);
    expect(manager.isRunning, isFalse);
  });

  test(
    'ScopedAppiumProcessCleaner only targets configured Appium port',
    () async {
      final fake = FakeProcessHandle(pid: 4200);
      String? observedExecutable;
      List<String>? observedArguments;
      Map<String, String>? observedEnvironment;
      final cleaner = ScopedAppiumProcessCleaner(
        starter: (executable, arguments, {environment}) async {
          observedExecutable = executable;
          observedArguments = arguments;
          observedEnvironment = environment;
          fake.kill();
          return fake;
        },
      );

      await cleaner.cleanStaleAppium(
        config: const AppiumProcessConfig(host: '127.0.0.1', port: 4723),
      );

      expect(observedExecutable, '/usr/bin/pkill');
      expect(observedArguments, hasLength(2));
      expect(observedArguments, contains('-f'));
      expect(observedArguments!.last, contains('appium'));
      expect(observedArguments!.last, contains('--address 127\\.0\\.0\\.1'));
      expect(observedArguments!.last, contains('--port 4723'));
      expect(observedArguments!.last, isNot(contains('tunnel-creation')));
      expect(
        observedEnvironment,
        containsPair('APPIUM_XCUITEST_PREFER_DEVICECTL', 'true'),
      );
    },
  );

  test(
    'AppiumTunnelProcessManager starts sudo tunnel with stdin password',
    () async {
      final fake = FakeTunnelProcessHandle(pid: 5252);
      String? observedExecutable;
      List<String>? observedArguments;
      String? observedWorkingDirectory;
      Map<String, String>? observedEnvironment;
      final manager = AppiumTunnelProcessManager(
        config: const AppiumTunnelProcessConfig(
          appiumExecutable: '/project/node_modules/.bin/appium',
          workingDirectory: '/project',
          udid: 'device-1',
        ),
        starter:
            (executable, arguments, {workingDirectory, environment}) async {
              observedExecutable = executable;
              observedArguments = arguments;
              observedWorkingDirectory = workingDirectory;
              observedEnvironment = environment;
              return fake;
            },
        registryReader: (_) async => {'device-1'},
        settleDelay: Duration.zero,
      );

      final pid = await manager.start(adminPassword: 'mac password');
      await manager.stop();

      expect(pid, 5252);
      expect(observedExecutable, '/usr/bin/sudo');
      expect(observedArguments, containsAllInOrder(['-S', '-p', '']));
      expect(observedArguments, contains('/project/node_modules/.bin/appium'));
      expect(
        observedArguments,
        containsAllInOrder(['driver', 'run', 'xcuitest']),
      );
      expect(
        observedArguments,
        containsAllInOrder(['--tunnel-registry-port', '42314']),
      );
      expect(observedArguments, containsAllInOrder(['--udid', 'device-1']));
      expect(observedWorkingDirectory, '/project');
      expect(
        observedEnvironment,
        containsPair('APPIUM_XCUITEST_PREFER_DEVICECTL', 'true'),
      );
      expect(fake.inputLines, ['mac password']);
      expect(fake.inputClosed, isTrue);
      expect(fake.killed, isTrue);
    },
  );

  test(
    'AppiumTunnelProcessManager fails when registry never publishes device',
    () async {
      final fake = FakeTunnelProcessHandle(pid: 5253);
      var waitingEvents = 0;
      final manager = AppiumTunnelProcessManager(
        config: const AppiumTunnelProcessConfig(udid: 'device-1'),
        starter:
            (executable, arguments, {workingDirectory, environment}) async {
              return fake;
            },
        registryReader: (_) async => const <String>{},
        settleDelay: Duration.zero,
        readinessTimeout: const Duration(milliseconds: 1),
        readinessInterval: Duration.zero,
      );

      await expectLater(
        manager.start(
          adminPassword: 'mac password',
          onWaitingForRegistry: () => waitingEvents += 1,
        ),
        throwsA(
          isA<AppiumTunnelException>().having(
            (error) => error.message,
            'message',
            '手机隧道未完成。请解锁手机并点允许。',
          ),
        ),
      );

      expect(waitingEvents, 1);
      expect(fake.killed, isTrue);
      expect(manager.isRunning, isFalse);
    },
  );

  test(
    'AppiumTunnelProcessManager explains when registry has another device',
    () async {
      final fake = FakeTunnelProcessHandle(pid: 5254);
      final manager = AppiumTunnelProcessManager(
        config: const AppiumTunnelProcessConfig(udid: 'device-1'),
        starter:
            (executable, arguments, {workingDirectory, environment}) async {
              return fake;
            },
        registryReader: (_) async => {'device-2'},
        settleDelay: Duration.zero,
        readinessTimeout: const Duration(milliseconds: 1),
        readinessInterval: Duration.zero,
      );

      await expectLater(
        manager.start(adminPassword: 'mac password'),
        throwsA(
          isA<AppiumTunnelException>().having(
            (error) => error.message,
            'message',
            '绑定手机不可用。',
          ),
        ),
      );

      expect(fake.killed, isTrue);
      expect(manager.isRunning, isFalse);
    },
  );

  test(
    'local dependency probe checks toolchain and Android adb without leaking serial',
    () async {
      final commands = <String>[];
      final probe = LocalDependencyProbe(
        tunnelRegistryReader: (_) async => {'device-1'},
        runner: (executable, arguments) async {
          commands.add('$executable ${arguments.join(' ')}');
          if (executable == 'ps') {
            return ProcessResult(
              1,
              0,
              'appium driver run xcuitest tunnel-creation',
              '',
            );
          }
          if (executable == 'appium') {
            return ProcessResult(1, 0, '/Users/private/bin/appium 2.19.0', '');
          }
          if (executable == 'xcodebuild') {
            return ProcessResult(
              1,
              0,
              'Xcode 16.2\nBuild version 16C5032a',
              '',
            );
          }
          if (executable == 'adb') {
            return ProcessResult(
              1,
              0,
              'List of devices attached\n'
                  'android-serial-123 device model:Pixel_8 release:15\n',
              '',
            );
          }
          return ProcessResult(1, 0, 'ok', '');
        },
      );

      final report = await probe.check(
        appiumProcess: const AppiumProcessConfig(executable: 'appium'),
      );

      expect(report.readyCount, 6);
      expect(report.hasError, isFalse);
      expect(
        report.checkById('appium-cli')?.status,
        LocalDependencyStatus.ready,
      );
      expect(report.checkById('appium-cli')?.detail, '[path] 2.19.0');
      expect(report.checkById('appium-cli')?.detail, isNot(contains('/Users')));
      expect(
        report.checkById('xcode-cli')?.status,
        LocalDependencyStatus.ready,
      );
      expect(
        report.checkById('xcode-cli')?.detail,
        'Xcode 16.2 / Build version 16C5032a',
      );
      expect(
        report.checkById('ios-device-tools')?.status,
        LocalDependencyStatus.ready,
      );
      expect(
        report.checkById('ios-tunnel')?.status,
        LocalDependencyStatus.ready,
      );
      expect(
        report.checkById('wda-prerequisites')?.status,
        LocalDependencyStatus.ready,
      );
      expect(
        report.checkById('android-adb')?.status,
        LocalDependencyStatus.ready,
      );
      expect(report.checkById('android-adb')?.detail, 'Pixel 8 / Android 15');
      expect(
        report.checkById('android-adb')?.detail,
        isNot(contains('android-serial-123')),
      );
      expect(commands, [
        'appium --version',
        'xcodebuild -version',
        'xcrun devicectl --help',
        'adb devices -l',
        'ps aux',
      ]);
    },
  );

  test(
    'local dependency probe warns when Android phone is unauthorized',
    () async {
      final probe = LocalDependencyProbe(
        tunnelRegistryReader: (_) async => {'device-1'},
        runner: (executable, arguments) async {
          if (executable == 'ps') {
            return ProcessResult(
              1,
              0,
              'appium driver run xcuitest tunnel-creation',
              '',
            );
          }
          if (executable == 'adb') {
            return ProcessResult(
              1,
              0,
              'List of devices attached\n'
                  'android-secret-serial unauthorized model:Pixel_8 release:15\n',
              '',
            );
          }
          return ProcessResult(1, 0, 'ok', '');
        },
      );

      final report = await probe.check(
        appiumProcess: const AppiumProcessConfig(executable: 'appium'),
      );

      final android = report.checkById('android-adb');
      expect(report.hasError, isFalse);
      expect(report.hasWarning, isTrue);
      expect(android?.status, LocalDependencyStatus.warning);
      expect(android?.summary, '安卓手机未授权。');
      expect(android?.nextStep, '在手机上允许 USB 调试后重试。');
      expect(
        '${android?.summary} ${android?.detail}',
        isNot(contains('android-secret-serial')),
      );
    },
  );

  test('local dependency probe keeps missing adb as Android warning', () async {
    final probe = LocalDependencyProbe(
      tunnelRegistryReader: (_) async => {'device-1'},
      runner: (executable, arguments) async {
        if (executable == 'ps') {
          return ProcessResult(
            1,
            0,
            'appium driver run xcuitest tunnel-creation',
            '',
          );
        }
        if (executable == 'adb') {
          return ProcessResult(
            1,
            127,
            '',
            '/Users/dev/bin/adb: command not found',
          );
        }
        return ProcessResult(1, 0, 'ok', '');
      },
    );

    final report = await probe.check(
      appiumProcess: const AppiumProcessConfig(executable: 'appium'),
    );

    final android = report.checkById('android-adb');
    expect(report.hasError, isFalse);
    expect(report.hasWarning, isTrue);
    expect(android?.status, LocalDependencyStatus.warning);
    expect(android?.summary, '无法读取安卓手机。');
    expect(android?.nextStep, '确认 ADB 已安装并开启 USB 调试。');
    expect(android?.detail, contains('[本机路径]'));
    expect(android?.detail, isNot(contains('/Users/dev')));
  });

  test(
    'local dependency probe warns when local tunnel is not running',
    () async {
      final probe = LocalDependencyProbe(
        runner: (executable, arguments) async {
          return ProcessResult(1, 0, 'ok', '');
        },
      );

      final report = await probe.check(
        appiumProcess: const AppiumProcessConfig(executable: 'appium'),
      );

      expect(report.hasError, isFalse);
      expect(report.hasWarning, isTrue);
      expect(
        report.checkById('ios-tunnel')?.status,
        LocalDependencyStatus.warning,
      );
      expect(report.checkById('ios-tunnel')?.nextStep, '点连接设备并输入密码。');
      expect(
        report.checkById('wda-prerequisites')?.status,
        LocalDependencyStatus.warning,
      );
      expect(report.checkById('wda-prerequisites')?.summary, '会话等待本机隧道或手机允许。');
      expect(report.message, '本机检查需要处理。');
    },
  );

  test('local dependency probe warns when tunnel registry is empty', () async {
    final probe = LocalDependencyProbe(
      tunnelRegistryReader: (_) async => const <String>{},
      runner: (executable, arguments) async {
        if (executable == 'ps') {
          return ProcessResult(
            1,
            0,
            'appium driver run xcuitest tunnel-creation',
            '',
          );
        }
        if (executable == 'appium') {
          return ProcessResult(1, 0, '3.5.2', '');
        }
        if (executable == 'xcodebuild') {
          return ProcessResult(1, 0, 'Xcode 16.2', '');
        }
        return ProcessResult(1, 0, 'ok', '');
      },
    );

    final report = await probe.check(
      appiumProcess: const AppiumProcessConfig(executable: 'appium'),
    );

    expect(report.hasError, isFalse);
    expect(report.hasWarning, isTrue);
    expect(report.checkById('ios-tunnel')?.summary, '本机隧道还没连上手机。');
    expect(report.checkById('ios-tunnel')?.nextStep, '点连接设备，手机提示时点允许。');
    expect(report.message, '本机检查需要处理。');
  });

  test('local dependency probe blocks WDA when Xcode is missing', () async {
    final probe = LocalDependencyProbe(
      runner: (executable, arguments) async {
        if (executable == 'xcodebuild') {
          return ProcessResult(2, 1, '', 'missing');
        }
        return ProcessResult(1, 0, 'ok', '');
      },
    );

    final report = await probe.check(
      appiumProcess: const AppiumProcessConfig(executable: 'appium'),
    );

    expect(report.hasError, isTrue);
    expect(report.checkById('xcode-cli')?.status, LocalDependencyStatus.error);
    expect(
      report.checkById('wda-prerequisites')?.status,
      LocalDependencyStatus.error,
    );
  });

  test('runtime controller refreshes local dependency report', () async {
    final checker = FakeDependencyChecker(
      const LocalDependencyReport(
        checks: [
          LocalDependencyCheck(
            id: 'appium-cli',
            label: '驱动工具',
            status: LocalDependencyStatus.ready,
            summary: '驱动工具可用。',
            nextStep: '连接设备。',
          ),
        ],
        checkedAt: null,
        message: '本机检查通过。',
      ),
    );
    final controller = StudioRuntimeController(dependencyChecker: checker);

    await controller.refreshDependencyReport();
    await controller.dispose();

    expect(checker.checks, 1);
    expect(controller.snapshot.dependencyReport.readyCount, 1);
    expect(controller.snapshot.events.last.message, contains('通过'));
  });

  test(
    'runtime controller reports first actionable dependency issue',
    () async {
      final checker = FakeDependencyChecker(
        const LocalDependencyReport(
          checks: [
            LocalDependencyCheck(
              id: 'appium-cli',
              label: '驱动工具',
              status: LocalDependencyStatus.error,
              summary: '本机驱动工具不可用。',
              nextStep: '请安装驱动工具或更新配置。',
            ),
            LocalDependencyCheck(
              id: 'wda-prerequisites',
              label: '会话准备',
              status: LocalDependencyStatus.error,
              summary: '本机工具未通过，会话无法准备。',
              nextStep: '先处理驱动、开发工具和设备工具。',
            ),
          ],
          checkedAt: null,
          message: '本机检查发现阻断项。',
        ),
      );
      final controller = StudioRuntimeController(dependencyChecker: checker);

      await controller.refreshDependencyReport();
      await controller.dispose();

      expect(
        controller.snapshot.events.last.message,
        '本机检查发现阻断项。驱动工具：本机驱动工具不可用。请安装驱动工具或更新配置。',
      );
    },
  );

  test('runtime controller emits Appium process events', () async {
    final fake = FakeProcessHandle(pid: 9001);
    final manager = AppiumProcessManager(
      starter: (_, _, {environment}) async => fake,
    );
    final checker = FakeAvailabilityChecker(<AppiumAvailability>[
      const AppiumAvailability(available: true, message: 'ready'),
      const AppiumAvailability(
        available: false,
        message: 'Unable to reach Appium: Connection failed.',
      ),
    ]);
    final controller = StudioRuntimeController(
      availabilityProbe: checker,
      processManager: manager,
      appiumReadinessInterval: Duration.zero,
    );
    final snapshots = <StudioRuntimeSnapshot>[];
    final subscription = controller.snapshots.listen(snapshots.add);

    await controller.startAppium();
    await controller.stopAppium();
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    await controller.dispose();

    expect(controller.snapshot.appiumStatus, AppiumProcessStatus.stopped);
    expect(controller.snapshot.appiumOwnership, AppiumProcessOwnership.unknown);
    expect(
      snapshots.map((snapshot) => snapshot.appiumStatus),
      containsAllInOrder([
        AppiumProcessStatus.starting,
        AppiumProcessStatus.running,
        AppiumProcessStatus.stopping,
        AppiumProcessStatus.stopped,
      ]),
    );
    expect(fake.killed, isTrue);
    expect(checker.checks, 2);
  });

  test(
    'runtime controller marks ready external Appium without taking ownership',
    () async {
      var starts = 0;
      final manager = AppiumProcessManager(
        starter: (_, _, {environment}) async {
          starts += 1;
          return FakeProcessHandle(pid: 9050);
        },
      );
      final checker = FakeAvailabilityChecker(<AppiumAvailability>[
        const AppiumAvailability(available: true, message: 'ready'),
        const AppiumAvailability(available: true, message: 'ready'),
      ]);
      final controller = StudioRuntimeController(
        availabilityProbe: checker,
        processManager: manager,
      );

      await controller.prepareAppium();
      await controller.stopAppium();
      await controller.dispose();

      expect(starts, 0);
      expect(controller.snapshot.appiumStatus, AppiumProcessStatus.running);
      expect(
        controller.snapshot.appiumOwnership,
        AppiumProcessOwnership.external,
      );
      expect(controller.snapshot.appiumMessage, '驱动已就绪。外部启动。');
      expect(
        controller.snapshot.events.map((event) => event.message),
        containsAllInOrder(['驱动已就绪。外部启动。', '外部驱动未停止。可直接连接设备。']),
      );
    },
  );

  test('runtime controller waits until Appium status is ready', () async {
    final fake = FakeProcessHandle(pid: 9002);
    final manager = AppiumProcessManager(
      starter: (_, _, {environment}) async => fake,
    );
    final checker = FakeAvailabilityChecker(<AppiumAvailability>[
      const AppiumAvailability(available: false, message: 'starting'),
      const AppiumAvailability(available: true, message: 'ready'),
    ]);
    final controller = StudioRuntimeController(
      availabilityProbe: checker,
      processManager: manager,
      appiumReadinessInterval: Duration.zero,
    );

    await controller.startAppium();
    await controller.dispose();

    expect(controller.snapshot.appiumStatus, AppiumProcessStatus.running);
    expect(controller.snapshot.appiumMessage, '驱动已就绪。进程 9002。');
    expect(checker.checks, 2);
  });

  test('runtime controller turns unreachable Appium into next step', () async {
    final checker = FakeAvailabilityChecker(<AppiumAvailability>[
      const AppiumAvailability(
        available: false,
        message: 'Unable to reach Appium: Connection failed.',
      ),
    ]);
    final controller = StudioRuntimeController(availabilityProbe: checker);

    await controller.checkAppium();
    await controller.dispose();

    expect(controller.snapshot.appiumStatus, AppiumProcessStatus.stopped);
    expect(controller.snapshot.appiumMessage, contains('请点连接设备'));
    expect(
      controller.snapshot.events.last.message,
      '驱动检查失败：未发现本机驱动。请点连接设备；若仍失败，点查环境。',
    );
    expect(checker.checks, 1);
  });

  test(
    'runtime controller prepares Appium by checking then starting',
    () async {
      final fake = FakeProcessHandle(pid: 9101);
      final manager = AppiumProcessManager(
        starter: (_, _, {environment}) async => fake,
      );
      final checker = FakeAvailabilityChecker(<AppiumAvailability>[
        const AppiumAvailability(
          available: false,
          message: 'Unable to reach Appium: Connection failed.',
        ),
        const AppiumAvailability(available: true, message: 'ready'),
      ]);
      final controller = StudioRuntimeController(
        availabilityProbe: checker,
        processManager: manager,
        appiumReadinessInterval: Duration.zero,
      );

      await controller.prepareAppium();
      await controller.dispose();

      expect(controller.snapshot.appiumStatus, AppiumProcessStatus.running);
      expect(controller.snapshot.appiumMessage, '驱动已就绪。进程 9101。');
      expect(
        controller.snapshot.events.map((event) => event.message),
        containsAllInOrder([
          '正在准备驱动。',
          '未发现本机驱动，正在启动。',
          '驱动已启动，等待就绪。',
          '驱动已就绪。',
        ]),
      );
      expect(checker.checks, 2);
    },
  );

  test(
    'runtime controller connects end-to-end with tunnel, driver, and session',
    () async {
      final server = await sessionServer('one-button-session');
      final fakeAppium = FakeProcessHandle(pid: 9301);
      final fakeTunnel = FakeTunnelProcessHandle(pid: 9302);
      final manager = AppiumProcessManager(
        starter: (_, _, {environment}) async => fakeAppium,
      );
      final tunnelManager = AppiumTunnelProcessManager(
        starter:
            (executable, arguments, {workingDirectory, environment}) async {
              return fakeTunnel;
            },
        registryReader: (_) async => {'device-1'},
        settleDelay: Duration.zero,
      );
      final checker = FakeAvailabilityChecker(<AppiumAvailability>[
        const AppiumAvailability(
          available: false,
          message: 'Unable to reach Appium: Connection failed.',
        ),
        const AppiumAvailability(available: true, message: 'ready'),
      ]);
      final controller = StudioRuntimeController(
        availabilityProbe: checker,
        dependencyChecker: FakeDependencyChecker(
          LocalDependencyReport(
            checks: const [
              LocalDependencyCheck(
                id: 'ios-tunnel',
                label: '本机隧道',
                status: LocalDependencyStatus.warning,
                summary: '未发现本机隧道。',
                nextStep: '点连接设备并输入密码。',
              ),
            ],
            checkedAt: DateTime(2026, 1, 7),
            message: '本机检查需要处理。',
          ),
        ),
        processManager: manager,
        tunnelManager: tunnelManager,
        sessionManager: fakeSessionManager(server),
        requiresAppiumTunnel: true,
        appiumReadinessInterval: Duration.zero,
      );

      await controller.connectDeviceEndToEnd(adminPassword: 'top secret');
      await controller.dispose();
      await server.close(force: true);

      expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
      expect(controller.snapshot.sessionId, 'one-button-session');
      expect(fakeTunnel.inputLines, ['top secret']);
      expect(fakeAppium.killed, isTrue);
      expect(fakeTunnel.killed, isTrue);
      expect(
        controller.snapshot.events.map((event) => event.message).join('\n'),
        isNot(contains('top secret')),
      );
      expect(
        controller.snapshot.events.map((event) => event.message),
        containsAllInOrder([
          '正在连接设备。',
          '正在检查本机环境。',
          '正在启动本机隧道。',
          '等待手机允许。请在手机提示时点允许。',
          '本机隧道已就绪。',
          '正在准备驱动。',
          '手机会话已连接。',
        ]),
      );
    },
  );

  test(
    'runtime controller waits existing empty tunnel registry without password',
    () async {
      final server = await sessionServer('existing-tunnel-session');
      final fakeAppium = FakeProcessHandle(pid: 9311);
      var tunnelStarts = 0;
      final manager = AppiumProcessManager(
        starter: (_, _, {environment}) async => fakeAppium,
      );
      final tunnelManager = AppiumTunnelProcessManager(
        starter:
            (executable, arguments, {workingDirectory, environment}) async {
              tunnelStarts += 1;
              return FakeTunnelProcessHandle(pid: 9312);
            },
        registryReader: (_) async => {'device-1'},
        settleDelay: Duration.zero,
      );
      final checker = FakeAvailabilityChecker(<AppiumAvailability>[
        const AppiumAvailability(
          available: false,
          message: 'Unable to reach Appium: Connection failed.',
        ),
        const AppiumAvailability(available: true, message: 'ready'),
      ]);
      final dependencyChecker = SequencedDependencyChecker([
        LocalDependencyReport(
          checks: const [
            LocalDependencyCheck(
              id: 'ios-tunnel',
              label: '本机隧道',
              status: LocalDependencyStatus.warning,
              summary: '本机隧道还没连上手机。',
              nextStep: '点连接设备，手机提示时点允许。',
              detail: 'registry-empty',
            ),
          ],
          checkedAt: DateTime(2026, 1, 7),
          message: '本机检查需要处理。',
        ),
        LocalDependencyReport(
          checks: const [
            LocalDependencyCheck(
              id: 'ios-tunnel',
              label: '本机隧道',
              status: LocalDependencyStatus.ready,
              summary: '本机隧道已运行。',
              nextStep: '回到应用继续连接。',
            ),
          ],
          checkedAt: DateTime(2026, 1, 7, 0, 0, 1),
          message: '本机检查通过。',
        ),
      ]);
      final controller = StudioRuntimeController(
        availabilityProbe: checker,
        dependencyChecker: dependencyChecker,
        processManager: manager,
        tunnelManager: tunnelManager,
        sessionManager: fakeSessionManager(server),
        requiresAppiumTunnel: true,
        appiumReadinessInterval: Duration.zero,
      );

      await controller.connectDeviceEndToEnd();
      await controller.dispose();
      await server.close(force: true);

      expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
      expect(controller.snapshot.sessionId, 'existing-tunnel-session');
      expect(tunnelStarts, 0);
      expect(dependencyChecker.checks, 2);
      expect(
        controller.snapshot.events.map((event) => event.message),
        containsAllInOrder([
          '正在连接设备。',
          '正在检查本机环境。',
          '等待手机允许。请在手机提示时点允许。',
          '本机隧道已就绪。',
          '正在检查本机环境。',
          '正在准备驱动。',
          '手机会话已连接。',
        ]),
      );
    },
  );

  test(
    'runtime controller cleans stale empty tunnel registry before retrying',
    () async {
      final server = await sessionServer('recovered-tunnel-session');
      final fakeAppium = FakeProcessHandle(pid: 9315);
      final cleaner = _RecordingTunnelCleaner();
      var tunnelStarts = 0;
      var cleaned = false;
      final manager = AppiumProcessManager(
        starter: (_, _, {environment}) async => fakeAppium,
      );
      final tunnelManager = AppiumTunnelProcessManager(
        starter:
            (executable, arguments, {workingDirectory, environment}) async {
              tunnelStarts += 1;
              return FakeTunnelProcessHandle(pid: 9316);
            },
        registryReader: (_) async => cleaned ? {'device-1'} : const <String>{},
        settleDelay: Duration.zero,
        readinessTimeout: const Duration(milliseconds: 1),
        readinessInterval: Duration.zero,
      );
      cleaner.onClean = () => cleaned = true;
      final dependencyChecker = SequencedDependencyChecker([
        LocalDependencyReport(
          checks: const [
            LocalDependencyCheck(
              id: 'ios-tunnel',
              label: '本机隧道',
              status: LocalDependencyStatus.warning,
              summary: '本机隧道还没连上手机。',
              nextStep: '点连接设备，手机提示时点允许。',
              detail: 'registry-empty',
            ),
          ],
          checkedAt: DateTime(2026, 1, 7),
          message: '本机检查需要处理。',
        ),
        LocalDependencyReport(
          checks: const [
            LocalDependencyCheck(
              id: 'ios-tunnel',
              label: '本机隧道',
              status: LocalDependencyStatus.ready,
              summary: '本机隧道已运行。',
              nextStep: '回到应用继续连接。',
            ),
          ],
          checkedAt: DateTime(2026, 1, 7, 0, 0, 1),
          message: '本机检查通过。',
        ),
      ]);
      final controller = StudioRuntimeController(
        availabilityProbe: FakeAvailabilityChecker(<AppiumAvailability>[
          const AppiumAvailability(
            available: false,
            message: 'Unable to reach Appium: Connection failed.',
          ),
          const AppiumAvailability(available: true, message: 'ready'),
        ]),
        dependencyChecker: dependencyChecker,
        processManager: manager,
        tunnelManager: tunnelManager,
        tunnelCleaner: cleaner,
        sessionManager: fakeSessionManager(server),
        requiresAppiumTunnel: true,
        appiumReadinessInterval: Duration.zero,
      );

      await controller.connectDeviceEndToEnd(adminPassword: 'top secret');
      await controller.dispose();
      await server.close(force: true);

      expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
      expect(controller.snapshot.sessionId, 'recovered-tunnel-session');
      expect(cleaner.passwords, ['top secret']);
      expect(tunnelStarts, 1);
      expect(
        controller.snapshot.events.map((event) => event.message),
        containsAllInOrder([
          '等待手机允许。请在手机提示时点允许。',
          '正在清理旧隧道。',
          '正在启动本机隧道。',
          '本机隧道已就绪。',
          '手机会话已连接。',
        ]),
      );
      expect(
        controller.snapshot.events.map((event) => event.message).join('\n'),
        isNot(contains('top secret')),
      );
    },
  );

  test(
    'runtime controller blocks ready tunnel that belongs to another device',
    () async {
      final fakeAppium = FakeProcessHandle(pid: 9321);
      final sessionManager = SequencedSessionManager([
        const WebDriverSession(
          id: 'should-not-connect',
          capabilities: <String, Object?>{'platformName': 'iOS'},
        ),
      ]);
      final tunnelManager = AppiumTunnelProcessManager(
        config: const AppiumTunnelProcessConfig(udid: 'device-1'),
        starter:
            (executable, arguments, {workingDirectory, environment}) async {
              return FakeTunnelProcessHandle(pid: 9322);
            },
        registryReader: (_) async => {'device-2'},
        readinessTimeout: const Duration(milliseconds: 1),
        readinessInterval: Duration.zero,
      );
      final controller = StudioRuntimeController(
        availabilityProbe: FakeAvailabilityChecker(<AppiumAvailability>[
          const AppiumAvailability(available: true, message: 'ready'),
        ]),
        dependencyChecker: FakeDependencyChecker(
          LocalDependencyReport(
            checks: const [
              LocalDependencyCheck(
                id: 'ios-tunnel',
                label: '本机隧道',
                status: LocalDependencyStatus.ready,
                summary: '本机隧道已运行。',
                nextStep: '回到应用继续连接。',
              ),
            ],
            checkedAt: DateTime(2026, 1, 7),
            message: '本机检查通过。',
          ),
        ),
        processManager: AppiumProcessManager(
          starter: (_, _, {environment}) async => fakeAppium,
        ),
        tunnelManager: tunnelManager,
        sessionManager: sessionManager,
        requiresAppiumTunnel: true,
        appiumReadinessInterval: Duration.zero,
      );

      await controller.connectDeviceEndToEnd();
      await controller.dispose();

      expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
      expect(controller.snapshot.appiumMessage, '未找到 USB 手机。');
      expect(sessionManager.connects, 0);
      expect(
        controller.snapshot.lastConnectionDiagnostic?.nextStep,
        '用数据线连接一台手机并解锁，再点连接设备。',
      );
    },
  );

  test(
    'runtime controller restarts managed driver when current USB is invisible to Appium',
    () async {
      final fakeProcesses = <FakeProcessHandle>[];
      final manager = AppiumProcessManager(
        starter: (_, _, {environment}) async {
          final process = FakeProcessHandle(pid: 9400 + fakeProcesses.length);
          fakeProcesses.add(process);
          return process;
        },
      );
      final sessionManager = SequencedSessionManager([
        const AppiumClientException(
          'Appium returned HTTP 500 for /session. Unknown device or simulator UDID: DEVICE',
        ),
        const WebDriverSession(
          id: 'recovered-visible-session',
          capabilities: <String, Object?>{'platformName': 'iOS'},
        ),
      ]);
      final controller = StudioRuntimeController(
        availabilityProbe: FakeAvailabilityChecker(<AppiumAvailability>[
          const AppiumAvailability(
            available: false,
            message: 'Unable to reach Appium: Connection failed.',
          ),
          const AppiumAvailability(available: true, message: 'ready'),
          const AppiumAvailability(
            available: false,
            message: 'Unable to reach Appium: Connection failed.',
          ),
          const AppiumAvailability(
            available: false,
            message: 'Unable to reach Appium: Connection failed.',
          ),
          const AppiumAvailability(available: true, message: 'ready'),
        ]),
        dependencyChecker: FakeDependencyChecker(LocalDependencyReport.empty),
        processManager: manager,
        sessionManager: sessionManager,
        usbDeviceDiscovery: const _StaticUsbDeviceDiscovery([
          RuntimeUsbDevice(
            udid: 'DEVICE',
            name: 'USB Phone',
            modelName: 'iPhone',
            platformVersion: '17.5',
          ),
        ]),
        deviceBindingStore: _PassthroughDeviceBindingStore(),
        appiumReadinessInterval: Duration.zero,
      );

      await controller.connectDeviceEndToEnd();
      await controller.dispose();

      expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
      expect(controller.snapshot.sessionId, 'recovered-visible-session');
      expect(sessionManager.connects, 2);
      expect(fakeProcesses, hasLength(2));
      expect(fakeProcesses.first.killed, isTrue);
      expect(fakeProcesses.last.killed, isTrue);
      expect(
        controller.snapshot.events.map((event) => event.message),
        containsAllInOrder(['手机会话已连接。']),
      );
    },
  );

  test(
    'runtime controller resets external driver when current USB is invisible to Appium',
    () async {
      final fakeProcesses = <FakeProcessHandle>[];
      final manager = AppiumProcessManager(
        starter: (_, _, {environment}) async {
          final process = FakeProcessHandle(pid: 9450 + fakeProcesses.length);
          fakeProcesses.add(process);
          return process;
        },
      );
      final cleaner = _RecordingAppiumCleaner();
      final sessionManager = SequencedSessionManager([
        const AppiumClientException(
          'Appium returned HTTP 500 for /session. Unknown device or simulator UDID: DEVICE',
        ),
        const WebDriverSession(
          id: 'recovered-external-visible-session',
          capabilities: <String, Object?>{'platformName': 'iOS'},
        ),
      ]);
      final controller = StudioRuntimeController(
        availabilityProbe: FakeAvailabilityChecker(<AppiumAvailability>[
          const AppiumAvailability(available: true, message: 'external ready'),
          const AppiumAvailability(available: true, message: 'external ready'),
          const AppiumAvailability(
            available: false,
            message: 'Unable to reach Appium: Connection failed.',
          ),
          const AppiumAvailability(
            available: false,
            message: 'Unable to reach Appium: Connection failed.',
          ),
          const AppiumAvailability(available: true, message: 'ready'),
        ]),
        dependencyChecker: FakeDependencyChecker(LocalDependencyReport.empty),
        processManager: manager,
        appiumCleaner: cleaner,
        sessionManager: sessionManager,
        usbDeviceDiscovery: const _StaticUsbDeviceDiscovery([
          RuntimeUsbDevice(
            udid: 'DEVICE',
            name: 'USB Phone',
            modelName: 'iPhone',
            platformVersion: '17.5',
          ),
        ]),
        deviceBindingStore: _PassthroughDeviceBindingStore(),
        appiumReadinessInterval: Duration.zero,
      );

      await controller.connectDeviceEndToEnd();
      await controller.dispose();

      expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
      expect(
        controller.snapshot.sessionId,
        'recovered-external-visible-session',
      );
      expect(sessionManager.connects, 2);
      expect(cleaner.cleans, 1);
      expect(fakeProcesses, hasLength(1));
      expect(fakeProcesses.single.killed, isTrue);
      expect(
        controller.snapshot.events.map((event) => event.message),
        containsAllInOrder(['正在重置旧驱动。', '旧驱动已重置。', '手机会话已连接。']),
      );
    },
  );

  test(
    'runtime controller restarts managed driver once for transient WDA proxy failure',
    () async {
      final fakeProcesses = <FakeProcessHandle>[];
      final manager = AppiumProcessManager(
        starter: (_, _, {environment}) async {
          final process = FakeProcessHandle(pid: 9500 + fakeProcesses.length);
          fakeProcesses.add(process);
          return process;
        },
      );
      final sessionManager = SequencedSessionManager([
        const AppiumClientException(
          'Unable to launch WebDriverAgent. Original error: socket hang up on port 8100',
        ),
        const WebDriverSession(
          id: 'recovered-wda-session',
          capabilities: <String, Object?>{'platformName': 'iOS'},
        ),
      ]);
      final controller = StudioRuntimeController(
        availabilityProbe: FakeAvailabilityChecker(<AppiumAvailability>[
          const AppiumAvailability(
            available: false,
            message: 'Unable to reach Appium: Connection failed.',
          ),
          const AppiumAvailability(available: true, message: 'ready'),
          const AppiumAvailability(
            available: false,
            message: 'Unable to reach Appium: Connection failed.',
          ),
          const AppiumAvailability(
            available: false,
            message: 'Unable to reach Appium: Connection failed.',
          ),
          const AppiumAvailability(available: true, message: 'ready'),
        ]),
        dependencyChecker: FakeDependencyChecker(LocalDependencyReport.empty),
        processManager: manager,
        sessionManager: sessionManager,
        usbDeviceDiscovery: const _StaticUsbDeviceDiscovery([
          RuntimeUsbDevice(
            udid: 'DEVICE',
            name: 'USB Phone',
            modelName: 'iPhone',
            platformVersion: '17.5',
          ),
        ]),
        deviceBindingStore: _PassthroughDeviceBindingStore(),
        appiumReadinessInterval: Duration.zero,
      );

      await controller.connectDeviceEndToEnd();
      await controller.dispose();

      expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
      expect(controller.snapshot.sessionId, 'recovered-wda-session');
      expect(sessionManager.connects, 2);
      expect(fakeProcesses, hasLength(2));
      expect(fakeProcesses.first.killed, isTrue);
      expect(fakeProcesses.last.killed, isTrue);
      expect(
        controller.snapshot.events.map((event) => event.message),
        containsAllInOrder([
          '手机会话启动失败。 确认已解锁和已信任，再点连接设备。 详情：Unable to launch WebDriverAgent. Original error: socket hang up on port 8100',
          '正在恢复手机会话。',
          '手机会话已连接。',
        ]),
      );
    },
  );

  test(
    'runtime controller does not restart driver for Xcode build failures',
    () async {
      final fakeProcesses = <FakeProcessHandle>[];
      final manager = AppiumProcessManager(
        starter: (_, _, {environment}) async {
          final process = FakeProcessHandle(pid: 9600 + fakeProcesses.length);
          fakeProcesses.add(process);
          return process;
        },
      );
      final sessionManager = SequencedSessionManager([
        const AppiumClientException(
          'Unable to launch WebDriverAgent. Original error: xcodebuild failed with code 65',
        ),
      ]);
      final controller = StudioRuntimeController(
        availabilityProbe: FakeAvailabilityChecker(<AppiumAvailability>[
          const AppiumAvailability(
            available: false,
            message: 'Unable to reach Appium: Connection failed.',
          ),
          const AppiumAvailability(available: true, message: 'ready'),
        ]),
        dependencyChecker: FakeDependencyChecker(LocalDependencyReport.empty),
        processManager: manager,
        sessionManager: sessionManager,
        usbDeviceDiscovery: const _StaticUsbDeviceDiscovery([
          RuntimeUsbDevice(
            udid: 'DEVICE',
            name: 'USB Phone',
            modelName: 'iPhone',
            platformVersion: '17.5',
          ),
        ]),
        deviceBindingStore: _PassthroughDeviceBindingStore(),
        appiumReadinessInterval: Duration.zero,
      );

      await controller.connectDeviceEndToEnd();
      await controller.dispose();

      expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
      expect(controller.snapshot.appiumMessage, '手机会话构建失败。');
      expect(
        controller.snapshot.lastConnectionDiagnostic?.type,
        RuntimeConnectionIssueType.wdaBuildFailed,
      );
      expect(sessionManager.connects, 1);
      expect(fakeProcesses, hasLength(1));
      expect(fakeProcesses.single.killed, isTrue);
      expect(
        controller.snapshot.events.map((event) => event.message),
        isNot(contains('正在恢复手机会话。')),
      );
    },
  );

  test('runtime controller stores and clears connection diagnostics', () async {
    final sessionManager = SequencedSessionManager([
      const AppiumClientException(
        "Unable to launch WebDriverAgent. Original error: socket hang up",
      ),
      const WebDriverSession(
        id: 'diagnostic-recovered-session',
        capabilities: <String, Object?>{'platformName': 'iOS'},
      ),
    ]);
    final controller = StudioRuntimeController(sessionManager: sessionManager);

    await controller.connectDevice();

    expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
    expect(controller.snapshot.appiumMessage, '手机会话启动失败。');
    expect(controller.snapshot.lastConnectionDiagnostic, isNotNull);
    expect(
      controller.snapshot.lastConnectionDiagnostic?.type,
      RuntimeConnectionIssueType.wdaStartFailed,
    );
    expect(
      controller.snapshot.lastConnectionDiagnostic?.nextStep,
      '确认已解锁和已信任，再点连接设备。',
    );
    expect(
      controller.snapshot.lastConnectionDiagnostic?.detail,
      isNot(contains('127.0.0.1')),
    );

    await controller.connectDevice();
    await controller.dispose();

    expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
    expect(controller.snapshot.sessionId, 'diagnostic-recovered-session');
    expect(controller.snapshot.lastConnectionDiagnostic, isNull);
    expect(sessionManager.connects, 2);
  });

  test('runtime controller explains missing Appium executable', () async {
    final manager = AppiumProcessManager(
      starter: (executable, arguments, {environment}) async {
        throw ProcessException(
          executable,
          arguments,
          'No such file or directory',
        );
      },
    );
    final controller = StudioRuntimeController(processManager: manager);

    await controller.startAppium();
    await controller.dispose();

    expect(controller.snapshot.appiumStatus, AppiumProcessStatus.error);
    expect(controller.snapshot.appiumMessage, '未找到驱动工具。请点查环境。');
    expect(controller.snapshot.events.last.message, contains('未找到驱动工具。请点查环境。'));
  });

  test('runtime controller reports Appium readiness timeout', () async {
    final fake = FakeProcessHandle(pid: 9003);
    final manager = AppiumProcessManager(
      starter: (_, _, {environment}) async => fake,
    );
    final checker = FakeAvailabilityChecker(<AppiumAvailability>[
      const AppiumAvailability(available: false, message: 'not ready'),
      const AppiumAvailability(available: false, message: 'still not ready'),
    ]);
    final controller = StudioRuntimeController(
      availabilityProbe: checker,
      processManager: manager,
      appiumReadinessInterval: Duration.zero,
      appiumReadinessMaxAttempts: 2,
    );

    await controller.startAppium();
    await controller.dispose();

    expect(controller.snapshot.appiumStatus, AppiumProcessStatus.error);
    expect(controller.snapshot.appiumMessage, contains('驱动等待超时'));
    expect(checker.checks, 2);
  });
}

// 静态 USB 设备发现 fake。
// Runtime 生命周期测试用它确认一键连接不会访问真实手机。
final class _StaticUsbDeviceDiscovery implements UsbDeviceDiscovery {
  const _StaticUsbDeviceDiscovery(this.devices);

  final List<RuntimeUsbDevice> devices;

  @override
  Future<List<RuntimeUsbDevice>> listUsbDevices() async => devices;
}

// 透传型设备绑定存储 fake。
// 它返回当前 USB 手机生成的 session 配置，不写本地项目文件。
final class _PassthroughDeviceBindingStore implements DeviceBindingStore {
  @override
  Future<DeviceSessionConfig> saveDeviceBinding(RuntimeUsbDevice device) async {
    return DeviceSessionConfig(
      capabilities: {
        'platformName': 'iOS',
        'appium:automationName': 'XCUITest',
        'appium:udid': device.udid,
        'appium:deviceName': device.appiumDeviceName,
        'appium:platformVersion': device.platformVersion,
      },
    );
  }
}

// 旧隧道清理 fake，只记录密码是否被传入进程级清理，不写日志。
final class _RecordingTunnelCleaner implements AppiumTunnelProcessCleaner {
  final passwords = <String>[];
  void Function()? onClean;

  @override
  Future<void> cleanStaleTunnels({
    required AppiumTunnelProcessConfig config,
    required String adminPassword,
  }) async {
    passwords.add(adminPassword);
    onClean?.call();
  }
}

// 旧 Appium 清理 fake，只记录是否触发外部驱动重置。
// 它不访问真实本机进程，保持 Runtime 测试可重复。
final class _RecordingAppiumCleaner implements AppiumProcessCleaner {
  int cleans = 0;

  @override
  Future<void> cleanStaleAppium({required AppiumProcessConfig config}) async {
    cleans += 1;
  }
}
