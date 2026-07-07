part of '../../studio_mac_workspace.dart';

// Source 诊断文案映射，负责把底层 validator 输出转成短中文。
// 该文件只做展示翻译，不改变 validator 结果和 workflow 真源。

// 将底层 validator 文案翻译成短中文。
String _workflowDiagnosticMessage(String message) {
  final inputRequired = RegExp(
    r'^Input node ([A-Za-z0-9_-]+) text is required\.$',
  ).firstMatch(message);
  if (inputRequired != null) {
    return '输入节点 ${inputRequired.group(1)} 文本必填。';
  }

  final inputBranch = RegExp(
    r'^Input node ([A-Za-z0-9_-]+) can have only one main branch\.$',
  ).firstMatch(message);
  if (inputBranch != null) {
    return '输入节点 ${inputBranch.group(1)} 只能有一个主分支。';
  }

  final missingEntry = RegExp(
    r'^Entry node does not exist: ([^ .]+)\.$',
  ).firstMatch(message);
  if (missingEntry != null) {
    return '入口节点不存在：${missingEntry.group(1)}。';
  }

  final invalidEntry = RegExp(
    r'^Entry node ([A-Za-z0-9_-]+) must be a Start node\.$',
  ).firstMatch(message);
  if (invalidEntry != null) {
    return '入口必须是开始节点：${invalidEntry.group(1)}。';
  }

  final startBranch = RegExp(
    r'^Start node ([A-Za-z0-9_-]+) can have only one main branch\.$',
  ).firstMatch(message);
  if (startBranch != null) {
    return '开始节点 ${startBranch.group(1)} 只能有一条主线。';
  }

  final endBranch = RegExp(
    r'^End node ([A-Za-z0-9_-]+) cannot have outgoing branches\.$',
  ).firstMatch(message);
  if (endBranch != null) {
    return '结束节点 ${endBranch.group(1)} 不能继续连接。';
  }

  final tapInteger = RegExp(
    r'^Tap node ([A-Za-z0-9_-]+) (x|y) must be an integer\.$',
  ).firstMatch(message);
  if (tapInteger != null) {
    return '点击节点 ${tapInteger.group(1)} ${_workflowDiagnosticFieldLabel(tapInteger.group(2)!)}需填写数字。';
  }

  final waitDuration = RegExp(
    r'^Wait node ([A-Za-z0-9_-]+) ms must be non-negative\.$',
  ).firstMatch(message);
  if (waitDuration != null) {
    return '等待节点 ${waitDuration.group(1)} 等待需为 0 或更大。';
  }

  final swipeInteger = RegExp(
    r'^Swipe node ([A-Za-z0-9_-]+) (fromX|fromY|toX|toY) must be an integer\.$',
  ).firstMatch(message);
  if (swipeInteger != null) {
    return '滑动节点 ${swipeInteger.group(1)} ${_workflowDiagnosticFieldLabel(swipeInteger.group(2)!)}需填写数字。';
  }

  final swipeDuration = RegExp(
    r'^Swipe node ([A-Za-z0-9_-]+) durationMs must be non-negative\.$',
  ).firstMatch(message);
  if (swipeDuration != null) {
    return '滑动节点 ${swipeDuration.group(1)} 时长需为 0 或更大。';
  }

  final duplicateNode = RegExp(
    r'^Duplicate node id: ([^ .]+)\.$',
  ).firstMatch(message);
  if (duplicateNode != null) {
    return '节点 ID 重复：${duplicateNode.group(1)}。';
  }

  final missingNext = RegExp(
    r'^Nodes? ([A-Za-z0-9_-]+) references missing node ([A-Za-z0-9_-]+)\.$',
  ).firstMatch(message);
  if (missingNext != null) {
    return '节点 ${missingNext.group(1)} 指向不存在的节点 ${missingNext.group(2)}。';
  }

  final selfNext = RegExp(
    r'^Nodes ([A-Za-z0-9_-]+) cannot reference itself\.$',
  ).firstMatch(message);
  if (selfNext != null) {
    return '节点 ${selfNext.group(1)} 不能连接自己。';
  }

  final selfCatch = RegExp(
    r'^Catch node ([A-Za-z0-9_-]+) cannot reference itself onError\.$',
  ).firstMatch(message);
  if (selfCatch != null) {
    return '异常节点 ${selfCatch.group(1)} 的错误分支不能指向自己。';
  }

  final missingWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) references missing workflow ([^ .]+)\.$',
  ).firstMatch(message);
  if (missingWorkflow != null) {
    return '子流程节点 ${missingWorkflow.group(1)} 引用了不存在的子流程 ${missingWorkflow.group(2)}。';
  }

  final selfWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) cannot reference itself\.$',
  ).firstMatch(message);
  if (selfWorkflow != null) {
    return '子流程节点 ${selfWorkflow.group(1)} 不能引用自己。';
  }

  final inputMapObject = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) inputMap must be an object\.$',
  ).firstMatch(message);
  if (inputMapObject != null) {
    return '子流程节点 ${inputMapObject.group(1)} 的传入参数格式不对。';
  }

  final inputMapKey = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) inputMap key ([^ ]+) is invalid\.$',
  ).firstMatch(message);
  if (inputMapKey != null) {
    return '子流程节点 ${inputMapKey.group(1)} 的参数名 ${inputMapKey.group(2)} 不可用。';
  }

  final inputMapValue = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) inputMap value for ([^ ]+) must read context\.$',
  ).firstMatch(message);
  if (inputMapValue != null) {
    return '子流程节点 ${inputMapValue.group(1)} 的参数 ${inputMapValue.group(2)} 只能读取上下文。';
  }

  final recursiveWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) creates recursive workflow reference ([^ .]+)\.$',
  ).firstMatch(message);
  if (recursiveWorkflow != null) {
    return '子流程节点 ${recursiveWorkflow.group(1)} 会造成循环引用：${recursiveWorkflow.group(2)}。';
  }

  final missingNestedWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) references workflow ([^ .]+) with missing nested workflow ([^ .]+)\.$',
  ).firstMatch(message);
  if (missingNestedWorkflow != null) {
    return '子流程节点 ${missingNestedWorkflow.group(1)} 的子流程链缺少：${missingNestedWorkflow.group(3)}。';
  }

  return message;
}
