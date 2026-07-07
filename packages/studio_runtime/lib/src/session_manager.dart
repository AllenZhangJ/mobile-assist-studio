part of '../studio_runtime.dart';

// 设备会话管理，负责通过 Appium 建立和释放 WDA 会话。
abstract interface class RuntimeSessionManager {
  WebDriverSession? get session;

  Future<WebDriverSession> connect();

  Future<void> disconnect();
}

final class DeviceSessionManager implements RuntimeSessionManager {
  DeviceSessionManager({
    AppiumClient? client,
    this.config = const DeviceSessionConfig(),
  }) : _client = client ?? AppiumClient();

  final AppiumClient _client;
  DeviceSessionConfig config;
  WebDriverSession? _session;

  @override
  WebDriverSession? get session => _session;

  @override
  Future<WebDriverSession> connect() async {
    if (_session case final current?) {
      return current;
    }
    if (!config.hasValidUdid) {
      throw RuntimeDeviceBindingException(
        summary: '未找到 USB 手机。',
        nextStep: '用数据线连接一台手机并解锁，再点连接设备。',
        detail: config.hasInvalidUdidPlaceholder ? '设备配置不是当前手机。' : '缺少当前手机绑定。',
      );
    }
    final session = await _client.createSession(config.toSessionRequest());
    _session = session;
    return session;
  }

  // 更新下一次创建 session 使用的设备配置。
  // 已连接会话不会被静默替换，调用方必须先断开。
  void updateConfig(DeviceSessionConfig next) {
    if (_session != null) {
      throw const RuntimeDeviceBindingException(
        summary: '手机已连接。',
        nextStep: '先断开，再重新绑定。',
      );
    }
    config = next;
  }

  @override
  Future<void> disconnect() async {
    final session = _session;
    if (session == null) return;
    try {
      await _client.deleteSession(session.id);
    } finally {
      _session = null;
    }
  }
}
