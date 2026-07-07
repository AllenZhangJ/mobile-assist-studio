part of '../studio_runtime.dart';

const _iosAppiumCapabilities = MobileDriverCapabilityReport(
  platform: MobilePlatform.ios,
  screenshot: true,
  tap: true,
  swipe: true,
  input: true,
  pageSource: true,
  selectorTarget: true,
  imageTarget: false,
  ocrTarget: false,
  appLifecycle: false,
  logs: false,
  performance: false,
  remotePreview: false,
);

const _androidAppiumCapabilities = MobileDriverCapabilityReport(
  platform: MobilePlatform.android,
  screenshot: true,
  tap: true,
  swipe: true,
  input: true,
  pageSource: true,
  selectorTarget: true,
  imageTarget: false,
  ocrTarget: false,
  appLifecycle: false,
  logs: true,
  performance: false,
  remotePreview: false,
);

// IosAppiumMobileDriver 把现有 iOS Appium session 和设备动作包装成 V4 driver。
// 它不改变旧控制器路径，只提供平台中立 adapter 合同。
final class IosAppiumMobileDriver implements MobileDeviceDriver {
  // 创建 iOS Appium driver，可注入现有 session manager 和动作执行器。
  const IosAppiumMobileDriver({
    required RuntimeSessionManager sessionManager,
    required DeviceActionExecutor deviceActions,
    MobileDeviceSummary? device,
    int defaultTapDurationMs = 80,
  }) : _sessionManager = sessionManager,
       _deviceActions = deviceActions,
       _device = device,
       _defaultTapDurationMs = defaultTapDurationMs;

  final RuntimeSessionManager _sessionManager;
  final DeviceActionExecutor _deviceActions;
  final MobileDeviceSummary? _device;
  final int _defaultTapDurationMs;

  @override
  MobilePlatform get platform => MobilePlatform.ios;

  @override
  Future<MobileDriverCapabilityReport> capabilityReport() async {
    return _iosAppiumCapabilities;
  }

  @override
  Future<MobileDeviceSummary?> discoverCurrentDevice() async {
    return _device;
  }

  @override
  Future<MobileDriverSession> connect() async {
    final session = await _sessionManager.connect();
    return MobileDriverSession(
      sessionId: session.id,
      platform: MobilePlatform.ios,
      capabilities: _iosAppiumCapabilities,
      device: _device,
    );
  }

  @override
  Future<void> disconnect() {
    return _sessionManager.disconnect();
  }

  @override
  Future<MobileDriverHeartbeat> heartbeat() async {
    final ready = _sessionManager.session != null;
    return MobileDriverHeartbeat(
      ready: ready,
      message: ready ? '手机会话可用。' : '手机会话未连接。',
      capabilities: _iosAppiumCapabilities,
    );
  }

  @override
  Future<MobileScreenshot> captureScreenshot() async {
    final sessionId = _requireSessionId();
    final screenshot = await _deviceActions.screenshot(sessionId);
    final viewport = await _deviceActions.viewportSize(sessionId);
    return MobileScreenshot(
      base64Png: screenshot,
      capturedAt: DateTime.now(),
      viewport: viewport,
    );
  }

  @override
  Future<String?> getPageSource() async {
    return _deviceActions.pageSource(_requireSessionId());
  }

  @override
  Future<void> tap(ViewportPoint point, {Duration? duration}) {
    return _deviceActions.tap(
      _requireSessionId(),
      RuntimeTap(
        point: point,
        label: '移动点按',
        durationMs: duration?.inMilliseconds ?? _defaultTapDurationMs,
      ),
    );
  }

  @override
  Future<void> swipe(
    ViewportPoint from,
    ViewportPoint to, {
    Duration? duration,
  }) {
    return _deviceActions.swipe(
      _requireSessionId(),
      RuntimeSwipe(
        from: from,
        to: to,
        label: '移动滑动',
        durationMs: duration?.inMilliseconds ?? 500,
      ),
    );
  }

  @override
  Future<void> inputText(String text) {
    return _deviceActions.inputText(
      _requireSessionId(),
      RuntimeInput(text: text, label: '移动输入'),
    );
  }

  @override
  Future<void> launchApp(String appId) {
    throw UnsupportedError('iOS App 启动能力尚未接入 V4 driver。');
  }

  @override
  Future<void> stopApp(String appId) {
    throw UnsupportedError('iOS App 停止能力尚未接入 V4 driver。');
  }

  @override
  Future<void> pressHome() {
    return _deviceActions.pressButton(
      _requireSessionId(),
      RuntimeDeviceButton.home,
    );
  }

  @override
  Future<List<String>> collectLogs() async {
    return const <String>[];
  }

  @override
  Future<void> releaseActions() {
    return _deviceActions.releaseActions(_requireSessionId());
  }

  // 读取当前 session id，未连接时给出可诊断错误。
  String _requireSessionId() {
    final session = _sessionManager.session;
    if (session == null) {
      throw StateError('手机会话未连接。');
    }
    return session.id;
  }
}

// AndroidAppiumMobileDriver 通过 ADB 发现当前 Android 手机，并用 UiAutomator2 建立会话。
// 它只负责平台 adapter，不直接修改 workflow 或绕过 Runtime 资源锁。
final class AndroidAppiumMobileDriver implements MobileDeviceDriver {
  // 创建 Android driver，并确保默认动作执行器复用同一个 Appium client。
  factory AndroidAppiumMobileDriver({
    AndroidDeviceDiscovery discovery = const AdbAndroidDeviceDiscovery(),
    AppiumClient? client,
    DeviceActionExecutor? deviceActions,
    Map<String, Object?> baseCapabilities = const <String, Object?>{},
    int defaultTapDurationMs = 80,
  }) {
    final resolvedClient = client ?? AppiumClient();
    return AndroidAppiumMobileDriver._(
      discovery: discovery,
      client: resolvedClient,
      deviceActions:
          deviceActions ?? AppiumDeviceActionExecutor(resolvedClient),
      baseCapabilities: Map<String, Object?>.unmodifiable(baseCapabilities),
      defaultTapDurationMs: defaultTapDurationMs,
    );
  }

  // 创建 Android driver 内部实例。
  AndroidAppiumMobileDriver._({
    required AndroidDeviceDiscovery discovery,
    required AppiumClient client,
    required DeviceActionExecutor deviceActions,
    required Map<String, Object?> baseCapabilities,
    required int defaultTapDurationMs,
  }) : _discovery = discovery,
       _client = client,
       _deviceActions = deviceActions,
       _baseCapabilities = baseCapabilities,
       _defaultTapDurationMs = defaultTapDurationMs;

  final AndroidDeviceDiscovery _discovery;
  final AppiumClient _client;
  final DeviceActionExecutor _deviceActions;
  final Map<String, Object?> _baseCapabilities;
  final int _defaultTapDurationMs;
  WebDriverSession? _session;
  AndroidAdbDevice? _device;

  @override
  MobilePlatform get platform => MobilePlatform.android;

  @override
  Future<MobileDriverCapabilityReport> capabilityReport() async {
    return _androidAppiumCapabilities;
  }

  @override
  Future<MobileDeviceSummary?> discoverCurrentDevice() async {
    try {
      final discovery = await _discovery.discover();
      return discovery.requireSingleReadyDevice().toSummary();
    } on AndroidDeviceDiscoveryException {
      return null;
    }
  }

  @override
  Future<MobileDriverSession> connect() async {
    if (_session case final current?) {
      return MobileDriverSession(
        sessionId: current.id,
        platform: MobilePlatform.android,
        capabilities: _androidAppiumCapabilities,
        device: _device?.toSummary(),
      );
    }

    final discovery = await _discovery.discover();
    final device = discovery.requireSingleReadyDevice();
    final session = await _client.createSession(
      AppiumSessionRequest(capabilities: _capabilitiesFor(device)),
    );
    _session = session;
    _device = device;
    return MobileDriverSession(
      sessionId: session.id,
      platform: MobilePlatform.android,
      capabilities: _androidAppiumCapabilities,
      device: device.toSummary(),
    );
  }

  @override
  Future<void> disconnect() async {
    final session = _session;
    if (session == null) return;
    try {
      await _client.deleteSession(session.id);
    } finally {
      _session = null;
      _device = null;
    }
  }

  @override
  Future<MobileDriverHeartbeat> heartbeat() async {
    final ready = _session != null;
    return MobileDriverHeartbeat(
      ready: ready,
      message: ready ? '安卓会话可用。' : '安卓会话未连接。',
      capabilities: _androidAppiumCapabilities,
    );
  }

  @override
  Future<MobileScreenshot> captureScreenshot() async {
    final sessionId = _requireSessionId();
    final screenshot = await _deviceActions.screenshot(sessionId);
    final viewport = await _deviceActions.viewportSize(sessionId);
    return MobileScreenshot(
      base64Png: screenshot,
      capturedAt: DateTime.now(),
      viewport: viewport,
    );
  }

  @override
  Future<String?> getPageSource() {
    return _deviceActions.pageSource(_requireSessionId());
  }

  @override
  Future<void> tap(ViewportPoint point, {Duration? duration}) {
    return _deviceActions.tap(
      _requireSessionId(),
      RuntimeTap(
        point: point,
        label: '安卓点按',
        durationMs: duration?.inMilliseconds ?? _defaultTapDurationMs,
      ),
    );
  }

  @override
  Future<void> swipe(
    ViewportPoint from,
    ViewportPoint to, {
    Duration? duration,
  }) {
    return _deviceActions.swipe(
      _requireSessionId(),
      RuntimeSwipe(
        from: from,
        to: to,
        label: '安卓滑动',
        durationMs: duration?.inMilliseconds ?? 500,
      ),
    );
  }

  @override
  Future<void> inputText(String text) {
    return _deviceActions.inputText(
      _requireSessionId(),
      RuntimeInput(text: text, label: '安卓输入'),
    );
  }

  @override
  Future<void> launchApp(String appId) {
    throw UnsupportedError('Android App 启动能力尚未接入。');
  }

  @override
  Future<void> stopApp(String appId) {
    throw UnsupportedError('Android App 停止能力尚未接入。');
  }

  @override
  Future<void> pressHome() {
    throw UnsupportedError('Android 主页键能力尚未接入。');
  }

  @override
  Future<List<String>> collectLogs() async {
    final device = _device;
    if (device == null) return const <String>[];
    return _discovery.collectLogcat(serial: device.serial);
  }

  @override
  Future<void> releaseActions() {
    return _deviceActions.releaseActions(_requireSessionId());
  }

  // 合成 Android UiAutomator2 session capabilities，并强制平台核心字段正确。
  Map<String, Object?> _capabilitiesFor(AndroidAdbDevice device) {
    final next = <String, Object?>{..._baseCapabilities};
    next['platformName'] = 'Android';
    next['appium:automationName'] = 'UiAutomator2';
    next['appium:udid'] = device.serial;
    next.putIfAbsent('appium:deviceName', () => device.displayName);
    next.putIfAbsent('appium:autoGrantPermissions', () => true);
    next.putIfAbsent('appium:noReset', () => true);
    next.putIfAbsent('appium:newCommandTimeout', () => 300);
    if (device.androidVersion case final version? when version.isNotEmpty) {
      next.putIfAbsent('appium:platformVersion', () => version);
    }
    return Map<String, Object?>.unmodifiable(next);
  }

  // 读取当前 Android session id，未连接时给出可诊断错误。
  String _requireSessionId() {
    final session = _session;
    if (session == null) {
      throw StateError('安卓会话未连接。');
    }
    return session.id;
  }
}
