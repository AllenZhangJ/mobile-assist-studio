part of '../studio_runtime.dart';

// Runtime 设置项目命令，负责本地偏好、收藏和隐私保留策略。
// 设置命令只写本机 store，不直接改变 Appium 连接或 workflow 结构。
extension StudioRuntimeSettingsProjectCommands on StudioRuntimeController {
  // 切换当前流程收藏状态，只写本机设置，不触发设备或运行。
  // 收藏失败时保留原 snapshot，避免 UI 与设置文件漂移。
  Future<bool> toggleCurrentWorkflowFavorite() async {
    final workflowId = _snapshot.workflow.id;
    final favorites = _snapshot.settings.favoriteWorkflowIds.toList();
    final wasFavorite = favorites.remove(workflowId);
    if (!wasFavorite) favorites.add(workflowId);
    final updatedSettings = _snapshot.settings.copyWith(
      favoriteWorkflowIds: favorites,
    );

    try {
      await _settingsStore.saveSettings(updatedSettings);
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '收藏保存失败：$error')));
      return false;
    }

    _emit(
      _snapshot.copyWith(
        settings: updatedSettings,
        events: _appendEvent('info', wasFavorite ? '已取消收藏。' : '已收藏流程。'),
      ),
    );
    return true;
  }

  // 更新本机设置，并把证据保留策略同步到 evidence store。
  // 隐私硬开关由 StudioSettings 模型归一，调用方不能关闭。
  Future<bool> updateSettings(StudioSettings settings) async {
    final normalized = settings.copyWith(
      evidenceMaxRuns: settings.evidenceMaxRuns,
      evidenceMaxAgeDays: settings.evidenceMaxAgeDays,
    );
    try {
      await _settingsStore.saveSettings(normalized);
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '设置保存失败：$error')));
      return false;
    }

    if (!_usesInjectedTargetResolver) {
      _targetResolver = _targetResolverForSettings(normalized);
    }

    try {
      final evidenceStore = _evidenceStore;
      if (evidenceStore is LocalRunEvidenceStore) {
        await evidenceStore.updateRetention(
          maxRuns: normalized.evidenceMaxRuns,
          maxAgeDays: normalized.evidenceMaxAgeDays,
        );
      }
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(
          settings: normalized,
          events: _appendEvent('warning', '证据清理失败：$error'),
        ),
      );
      return true;
    }

    _emit(
      _snapshot.copyWith(
        settings: normalized,
        events: _appendEvent('info', '设置已更新。'),
      ),
    );
    return true;
  }
}
