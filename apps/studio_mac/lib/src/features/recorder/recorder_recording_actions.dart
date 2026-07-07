part of '../../studio_mac_workspace.dart';

// Recorder 录制控制动作，只负责切换本地录制状态。
extension _RecorderRecordingActions on _RecorderPageState {
  // 开始录制，只改变本地录制状态，不直接触发设备动作。
  void _startRecording() {
    _setRecording(true);
  }

  // 停止录制，已捕获动作仍保留在时间线中。
  void _stopRecording() {
    _setRecording(false);
  }
}
