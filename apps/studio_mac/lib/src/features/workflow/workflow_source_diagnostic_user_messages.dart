part of '../../studio_mac_workspace.dart';

// Source 诊断用户文案映射，负责把 validator 输出转成普通用户可读短句。
// 该文件只服务 Validate、Canvas 和 Inspector，不承担源码定位。

// 将底层 validator 文案结合 workflow 上下文翻译成普通用户可读的短中文。
String _workflowDiagnosticMessageForWorkflow(
  String message,
  WorkflowDefinition workflow,
) {
  final inputRequired = RegExp(
    r'^Input node ([A-Za-z0-9_-]+) text is required\.$',
  ).firstMatch(message);
  if (inputRequired != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, inputRequired.group(1)!)} 文本必填。';
  }

  final inputBranch = RegExp(
    r'^Input node ([A-Za-z0-9_-]+) can have only one main branch\.$',
  ).firstMatch(message);
  if (inputBranch != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, inputBranch.group(1)!)} 只能有一个主线。';
  }

  final missingEntry = RegExp(
    r'^Entry node does not exist: ([^ .]+)\.$',
  ).firstMatch(message);
  if (missingEntry != null) {
    return '入口节点不存在，请重新选择入口。';
  }

  final invalidEntry = RegExp(
    r'^Entry node ([A-Za-z0-9_-]+) must be a Start node\.$',
  ).firstMatch(message);
  if (invalidEntry != null) {
    return '入口必须从开始节点进入。';
  }

  final startBranch = RegExp(
    r'^Start node ([A-Za-z0-9_-]+) can have only one main branch\.$',
  ).firstMatch(message);
  if (startBranch != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, startBranch.group(1)!)} 只能有一条主线。';
  }

  final endBranch = RegExp(
    r'^End node ([A-Za-z0-9_-]+) cannot have outgoing branches\.$',
  ).firstMatch(message);
  if (endBranch != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, endBranch.group(1)!)} 不能继续连接。';
  }

  final tapInteger = RegExp(
    r'^Tap node ([A-Za-z0-9_-]+) (x|y) must be an integer\.$',
  ).firstMatch(message);
  if (tapInteger != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, tapInteger.group(1)!)} ${_workflowDiagnosticFieldLabel(tapInteger.group(2)!)}需填写数字。';
  }

  final waitDuration = RegExp(
    r'^Wait node ([A-Za-z0-9_-]+) ms must be non-negative\.$',
  ).firstMatch(message);
  if (waitDuration != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, waitDuration.group(1)!)} 等待需为 0 或更大。';
  }

  final swipeInteger = RegExp(
    r'^Swipe node ([A-Za-z0-9_-]+) (fromX|fromY|toX|toY) must be an integer\.$',
  ).firstMatch(message);
  if (swipeInteger != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, swipeInteger.group(1)!)} ${_workflowDiagnosticFieldLabel(swipeInteger.group(2)!)}需填写数字。';
  }

  final swipeDuration = RegExp(
    r'^Swipe node ([A-Za-z0-9_-]+) durationMs must be non-negative\.$',
  ).firstMatch(message);
  if (swipeDuration != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, swipeDuration.group(1)!)} 时长需为 0 或更大。';
  }

  final duplicateNode = RegExp(
    r'^Duplicate node id: ([^ .]+)\.$',
  ).firstMatch(message);
  if (duplicateNode != null) {
    return '有重复节点，请检查源码。';
  }

  final missingNext = RegExp(
    r'^Nodes? ([A-Za-z0-9_-]+) references missing node ([A-Za-z0-9_-]+)\.$',
  ).firstMatch(message);
  if (missingNext != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, missingNext.group(1)!)} 指向不存在的目标。';
  }

  final selfNext = RegExp(
    r'^Nodes ([A-Za-z0-9_-]+) cannot reference itself\.$',
  ).firstMatch(message);
  if (selfNext != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, selfNext.group(1)!)} 不能连接自己。';
  }

  final selfCatch = RegExp(
    r'^Catch node ([A-Za-z0-9_-]+) cannot reference itself onError\.$',
  ).firstMatch(message);
  if (selfCatch != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, selfCatch.group(1)!)} 的错误分支不能指向自己。';
  }

  final missingWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) references missing workflow ([^ .]+)\.$',
  ).firstMatch(message);
  if (missingWorkflow != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, missingWorkflow.group(1)!)} 没有选到可用子流程。';
  }

  final selfWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) cannot reference itself\.$',
  ).firstMatch(message);
  if (selfWorkflow != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, selfWorkflow.group(1)!)} 不能引用当前流程。';
  }

  final inputMapObject = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) inputMap must be an object\.$',
  ).firstMatch(message);
  if (inputMapObject != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, inputMapObject.group(1)!)} 的参数格式不对。';
  }

  final inputMapKey = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) inputMap key ([^ ]+) is invalid\.$',
  ).firstMatch(message);
  if (inputMapKey != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, inputMapKey.group(1)!)} 的参数名不可用。';
  }

  final inputMapValue = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) inputMap value for ([^ ]+) must read context\.$',
  ).firstMatch(message);
  if (inputMapValue != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, inputMapValue.group(1)!)} 的参数只能读取上下文。';
  }

  final recursiveWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) creates recursive workflow reference ([^ .]+)\.$',
  ).firstMatch(message);
  if (recursiveWorkflow != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, recursiveWorkflow.group(1)!)} 会造成子流程循环。';
  }

  final missingNestedWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) references workflow ([^ .]+) with missing nested workflow ([^ .]+)\.$',
  ).firstMatch(message);
  if (missingNestedWorkflow != null) {
    return '${_workflowDiagnosticNodeLabel(workflow, missingNestedWorkflow.group(1)!)} 的子流程链不完整。';
  }

  return _workflowDiagnosticMessage(message);
}

// 将节点 ID 映射为节点名称，缺失时只给用户显示“目标节点”。
String _workflowDiagnosticNodeLabel(
  WorkflowDefinition workflow,
  String nodeId,
) {
  final label = _workflowNodeDisplayLabel(workflow, nodeId);
  return label.startsWith('缺失 ') ? '目标节点' : label;
}

// 将 Source 字段名映射为短中文字段，避免 Validate / Inspector 暴露底层字段。
String _workflowDiagnosticFieldLabel(String field) {
  return switch (field) {
    'id' => '标识',
    'name' => '名称',
    'entryNodesId' => '入口',
    'visual' => '位置',
    'expression' => '条件',
    'confidenceThreshold' => '置信',
    'x' => '横',
    'y' => '纵',
    'ms' => '等待',
    'fromX' => '起横',
    'fromY' => '起纵',
    'toX' => '终横',
    'toY' => '终纵',
    'durationMs' => '时长',
    'text' => '文本',
    'count' => '次数',
    'maxRetries' => '重试',
    'workflowId' => '子流程',
    'inputMap' => '参数',
    'onError' => '错误分支',
    'next' => '后续',
    _ => '字段',
  };
}
