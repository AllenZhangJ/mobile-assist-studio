part of '../../studio_mac_workspace.dart';

// 录制会话摘要，负责展示录制前的关键准备状态。
class _RecorderSessionPanel extends StatelessWidget {
  const _RecorderSessionPanel({
    required this.snapshot,
    required this.controller,
    required this.recording,
    required this.actionCount,
  });

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;
  final bool recording;
  final int actionCount;

  // 渲染录制准备状态，避免在主界面暴露底层连接细节。
  @override
  Widget build(BuildContext context) {
    final readyToRecord =
        snapshot.connectionStatus == ConnectionStatus.connected &&
        snapshot.runStatus == RunStatus.idle;
    return _Surface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '会话摘要',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _RecorderSessionStatusRow(
              recording: recording,
              readyToRecord: readyToRecord,
            ),
            const SizedBox(height: 16),
            _DeviceFactRow(label: '操作', value: '$actionCount'),
            const SizedBox(height: 10),
            _DeviceFactRow(
              label: '预览',
              value: snapshot.latestScreenshotAt == null
                  ? '暂无截图'
                  : _timeOnly(snapshot.latestScreenshotAt!),
            ),
            const SizedBox(height: 10),
            _DeviceFactRow(
              label: '设备',
              value: _deviceStatusLabel(snapshot.connectionStatus),
            ),
            const SizedBox(height: 10),
            _DeviceFactRow(
              label: '运行锁',
              value: _runStatusLabel(snapshot.runStatus),
            ),
            const SizedBox(height: 18),
            _RecorderReadinessBox(snapshot: snapshot),
            if (snapshot.connectionStatus != ConnectionStatus.connected) ...[
              const SizedBox(height: 14),
              _ConnectPrimaryAction(
                snapshot: snapshot,
                controller: controller,
                controlKey: const ValueKey('recorder-connect-one-button'),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              _recorderNextStepMessage(
                snapshot: snapshot,
                recording: recording,
                actionCount: actionCount,
              ),
              style: const TextStyle(color: StudioColors.muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

// 会话摘要状态行，使用短标签说明录制和截图是否可用。
class _RecorderSessionStatusRow extends StatelessWidget {
  const _RecorderSessionStatusRow({
    required this.recording,
    required this.readyToRecord,
  });

  final bool recording;
  final bool readyToRecord;

  // 渲染两个摘要状态，避免用户先读复杂准备项。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusPill(
          label: recording ? '录制中' : '空闲',
          tone: recording ? StudioStatusTone.error : StudioStatusTone.offline,
        ),
        StatusPill(
          label: readyToRecord ? '可截图' : '需设置',
          tone: readyToRecord
              ? StudioStatusTone.ready
              : StudioStatusTone.warning,
        ),
      ],
    );
  }
}

// 录制前检查盒子，只展示用户能理解的准备状态。
class _RecorderReadinessBox extends StatelessWidget {
  const _RecorderReadinessBox({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  // 渲染设备、运行锁和截图准备项，供用户判断下一步。
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.42),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('录制前', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _ReadinessRow(
            label: '设备就绪',
            ready: snapshot.connectionStatus == ConnectionStatus.connected,
            waiting: _deviceBusy(snapshot.connectionStatus),
          ),
          const SizedBox(height: 10),
          _ReadinessRow(
            label: '空闲',
            ready: snapshot.runStatus == RunStatus.idle,
            waiting: snapshot.runStatus == RunStatus.running,
          ),
          const SizedBox(height: 10),
          _ReadinessRow(
            label: '可预览',
            ready: snapshot.latestScreenshotBase64 != null,
            waiting: false,
          ),
        ],
      ),
    );
  }
}
