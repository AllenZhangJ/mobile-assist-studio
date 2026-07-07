part of '../studio_runtime.dart';

// RuntimeConnectionIssueType 描述手机会话失败的大类。
// UI 只展示短中文摘要，底层长错误只作为脱敏详情进入 Console。
enum RuntimeConnectionIssueType {
  developerTrust,
  deviceLocked,
  appiumUnavailable,
  tunnelUnavailable,
  deviceNotVisible,
  driverDeviceNotVisible,
  deviceUnavailable,
  wdaBuildFailed,
  wdaStartFailed,
  unknown,
}

// RuntimeConnectionDiagnostic 是连接失败后的可操作诊断。
// 它把 Appium / Xcode 长错误收敛成状态、摘要和下一步动作。
final class RuntimeConnectionDiagnostic {
  // 创建连接诊断结果。
  const RuntimeConnectionDiagnostic({
    required this.type,
    required this.status,
    required this.summary,
    required this.nextStep,
    required this.detail,
  });

  final RuntimeConnectionIssueType type;
  final ConnectionStatus status;
  final String summary;
  final String nextStep;
  final String detail;

  // 生成可写入事件流的短诊断文案。
  String get eventMessage {
    if (detail.isEmpty) {
      return '$summary $nextStep';
    }
    return '$summary $nextStep 详情：$detail';
  }
}

// classifyRuntimeConnectionError 把底层连接异常转成用户能操作的中文状态。
// 该函数不启动进程、不读设备，只做纯文本分类和脱敏。
RuntimeConnectionDiagnostic classifyRuntimeConnectionError(Object error) {
  if (error is RuntimeDeviceBindingException) {
    return RuntimeConnectionDiagnostic(
      type: RuntimeConnectionIssueType.deviceNotVisible,
      status: ConnectionStatus.error,
      summary: error.summary,
      nextStep: error.nextStep,
      detail: _redactConnectionDetail(error.detail),
    );
  }

  final text = _runtimeConnectionErrorText(error);
  final lower = text.toLowerCase();
  final detail = _redactConnectionDetail(text);

  if (_hasAny(lower, const [
    'developer app certificate is not trusted',
    'developer app is not trusted',
    'profile has not been explicitly trusted',
    'explicitly trusted by the user',
    'not trusted',
    'verify app',
  ])) {
    return RuntimeConnectionDiagnostic(
      type: RuntimeConnectionIssueType.developerTrust,
      status: ConnectionStatus.waitingForDeveloperTrust,
      summary: '等待手机信任。',
      nextStep: '在手机设置里信任一次，再点连接设备。',
      detail: detail,
    );
  }

  if (_hasAny(lower, const [
    'unlock',
    'device is locked',
    'passcode',
    'destination is not ready',
  ])) {
    return RuntimeConnectionDiagnostic(
      type: RuntimeConnectionIssueType.deviceLocked,
      status: ConnectionStatus.error,
      summary: '请先解锁手机。',
      nextStep: '保持亮屏后再点连接设备。',
      detail: detail,
    );
  }

  if (_hasAny(lower, const [
    'unable to reach appium',
    'connection refused',
    'failed host lookup',
    'timed out while requesting',
    'appium response was not an object',
  ])) {
    return RuntimeConnectionDiagnostic(
      type: RuntimeConnectionIssueType.appiumUnavailable,
      status: ConnectionStatus.error,
      summary: '驱动未就绪。',
      nextStep: '点连接设备重试。',
      detail: detail,
    );
  }

  if (_hasAny(lower, const [
    'remotexpc tunnel is not available',
    'cannot create port forwarder via remotexpc tunnel',
    'tunnel-creation',
  ])) {
    return RuntimeConnectionDiagnostic(
      type: RuntimeConnectionIssueType.tunnelUnavailable,
      status: ConnectionStatus.error,
      summary: '本机隧道未就绪。',
      nextStep: '点连接设备并输入密码。',
      detail: detail,
    );
  }

  if (_hasAny(lower, const ['unknown device or simulator udid'])) {
    return RuntimeConnectionDiagnostic(
      type: RuntimeConnectionIssueType.driverDeviceNotVisible,
      status: ConnectionStatus.error,
      summary: '驱动未识别手机。',
      nextStep: '保持解锁，点连接设备。仍失败就重插线。',
      detail: '本机驱动没有看到当前手机。',
    );
  }

  if (_hasAny(lower, const [
    'usbmux',
    'device unavailable',
    'no device',
    'not available through usb',
  ])) {
    return RuntimeConnectionDiagnostic(
      type: RuntimeConnectionIssueType.deviceUnavailable,
      status: ConnectionStatus.error,
      summary: '未找到手机。',
      nextStep: '检查 USB 连接和电脑信任。',
      detail: detail,
    );
  }

  if (_hasAny(lower, const [
    'xcodebuild failed with code 65',
    'xcodebuild failed',
    'provisioning profile',
    'code signing',
    'requires a development team',
    'signing certificate',
    'development team',
    'no profiles for',
    'failed to build webdriveragent',
  ])) {
    return RuntimeConnectionDiagnostic(
      type: RuntimeConnectionIssueType.wdaBuildFailed,
      status: ConnectionStatus.error,
      summary: '手机会话构建失败。',
      nextStep: '打开 Xcode 处理签名后，再点连接设备。',
      detail: detail,
    );
  }

  if (_hasAny(lower, const [
    'webdriveragent',
    'could not proxy command',
    'socket hang up',
    'port 8100',
    'wda',
  ])) {
    return RuntimeConnectionDiagnostic(
      type: RuntimeConnectionIssueType.wdaStartFailed,
      status: ConnectionStatus.error,
      summary: '手机会话启动失败。',
      nextStep: '确认已解锁和已信任，再点连接设备。',
      detail: detail,
    );
  }

  return RuntimeConnectionDiagnostic(
    type: RuntimeConnectionIssueType.unknown,
    status: ConnectionStatus.error,
    summary: '手机会话失败。',
    nextStep: '查看控制台后重试。',
    detail: detail,
  );
}

// _runtimeConnectionErrorText 提取异常里的可读信息。
// AppiumClientException 只取 message，避免把 Exception 类型名展示给用户。
String _runtimeConnectionErrorText(Object error) {
  if (error is AppiumClientException) {
    return error.message;
  }
  return error.toString();
}

// _redactConnectionDetail 裁剪并脱敏连接失败详情。
// 它使用中文占位，避免用户误以为脱敏文本是实际设备配置。
String _redactConnectionDetail(String text) {
  final oneLine = text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'/Users/[^ ]+'), '[本机路径]')
      .replaceAll(RegExp(r'/private/[^ ]+'), '[本机路径]')
      .replaceAll(RegExp(r'http://127\.0\.0\.1:\d+[^\s]*'), '[本机地址]')
      .replaceAll(RegExp(r'[A-Fa-f0-9]{8}-[A-Fa-f0-9]{16}'), '[标识]')
      .replaceAll(RegExp(r'[A-Fa-f0-9]{40}'), '[标识]')
      .replaceAll(
        RegExp(
          r'[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}',
        ),
        '[编号]',
      )
      .trim();
  if (oneLine.length <= 260) {
    return oneLine;
  }
  return '${oneLine.substring(0, 260)}...';
}

// _hasAny 判断文本是否包含任一关键词。
// 统一封装后，分类分支保持短而可读。
bool _hasAny(String text, List<String> needles) {
  return needles.any(text.contains);
}
