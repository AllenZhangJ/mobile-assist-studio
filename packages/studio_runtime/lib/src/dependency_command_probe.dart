part of '../studio_runtime.dart';

// 本机命令检查分片，负责执行命令并生成脱敏短详情。
extension LocalDependencyCommandProbe on LocalDependencyProbe {
  // 执行一个本机命令，并把退出结果转换为依赖检查项。
  Future<LocalDependencyCheck> _checkCommand({
    required String id,
    required String label,
    required String executable,
    required List<String> arguments,
    required String readySummary,
    required String readyNextStep,
    required String errorSummary,
    required String errorNextStep,
    String? Function(ProcessResult result)? detailBuilder,
  }) async {
    try {
      final result = await _runner(executable, arguments).timeout(timeout);
      if (result.exitCode == 0) {
        return LocalDependencyCheck(
          id: id,
          label: label,
          status: LocalDependencyStatus.ready,
          summary: readySummary,
          nextStep: readyNextStep,
          detail: detailBuilder?.call(result),
        );
      }
      return LocalDependencyCheck(
        id: id,
        label: label,
        status: LocalDependencyStatus.error,
        summary: errorSummary,
        nextStep: errorNextStep,
      );
    } on TimeoutException {
      return LocalDependencyCheck(
        id: id,
        label: label,
        status: LocalDependencyStatus.warning,
        summary: '$label 响应超时。',
        nextStep: '如有工具卡住，请关闭后重试。',
      );
    } on Object {
      return LocalDependencyCheck(
        id: id,
        label: label,
        status: LocalDependencyStatus.error,
        summary: errorSummary,
        nextStep: errorNextStep,
      );
    }
  }

  // 提取命令输出的前几行，并清理路径等隐私信息。
  String? _commandDetail(ProcessResult result, {int maxLines = 1}) {
    final output = '${result.stdout}\n${result.stderr}';
    final lines = output
        .split(RegExp(r'\r?\n'))
        .map((line) => _sanitizeCommandLine(line.trim()))
        .where((line) => line.isNotEmpty)
        .take(maxLines)
        .toList(growable: false);
    if (lines.isEmpty) return null;
    return _clampDetail(lines.join(' / '));
  }

  // 脱敏单行命令输出，避免路径进入 UI 或日志。
  String _sanitizeCommandLine(String line) {
    return line
        .replaceAll(RegExp(r'(/[^\s]+)+'), '[path]')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // 限制详情长度，让状态抽屉保持紧凑。
  String _clampDetail(String detail) {
    const maxLength = 96;
    if (detail.length <= maxLength) return detail;
    return '${detail.substring(0, maxLength - 1)}...';
  }
}
