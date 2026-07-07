part of '../studio_runtime.dart';

// LocalDependencyStatus 表示本机依赖检查的结果级别。
// UI 只消费这些摘要状态，不展示原始命令输出。
enum LocalDependencyStatus { unknown, ready, warning, error }

// LocalDependencyCheck 表示单个本机检查项。
// 它只保存脱敏摘要、下一步和可选短详情。
final class LocalDependencyCheck {
  // 创建单项依赖检查摘要。
  const LocalDependencyCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.summary,
    required this.nextStep,
    this.detail,
  });

  final String id;
  final String label;
  final LocalDependencyStatus status;
  final String summary;
  final String nextStep;
  final String? detail;
}

// LocalDependencyReport 汇总本机依赖检查结果。
// Device 页和状态详情共用这份脱敏报告。
final class LocalDependencyReport {
  // 创建本机依赖检查报告。
  const LocalDependencyReport({
    required this.checks,
    required this.checkedAt,
    required this.message,
  });

  final List<LocalDependencyCheck> checks;
  final DateTime? checkedAt;
  final String message;

  // 统计已就绪检查项数量，供 UI 展示准备度。
  int get readyCount {
    return checks
        .where((check) => check.status == LocalDependencyStatus.ready)
        .length;
  }

  // 判断是否存在错误项，供主状态汇总使用。
  bool get hasError {
    return checks.any((check) => check.status == LocalDependencyStatus.error);
  }

  // 判断是否存在提醒项，供主状态汇总使用。
  bool get hasWarning {
    return checks.any((check) => check.status == LocalDependencyStatus.warning);
  }

  // 按检查 ID 查找单项，便于高级抽屉读取详情。
  LocalDependencyCheck? checkById(String id) {
    for (final check in checks) {
      if (check.id == id) return check;
    }
    return null;
  }

  static const empty = LocalDependencyReport(
    checks: <LocalDependencyCheck>[
      LocalDependencyCheck(
        id: 'appium-cli',
        label: '驱动工具',
        status: LocalDependencyStatus.unknown,
        summary: '尚未检查驱动工具。',
        nextStep: '连接前先查环境。',
      ),
      LocalDependencyCheck(
        id: 'xcode-cli',
        label: '开发工具',
        status: LocalDependencyStatus.unknown,
        summary: '尚未检查开发工具。',
        nextStep: '连接前先查环境。',
      ),
      LocalDependencyCheck(
        id: 'ios-device-tools',
        label: '设备工具',
        status: LocalDependencyStatus.unknown,
        summary: '尚未检查设备工具。',
        nextStep: '用有线方式连接手机后查环境。',
      ),
      LocalDependencyCheck(
        id: 'ios-tunnel',
        label: '本机隧道',
        status: LocalDependencyStatus.unknown,
        summary: '尚未检查本机隧道。',
        nextStep: '真机会话异常时先查环境。',
      ),
      LocalDependencyCheck(
        id: 'wda-prerequisites',
        label: '会话准备',
        status: LocalDependencyStatus.unknown,
        summary: '会话依赖驱动、开发工具和手机信任。',
        nextStep: '先处理本机检查项。',
      ),
    ],
    checkedAt: null,
    message: '尚未检查本机环境。',
  );
}
