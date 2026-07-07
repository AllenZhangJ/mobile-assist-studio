part of '../studio_runtime.dart';

// 本机隧道检查分片，只判断是否存在可用隧道和活动 registry。
extension LocalDependencyTunnelProbe on LocalDependencyProbe {
  // 检查本机隧道进程和活动数量，不启动命令、不请求权限。
  Future<LocalDependencyCheck> _checkTunnelProcess() async {
    try {
      final result = await _runner('ps', const ['aux']).timeout(timeout);
      if (result.exitCode != 0) {
        return const LocalDependencyCheck(
          id: 'ios-tunnel',
          label: '本机隧道',
          status: LocalDependencyStatus.warning,
          summary: '无法确认本机隧道状态。',
          nextStep: '点连接设备并输入密码。',
        );
      }
      final output = '${result.stdout}\n${result.stderr}'.toLowerCase();
      final running = output.contains('tunnel-creation');
      if (running) {
        final devices = await _readTunnelRegistryDevices();
        if (devices.isEmpty) {
          return const LocalDependencyCheck(
            id: 'ios-tunnel',
            label: '本机隧道',
            status: LocalDependencyStatus.warning,
            summary: '本机隧道还没连上手机。',
            nextStep: '点连接设备，手机提示时点允许。',
            detail: 'registry-empty',
          );
        }
        return const LocalDependencyCheck(
          id: 'ios-tunnel',
          label: '本机隧道',
          status: LocalDependencyStatus.ready,
          summary: '本机隧道已运行。',
          nextStep: '回到应用继续连接。',
        );
      }
      return const LocalDependencyCheck(
        id: 'ios-tunnel',
        label: '本机隧道',
        status: LocalDependencyStatus.warning,
        summary: '未发现本机隧道。',
        nextStep: '点连接设备并输入密码。',
      );
    } on TimeoutException {
      return const LocalDependencyCheck(
        id: 'ios-tunnel',
        label: '本机隧道',
        status: LocalDependencyStatus.warning,
        summary: '本机隧道检查超时。',
        nextStep: '点连接设备重试。',
      );
    } on Object {
      return const LocalDependencyCheck(
        id: 'ios-tunnel',
        label: '本机隧道',
        status: LocalDependencyStatus.warning,
        summary: '无法确认本机隧道状态。',
        nextStep: '点连接设备并输入密码。',
      );
    }
  }

  // 只读取 registry 的活动设备数量，不把设备标识写入检查报告。
  Future<Set<String>> _readTunnelRegistryDevices() async {
    try {
      return await _tunnelRegistryReader(
        const AppiumTunnelProcessConfig(),
      ).timeout(timeout);
    } on Object {
      return const <String>{};
    }
  }
}
