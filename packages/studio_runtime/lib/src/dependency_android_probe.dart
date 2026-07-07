part of '../studio_runtime.dart';

// Android ADB 依赖检查分片，只判断本机可见性，不启动驱动或执行真机动作。
extension LocalDependencyAndroidProbe on LocalDependencyProbe {
  // 检查 Android ADB 与唯一授权手机状态，输出脱敏短摘要。
  Future<LocalDependencyCheck> _checkAndroidAdb() async {
    try {
      final discovery = await AdbAndroidDeviceDiscovery(
        runner: _runner,
        timeout: timeout,
      ).discover();
      return _androidDependencyFromDiscovery(discovery);
    } on AndroidDeviceDiscoveryException catch (error) {
      return LocalDependencyCheck(
        id: 'android-adb',
        label: '安卓调试',
        status: LocalDependencyStatus.warning,
        summary: error.summary,
        nextStep: error.nextStep,
        detail: error.detail.isEmpty ? null : error.detail,
      );
    }
  }

  // 根据 ADB 发现结果生成用户可操作状态，不保留完整 serial。
  LocalDependencyCheck _androidDependencyFromDiscovery(
    AndroidAdbDiscovery discovery,
  ) {
    final ready = discovery.readyDevices;
    if (ready.length == 1) {
      final device = ready.single;
      return LocalDependencyCheck(
        id: 'android-adb',
        label: '安卓调试',
        status: LocalDependencyStatus.ready,
        summary: '已发现一台安卓手机。',
        nextStep: '可运行安卓冒烟。',
        detail: _androidDeviceDetail(device),
      );
    }
    if (ready.length > 1) {
      return LocalDependencyCheck(
        id: 'android-adb',
        label: '安卓调试',
        status: LocalDependencyStatus.warning,
        summary: '发现多台安卓手机。',
        nextStep: '只保留一台 USB 手机后重试。',
        detail: '可用 ${ready.length} 台',
      );
    }
    if (discovery.devices.any(_androidDeviceUnauthorized)) {
      return const LocalDependencyCheck(
        id: 'android-adb',
        label: '安卓调试',
        status: LocalDependencyStatus.warning,
        summary: '安卓手机未授权。',
        nextStep: '在手机上允许 USB 调试后重试。',
      );
    }
    if (discovery.devices.any(_androidDeviceOffline)) {
      return const LocalDependencyCheck(
        id: 'android-adb',
        label: '安卓调试',
        status: LocalDependencyStatus.warning,
        summary: '安卓手机离线。',
        nextStep: '重插数据线并保持亮屏。',
      );
    }
    if (discovery.devices.isEmpty) {
      return const LocalDependencyCheck(
        id: 'android-adb',
        label: '安卓调试',
        status: LocalDependencyStatus.warning,
        summary: '未发现安卓手机。',
        nextStep: '开启 USB 调试，插线并在手机上点允许。',
      );
    }
    return const LocalDependencyCheck(
      id: 'android-adb',
      label: '安卓调试',
      status: LocalDependencyStatus.warning,
      summary: '安卓手机状态不可用。',
      nextStep: '重插数据线并确认 USB 调试已开启。',
    );
  }

  // 生成不含 serial 的安卓设备短详情。
  String _androidDeviceDetail(AndroidAdbDevice device) {
    final version = device.androidVersion;
    if (version != null && version.trim().isNotEmpty) {
      return '${device.displayName} / Android $version';
    }
    return device.displayName;
  }
}

// 判断 ADB 设备是否处于未授权状态。
bool _androidDeviceUnauthorized(AndroidAdbDevice device) {
  return device.state == AndroidAdbDeviceState.unauthorized;
}

// 判断 ADB 设备是否处于离线状态。
bool _androidDeviceOffline(AndroidAdbDevice device) {
  return device.state == AndroidAdbDeviceState.offline;
}
