part of '../studio_mac_workspace.dart';

// 根据可见事件计算控制台总体状态色。
StudioStatusTone _consoleTone(List<RuntimeEvent> events) {
  if (events.any((event) => _runtimeLevelLabel(event.level) == '错误')) {
    return StudioStatusTone.error;
  }
  if (events.any((event) => _runtimeLevelLabel(event.level) == '提醒')) {
    return StudioStatusTone.warning;
  }
  if (events.isEmpty) {
    return StudioStatusTone.offline;
  }
  return StudioStatusTone.running;
}

// 生成控制台折叠态摘要。
String _consoleSummary(List<RuntimeEvent> events) {
  if (events.isEmpty) return '暂无控制台事件';
  final latest = events.last;
  return '[${_runtimeLevelLabel(latest.level)}] ${_safeRuntimeEventMessage(latest.message)}';
}

// 把 Runtime 事件级别转成短中文。
String _runtimeLevelLabel(String level) {
  return switch (level) {
    'error' || '错误' => '错误',
    'warning' || '提醒' => '提醒',
    'info' || '信息' => '信息',
    _ => level,
  };
}

// 返回事件级别对应的文本颜色。
Color _eventColor(String level) {
  return switch (level) {
    'error' || '错误' => StudioColors.red,
    'warning' || '提醒' => StudioColors.amber,
    'info' || '信息' => StudioColors.cyan,
    _ => StudioColors.muted,
  };
}

// 返回事件级别对应的状态色。
StudioStatusTone _eventTone(String level) {
  return switch (level) {
    'error' || '错误' => StudioStatusTone.error,
    'warning' || '提醒' => StudioStatusTone.warning,
    'info' || '信息' => StudioStatusTone.running,
    _ => StudioStatusTone.offline,
  };
}

// 将 Runtime 英文和底层错误信息转换成短中文，并做基础脱敏。
String _safeRuntimeEventMessage(String message) {
  final localized = switch (message) {
    'Studio runtime initialized' => '运行时已初始化',
    'Studio runtime initialized in Flutter shell mode.' => '运行时已初始化',
    'Run queued.' => '运行已排队。',
    'Starting workflow.' => '开始流程。',
    'Sending preview tap to device.' => '发送点击。',
    'Sending preview double tap to device.' => '发送双击。',
    'Sending preview long press to device.' => '发送长按。',
    'Sending preview swipe to device.' => '发送滑动。',
    'Cannot tap device preview before device is connected.' => '请先连接设备。',
    'Cannot double tap device preview before device is connected.' => '请先连接设备。',
    'Cannot long press device preview before device is connected.' => '请先连接设备。',
    'Cannot swipe device preview before device is connected.' => '请先连接设备。',
    'Cannot tap device preview while execution is active.' => '运行中不可操作。',
    'Cannot double tap device preview while execution is active.' => '运行中不可操作。',
    'Cannot long press device preview while execution is active.' => '运行中不可操作。',
    'Cannot swipe device preview while execution is active.' => '运行中不可操作。',
    'Execution paused for manual intervention.' => '运行已暂停，等待人工处理。',
    'Condition confidence was too low.' => '条件置信度过低。',
    'Stop requested after current wait.' => '等待结束后停止。',
    _ => message,
  };
  return localized
      .replaceAll('Appium has not been checked yet.', '尚未检查驱动。')
      .replaceAll('Checking local Appium and Xcode stack.', '正在检查本机环境。')
      .replaceAll('Checking Appium status.', '正在检查驱动。')
      .replaceAll('Checking Appium status...', '正在检查驱动。')
      .replaceAll('Starting Appium...', '正在启动驱动。')
      .replaceAll('Starting Appium process.', '正在启动驱动。')
      .replaceAll(
        'Appium process started. Waiting for readiness...',
        '驱动已启动，等待就绪。',
      )
      .replaceAll('Appium is ready.', '驱动已就绪。')
      .replaceAll(RegExp(r'Appium is ready\. PID \d+\.'), '驱动已就绪。')
      .replaceAll('Appium readiness failed:', '驱动就绪失败：')
      .replaceAll(
        RegExp(r'Appium did not become ready before timeout\..*'),
        '驱动启动超时。',
      )
      .replaceAll('Appium readiness has not been checked yet.', '尚未检查驱动。')
      .replaceAll(
        RegExp(
          r'Unable to reach Appium: (?:Connection failed|Connection refused|[^.]+)\.',
        ),
        '未发现本机驱动。请点连接设备；若仍失败，点查环境。',
      )
      .replaceAll(
        RegExp(r'Timed out while requesting /status\.'),
        '驱动没有响应。请停止后重启；若仍失败，点查环境。',
      )
      .replaceAll(
        RegExp(r'Appium response was not an object\.'),
        '驱动响应异常。请停止后重启；若仍失败，点查环境。',
      )
      .replaceAll(
        RegExp(r'Invalid Appium JSON: [^.]+\.'),
        '驱动响应异常。请停止后重启；若仍失败，点查环境。',
      )
      .replaceAll('Unable to start Appium.', '驱动启动失败。')
      .replaceAll('Stopping Appium...', '正在停止驱动。')
      .replaceAll('Stopping Appium process.', '正在停止驱动。')
      .replaceAll('Appium stopped.', '驱动已停止。')
      .replaceAll('Creating WebDriver session...', '正在连接手机会话。')
      .replaceAll('Creating WebDriver session.', '正在连接手机会话。')
      .replaceAll('WebDriver session connected.', '手机会话已连接。')
      .replaceAll('Unable to create WebDriver session.', '手机会话连接失败。')
      .replaceAll('WebDriver session failed:', '手机会话失败：')
      .replaceAll('Deleting WebDriver session...', '正在断开手机会话。')
      .replaceAll('Deleting WebDriver session.', '正在断开手机会话。')
      .replaceAll('WebDriver session disconnected.', '手机会话已断开。')
      .replaceAll('Connected state has no session id.', '会话缺失，请重连。')
      .replaceAll('Capturing screenshot:', '正在截图：')
      .replaceAll('Screenshot captured.', '截图完成。')
      .replaceAll('Screenshot failed:', '截图失败：')
      .replaceAll('Preview tap failed:', '预览点击失败：')
      .replaceAll(
        'Preview tap position must stay inside the visible device screen.',
        '点击位置需在画面内。',
      )
      .replaceAll('Preview tap release actions failed:', '点击收尾失败：')
      .replaceAll('Preview double tap failed:', '预览双击失败：')
      .replaceAll(
        'Preview double tap position must stay inside the visible device screen.',
        '双击位置需在画面内。',
      )
      .replaceAll('Preview double tap release actions failed:', '双击收尾失败：')
      .replaceAll('Preview long press failed:', '预览长按失败：')
      .replaceAll(
        'Preview long press duration must be zero or greater.',
        '长按时长不能小于 0。',
      )
      .replaceAll(
        'Preview long press position must stay inside the visible device screen.',
        '长按位置需在画面内。',
      )
      .replaceAll('Preview long press release actions failed:', '长按收尾失败：')
      .replaceAll('Preview swipe failed:', '预览滑动失败：')
      .replaceAll(
        'Preview swipe duration must be zero or greater.',
        '滑动时长不能小于 0。',
      )
      .replaceAll(
        'Preview swipe positions must stay inside the visible device screen.',
        '滑动位置需在画面内。',
      )
      .replaceAll('Preview swipe release actions failed:', '滑动收尾失败：')
      .replaceAll('Run loop count must be at least 1.', '轮数至少为 1。')
      .replaceAll('Cannot start a run while busy.', '忙碌中，暂不能运行。')
      .replaceAll('Run paused:', '运行已暂停：')
      .replaceAll('Run failed:', '运行失败：')
      .replaceAll('No active run to stop.', '当前没有运行。')
      .replaceAll('Paused run stopped safely.', '已安全停止。')
      .replaceAll('Workflow save failed:', '流程保存失败：')
      .replaceAll('Workflow updated:', '流程已更新：')
      .replaceAll('Settings save failed:', '设置保存失败：')
      .replaceAll('Settings updated.', '设置已更新。')
      .replaceAll('Run history refresh failed:', '记录刷新失败：')
      .replaceAll('Run detail read failed:', '详情读取失败：')
      .replaceAll('Evidence start failed:', '证据开始失败：')
      .replaceAll('Evidence finish failed:', '证据收尾失败：')
      .replaceAll('Evidence event failed:', '证据事件失败：')
      .replaceAll('Screenshot evidence failed:', '截图证据失败：')
      .replaceAll('is ready', '已就绪')
      .replaceAll('not ready', '未就绪')
      .replaceAll('ready', '就绪')
      .replaceAll('starting', '启动中')
      .replaceAll('Appium', '驱动')
      .replaceAll('WDA', '会话')
      .replaceAll('WebDriver', '手机会话')
      .replaceAll('Flutter', '应用')
      .replaceAll('[device]', '[标识]')
      .replaceAll('[path]', '[本机路径]')
      .replaceAll('[local-url]', '[本机地址]')
      .replaceAll('[id]', '[编号]')
      .replaceAll(
        RegExp(
          r'https?://(?:127\.0\.0\.1|localhost|\[?::1\]?)(?::\d+)?[^\s,;]*',
        ),
        '[本机地址]',
      )
      .replaceAll(RegExp(r'/Users/[^\s,;]+'), '[本机路径]')
      .replaceAll(RegExp(r'\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{12,}\b'), '[标识]')
      .replaceAll(RegExp(r'\b[0-9A-Fa-f]{20,}\b'), '[标识]');
}

// 生成事件列表可复制文本。
String _eventsText(List<RuntimeEvent> events) {
  if (events.isEmpty) return '暂无控制台事件';
  return events.map(_eventText).join('\n');
}

// 生成单条事件的可复制文本。
String _eventText(RuntimeEvent event) {
  return '[${_timeOnly(event.at)}] ${_runtimeLevelLabel(event.level)} ${_safeRuntimeEventMessage(event.message)}';
}

// 生成检查标签页可复制文本。
String _inspectorText(StudioRuntimeSnapshot snapshot) {
  final diagnostic = snapshot.lastConnectionDiagnostic;
  return <String>[
    '设备：${_deviceStatusLabel(snapshot.connectionStatus)}',
    '驱动：${_appiumStatusLabel(snapshot.appiumStatus)}',
    '运行：${_runStatusLabel(snapshot.runStatus)}',
    '流程：${snapshot.workflow.name}',
    '会话：${snapshot.sessionId == null ? '无' : _shortSession(snapshot.sessionId!)}',
    '截图：${snapshot.latestScreenshotAt == null ? '无' : _timeOnly(snapshot.latestScreenshotAt!)}',
    if (diagnostic != null) '连接诊断：${diagnostic.summary} ${diagnostic.nextStep}',
  ].join('\n');
}

// 生成网络标签页可复制文本，只包含本机驱动通道摘要。
String _networkText(StudioRuntimeSnapshot snapshot) {
  final diagnostic = snapshot.lastConnectionDiagnostic;
  return <String>[
    '通道：应用 -> 本机驱动 -> 手机',
    '协议：本机驱动',
    '驱动：${_appiumStatusLabel(snapshot.appiumStatus)}',
    '手机：${_deviceStatusLabel(snapshot.connectionStatus)}',
    '会话：${snapshot.sessionId == null ? '无' : _shortSession(snapshot.sessionId!)}',
    '消息：${_safeRuntimeEventMessage(snapshot.appiumMessage)}',
    if (diagnostic != null) '连接诊断：${diagnostic.summary} ${diagnostic.nextStep}',
  ].join('\n');
}

// 生成调试标签页可复制文本，避免暴露完整设备或会话信息。
String _debugText(StudioRuntimeSnapshot snapshot) {
  final workflowValidation = _snapshotWorkflowValidation(snapshot);
  final diagnostic = snapshot.lastConnectionDiagnostic;
  return <String>[
    '运行时：桌面应用',
    '驱动：本机驱动 / 手机会话',
    '流程有效：${workflowValidation.isValid ? '是' : '否'}',
    '流程节点：${snapshot.workflow.nodes.length}',
    '最近记录：${snapshot.runHistory.recentRuns.length}',
    '驱动消息：${_safeRuntimeEventMessage(snapshot.appiumMessage)}',
    if (diagnostic != null) '连接诊断：${diagnostic.summary} ${diagnostic.nextStep}',
  ].join('\n');
}
