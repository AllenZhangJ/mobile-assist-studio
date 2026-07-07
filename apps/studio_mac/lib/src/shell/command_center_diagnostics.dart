part of '../studio_mac_workspace.dart';

// 生成命令中心可复制诊断摘要，只包含安全、短句、可沟通的工作台状态。
String _commandDiagnosticsSummary(StudioRuntimeSnapshot snapshot) {
  final workflowValidation = _snapshotWorkflowValidation(snapshot);
  final diagnostic = snapshot.lastConnectionDiagnostic;
  final latestEvent = snapshot.events.isEmpty
      ? '无'
      : _safeRuntimeEventMessage(snapshot.events.last.message);
  return <String>[
    '应用：本机工作台',
    '设备：${_deviceStatusLabel(snapshot.connectionStatus)}',
    '驱动：${_appiumStatusLabel(snapshot.appiumStatus)}',
    '运行：${_runStatusLabel(snapshot.runStatus)}',
    '流程：${snapshot.workflow.name}',
    '流程状态：${_workflowStatusLabel(workflowValidation)}',
    if (diagnostic != null) '连接诊断：${diagnostic.summary} ${diagnostic.nextStep}',
    '节点：${snapshot.workflow.nodes.length}',
    '记录：${snapshot.runHistory.recentRuns.length}',
    '事件：${snapshot.events.length}',
    '最近：$latestEvent',
    '边界：本机、单设备、串行、无截图、无路径、无端点、无完整标识',
  ].join('\n');
}
