part of '../studio_runtime.dart';

// WDA 前置条件分片，负责把底层检查汇总成用户可理解的会话准备状态。
extension LocalDependencyWdaPrerequisites on LocalDependencyProbe {
  // 根据工具链和隧道检查结果生成会话准备项。
  LocalDependencyCheck _wdaPrerequisiteCheck(
    LocalDependencyCheck appium,
    LocalDependencyCheck xcode,
    LocalDependencyCheck deviceTools,
    LocalDependencyCheck tunnel,
  ) {
    final inputs = <LocalDependencyCheck>[appium, xcode, deviceTools, tunnel];
    if (inputs.any((check) => check.status == LocalDependencyStatus.error)) {
      return const LocalDependencyCheck(
        id: 'wda-prerequisites',
        label: '会话准备',
        status: LocalDependencyStatus.error,
        summary: '本机工具未通过，会话无法准备。',
        nextStep: '先处理驱动、开发工具和设备工具。',
      );
    }
    if (tunnel.status == LocalDependencyStatus.warning) {
      return const LocalDependencyCheck(
        id: 'wda-prerequisites',
        label: '会话准备',
        status: LocalDependencyStatus.warning,
        summary: '会话等待本机隧道或手机允许。',
        nextStep: '点连接设备并按手机提示允许。',
      );
    }
    if (inputs.any((check) => check.status == LocalDependencyStatus.warning)) {
      return const LocalDependencyCheck(
        id: 'wda-prerequisites',
        label: '会话准备',
        status: LocalDependencyStatus.warning,
        summary: '会话准备还有提醒项。',
        nextStep: '处理本机提醒后重新连接。',
      );
    }
    return const LocalDependencyCheck(
      id: 'wda-prerequisites',
      label: '会话准备',
      status: LocalDependencyStatus.ready,
      summary: '会话所需本机条件已就绪。',
      nextStep: '点连接设备，如有提示请在手机信任。',
    );
  }

  // 汇总本机检查报告文案，保持主界面只展示一句话。
  String _dependencyReportMessage(List<LocalDependencyCheck> checks) {
    final hasError = checks.any(
      (check) => check.status == LocalDependencyStatus.error,
    );
    final hasWarning = checks.any(
      (check) => check.status == LocalDependencyStatus.warning,
    );
    return switch ((hasError, hasWarning)) {
      (true, _) => '本机检查发现阻断项。',
      (_, true) => '本机检查需要处理。',
      _ => '本机检查通过。',
    };
  }
}
