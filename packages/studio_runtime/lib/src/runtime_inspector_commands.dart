part of '../studio_runtime.dart';

// Runtime Inspector 命令，负责采集当前界面检查快照。
// Inspector 失败只写诊断事件，不改变 Device / Execute 主流程状态。
extension StudioRuntimeInspectorCommands on StudioRuntimeController {
  // 采集当前手机界面截图和元素结构，生成脱敏 Inspector 快照。
  Future<InspectorSnapshot?> inspectCurrentScreen({
    String reason = 'manual',
  }) async {
    if (_snapshot.connectionStatus != ConnectionStatus.connected) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '请先连接设备再检查。')));
      return null;
    }
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能检查界面。')));
      return null;
    }
    if (_inspectorBusy) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '界面检查中，请稍等。')));
      return null;
    }
    final session = _sessionManager.session;
    if (session == null) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '设备已连但会话缺失。')));
      return null;
    }

    _inspectorBusy = true;
    final previousRuntime = _snapshot.mobileRuntime;
    _emit(
      _snapshot.copyWith(
        mobileRuntime: previousRuntime.copyWith(
          resourceState: MobileResourceState.diagnosing,
        ),
        events: _appendEvent('info', '正在检查界面：$reason。'),
      ),
    );
    try {
      final screenshot = await _deviceActions.screenshot(session.id);
      final source = await _deviceActions.pageSource(session.id);
      final parsed = const InspectorSourceParser().parse(source);
      final platform = _inspectorPlatform(previousRuntime, parsed.root);
      final capabilities = _inspectorCapabilities(previousRuntime, platform);
      final capturedAt = DateTime.now();
      final inspectorSnapshot = InspectorSnapshot(
        platform: platform,
        capturedAt: capturedAt,
        capabilities: capabilities,
        elementCount: parsed.elementCount,
        screenshotBase64: screenshot,
        rootElement: parsed.root,
        sourceSummary: parsed.summary,
        sourcePreview: parsed.preview,
      );
      _emit(
        _snapshot.copyWith(
          latestScreenshotBase64: screenshot,
          latestScreenshotAt: capturedAt,
          inspectorSnapshot: inspectorSnapshot,
          mobileRuntime: previousRuntime,
          events: _appendEvent('info', '界面检查完成。'),
        ),
      );
      return inspectorSnapshot;
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(
          mobileRuntime: previousRuntime,
          events: _appendEvent(
            'error',
            '界面检查失败：${_redactConnectionDetail(error.toString())}',
          ),
        ),
      );
      return null;
    } finally {
      _inspectorBusy = false;
    }
  }
}

// 推断 Inspector 平台，优先使用 Runtime 当前平台。
MobilePlatform _inspectorPlatform(
  MobileRuntimeSummary runtime,
  InspectorElementSummary? root,
) {
  if (runtime.platform != MobilePlatform.unknown) return runtime.platform;
  final type = root?.type.toLowerCase() ?? '';
  if (type.contains('xcui')) return MobilePlatform.ios;
  if (type.contains('hierarchy') || type.contains('layout')) {
    return MobilePlatform.android;
  }
  return MobilePlatform.unknown;
}

// 为 Inspector 生成能力面板数据，缺失 Runtime 能力时保守补齐检查能力。
MobileDriverCapabilityReport _inspectorCapabilities(
  MobileRuntimeSummary runtime,
  MobilePlatform platform,
) {
  final current = runtime.capabilities;
  if (current.screenshot || current.pageSource || current.selectorTarget) {
    return current.copyWith(platform: platform);
  }
  return MobileDriverCapabilityReport.none.copyWith(
    platform: platform,
    screenshot: true,
    pageSource: true,
    selectorTarget: true,
  );
}
