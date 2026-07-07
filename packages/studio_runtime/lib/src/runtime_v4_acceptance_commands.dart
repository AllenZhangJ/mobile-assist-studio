part of '../studio_runtime.dart';

// Runtime V4 终验命令，负责读取本地终验摘要。
// 该命令不执行 smoke、不启动设备动作，只刷新 snapshot。
extension StudioRuntimeV4AcceptanceCommands on StudioRuntimeController {
  // 刷新最新 V4 final acceptance 摘要。
  // 读取失败只写提示事件，避免 Monitor 打开时阻断主流程。
  Future<void> refreshV4AcceptanceSummary() async {
    try {
      final summary = await _v4AcceptanceSummaryReader.readLatest();
      _emit(_snapshot.copyWith(v4AcceptanceSummary: summary));
    } on Object {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '终验摘要读取失败。')));
    }
  }
}
