part of '../studio_mac_workspace.dart';

// 设置抽屉，承载本机偏好、隐私和边界状态。
class _SettingsDrawer extends StatelessWidget {
  const _SettingsDrawer({required this.snapshot, required this.controller});

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;

  // 根据 Runtime 快照渲染设置内容，避免页面缓存旧状态。
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StudioRuntimeSnapshot>(
      stream: controller.snapshots,
      initialData: snapshot,
      builder: (context, runtime) {
        final current = runtime.data ?? snapshot;
        final workflowValidation = _snapshotWorkflowValidation(current);
        return Material(
          color: StudioColors.panel,
          child: SizedBox(
            width: 420,
            height: double.infinity,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '设置',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '本机工作台控制与边界。',
                      style: TextStyle(color: StudioColors.muted, height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ListView(
                        children: [
                          _SettingsSection(
                            title: '工作台',
                            children: const [
                              _SettingsToggleRow(label: '单设备优先', value: true),
                              _SettingsToggleRow(label: '只存本机', value: true),
                              _SettingsToggleRow(label: '云同步', value: false),
                            ],
                          ),
                          _SettingsSection(
                            title: '运行时',
                            children: [
                              _DrawerField(
                                label: '驱动路径',
                                value: '应用 -> 运行时 -> 驱动 -> 手机',
                              ),
                              _DrawerField(
                                label: '设备',
                                value: _deviceStatusLabel(
                                  current.connectionStatus,
                                ),
                              ),
                              _DrawerField(
                                label: '驱动',
                                value: _appiumStatusLabel(current.appiumStatus),
                              ),
                              _DrawerField(
                                label: '运行',
                                value: _runStatusLabel(current.runStatus),
                              ),
                              _DrawerField(
                                label: '流程',
                                value: _workflowStatusLabel(workflowValidation),
                              ),
                            ],
                          ),
                          _SettingsSection(
                            title: '视觉',
                            children: [
                              _SettingsToggleRow(
                                label: '视觉增强',
                                value: current.settings.enablePythonVision,
                                onChanged: (value) => controller.updateSettings(
                                  current.settings.copyWith(
                                    enablePythonVision: value,
                                  ),
                                ),
                              ),
                              _DrawerField(
                                label: '方式',
                                value: current.settings.enablePythonVision
                                    ? 'Python 找图'
                                    : '轻量找图',
                              ),
                            ],
                          ),
                          _SettingsSection(
                            title: '隐私',
                            children: [
                              _SettingsToggleRow(
                                label: '隐藏标识',
                                value: current.settings.hideDeviceIdentifier,
                              ),
                              _SettingsToggleRow(
                                label: '隐藏原始数据',
                                value: current.settings.hideRawWebDriverPayload,
                              ),
                              _SettingsToggleRow(
                                label: '默认显示截图',
                                value:
                                    current.settings.revealScreenshotsByDefault,
                                onChanged: (value) => controller.updateSettings(
                                  current.settings.copyWith(
                                    revealScreenshotsByDefault: value,
                                  ),
                                ),
                              ),
                              _SettingsStepperRow(
                                label: '证据保留',
                                value: current.settings.evidenceMaxRuns,
                                min: 1,
                                max: 200,
                                suffix: '条',
                                onChanged: (value) => controller.updateSettings(
                                  current.settings.copyWith(
                                    evidenceMaxRuns: value,
                                  ),
                                ),
                              ),
                              _SettingsStepperRow(
                                label: '保留天数',
                                value: current.settings.evidenceMaxAgeDays,
                                min: 1,
                                max: 90,
                                suffix: '天',
                                onChanged: (value) => controller.updateSettings(
                                  current.settings.copyWith(
                                    evidenceMaxAgeDays: value,
                                  ),
                                ),
                              ),
                              _DrawerField(
                                label: '截图证据',
                                value: current.latestScreenshotAt == null
                                    ? '暂无预览'
                                    : '最新预览 ${_timeOnly(current.latestScreenshotAt!)}',
                              ),
                            ],
                          ),
                          const _SettingsSection(
                            title: '边界',
                            children: [
                              _SettingsToggleRow(label: '串行运行', value: true),
                              _SettingsToggleRow(label: '安全停', value: true),
                              _SettingsToggleRow(label: '旧节点接口', value: false),
                              _SettingsToggleRow(label: '任意脚本', value: false),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
