part of '../studio_mac_workspace.dart';

// 格式化与通用 helper，负责时间、比例、短标识和节点类型等展示转换。
String _formatDuration(Duration? duration) {
  if (duration == null) return '-';
  final milliseconds = duration.inMilliseconds;
  if (milliseconds < 1000) {
    return '${milliseconds}ms';
  }
  final seconds = duration.inSeconds;
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes}m ${remainder}s';
}

String _formatPercent(double value) {
  return '${(value * 100).toStringAsFixed(1)}%';
}

String _formatVisualConfidence(double? value) {
  if (value == null) return '-';
  return _formatPercent(value);
}

String _visualRuleLabel(String rule) {
  return switch (rule) {
    'latest_screenshot_presence' => '最新截图',
    _ => rule,
  };
}

bool _appiumBusy(AppiumProcessStatus status) {
  return status == AppiumProcessStatus.starting ||
      status == AppiumProcessStatus.stopping;
}

bool _deviceBusy(ConnectionStatus status) {
  return status == ConnectionStatus.initializing ||
      status == ConnectionStatus.connecting ||
      status == ConnectionStatus.disconnecting;
}

String _shortSession(String sessionId) {
  if (sessionId.length <= 8) {
    return sessionId;
  }
  return '${sessionId.substring(0, 4)}...${sessionId.substring(sessionId.length - 4)}';
}

String _deviceSummaryMessage(StudioRuntimeSnapshot snapshot) {
  if (snapshot.connectionStatus == ConnectionStatus.waitingForDeveloperTrust) {
    return 'iPhone 等待信任，请处理后重连。';
  }
  if (snapshot.lastConnectionDiagnostic case final diagnostic?
      when snapshot.connectionStatus != ConnectionStatus.connected) {
    return '${diagnostic.summary} ${diagnostic.nextStep}';
  }
  if (snapshot.connectionStatus == ConnectionStatus.connected) {
    return snapshot.sessionId == null
        ? '设备已连，但会话不可用。'
        : '手机会话 ${_shortSession(snapshot.sessionId!)} 已就绪。';
  }
  if (snapshot.connectionStatus == ConnectionStatus.error ||
      snapshot.appiumStatus == AppiumProcessStatus.error) {
    return snapshot.appiumMessage;
  }
  if (snapshot.appiumStatus != AppiumProcessStatus.running) {
    return '点连接设备后会自动准备。';
  }
  return snapshot.appiumMessage;
}

Uint8List? _decodeScreenshot(String? screenshotBase64) {
  if (screenshotBase64 == null || screenshotBase64.isEmpty) {
    return null;
  }
  try {
    return base64Decode(screenshotBase64);
  } on FormatException {
    return null;
  }
}

Future<Size?> _imageSizeFromBytes(Uint8List bytes) async {
  try {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    final image = await completer.future;
    return Size(image.width.toDouble(), image.height.toDouble());
  } on Object {
    return null;
  }
}

// 从 PNG IHDR 同步读取图片尺寸。
// Recorder 用它在完整解码前获得可靠坐标基准。
Size? _pngImageSizeFromBytes(Uint8List bytes) {
  if (bytes.length < 24) return null;
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return null;
  }
  if (bytes[12] != 0x49 ||
      bytes[13] != 0x48 ||
      bytes[14] != 0x44 ||
      bytes[15] != 0x52) {
    return null;
  }
  int readUint32(int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  final width = readUint32(16);
  final height = readUint32(20);
  if (width <= 0 || height <= 0) return null;
  return Size(width.toDouble(), height.toDouble());
}

Rect _previewContentRect(Size containerSize, Size? imageSize) {
  if (containerSize.width <= 0 || containerSize.height <= 0) {
    return Rect.zero;
  }
  final sourceSize = imageSize;
  if (sourceSize == null || sourceSize.width <= 0 || sourceSize.height <= 0) {
    return Offset.zero & containerSize;
  }
  final sourceAspect = sourceSize.width / sourceSize.height;
  final containerAspect = containerSize.width / containerSize.height;
  if (sourceAspect > containerAspect) {
    final height = containerSize.width / sourceAspect;
    final top = (containerSize.height - height) / 2;
    return Rect.fromLTWH(0, top, containerSize.width, height);
  }
  final width = containerSize.height * sourceAspect;
  final left = (containerSize.width - width) / 2;
  return Rect.fromLTWH(left, 0, width, containerSize.height);
}

String _timeOnly(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
}

int _runsForLocalDate(List<RunHistoryDay> days, DateTime date) {
  for (final day in days) {
    final local = day.day.toLocal();
    if (local.year == date.year &&
        local.month == date.month &&
        local.day == date.day) {
      return day.totalRuns;
    }
  }
  return 0;
}

int _maxDailyRuns(List<RunHistoryDay> days) {
  return days.fold<int>(0, (value, day) => math.max(value, day.totalRuns));
}

// 汇总 Dashboard 顶部健康状态，保持摘要优先、细节后置。
(String, StudioStatusTone, String) _dashboardHealth(
  StudioRuntimeSnapshot snapshot,
) {
  if (snapshot.connectionStatus == ConnectionStatus.error ||
      snapshot.appiumStatus == AppiumProcessStatus.error) {
    return ('需处理', StudioStatusTone.error, '设备或驱动需处理。');
  }
  if (snapshot.runStatus == RunStatus.running) {
    return ('运行中', StudioStatusTone.running, '流程运行中，可在运行或记录查看。');
  }
  if (snapshot.runStatus == RunStatus.paused) {
    return ('人工处理', StudioStatusTone.warning, '已暂停，等待确认。');
  }
  if (snapshot.connectionStatus == ConnectionStatus.connected &&
      snapshot.appiumStatus == AppiumProcessStatus.running &&
      _snapshotWorkflowIsRunnable(snapshot)) {
    return ('就绪', StudioStatusTone.ready, '设备、驱动、流程已就绪。');
  }
  return ('需设置', StudioStatusTone.warning, '请先连接 iPhone。');
}

StudioStatusTone _toneForDashboardWorkflow(String status) {
  if (status == '就绪') return StudioStatusTone.ready;
  return _toneForRunStatus(status);
}

Map<String, int> _workflowNodeTypeSummary(WorkflowDefinition workflow) {
  final counts = <String, int>{};
  for (final node in workflow.nodes) {
    final label = _workflowNodeTypeLabel(node.type);
    counts[label] = (counts[label] ?? 0) + 1;
  }
  return counts;
}

String _workflowNodeTypeLabel(WorkflowNodeType type) {
  return switch (type) {
    WorkflowNodeType.start => '开始',
    WorkflowNodeType.tap => '点击',
    WorkflowNodeType.wait => '等待',
    WorkflowNodeType.swipe => '滑动',
    WorkflowNodeType.input => '输入',
    WorkflowNodeType.snapshot => '截图',
    WorkflowNodeType.condition => '条件',
    WorkflowNodeType.visualBranch => '视觉分支',
    WorkflowNodeType.waitForTarget => '等目标',
    WorkflowNodeType.loop => '循环',
    WorkflowNodeType.catchNodes => '异常',
    WorkflowNodeType.subWorkflow => '子流程',
    WorkflowNodeType.end => '结束',
  };
}
