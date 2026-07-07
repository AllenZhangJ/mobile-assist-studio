part of '../../studio_mac_workspace.dart';

// 工作流上下文字段模型，描述条件表达式可读取的只读变量。
// 它独立于具体 UI，后续可复用于条件节点、变量池和帮助抽屉。
final class _WorkflowContextVariable {
  const _WorkflowContextVariable({
    required this.key,
    required this.name,
    required this.expression,
    required this.previewValue,
    required this.description,
  });

  final String key;
  final String name;
  final String expression;
  final String previewValue;
  final String description;
}

// 生成当前可读上下文字段，并把运行状态转成用户可理解的预览值。
List<_WorkflowContextVariable> _workflowContextVariables({
  required ConnectionStatus connectionStatus,
  required RunStatus runStatus,
  required DateTime? latestScreenshotAt,
  required RuntimeExecutionFocus executionFocus,
}) {
  final loopIndex = executionFocus.activeLoopIndex;
  final loopNumber = loopIndex == null ? null : loopIndex + 1;
  final totalLoops = executionFocus.totalLoops;
  return <_WorkflowContextVariable>[
    _WorkflowContextVariable(
      key: 'loop-index',
      name: '轮次索引',
      expression: 'context.loopIndex',
      previewValue: _contextPreview(loopIndex),
      description: '运行中的轮次索引。',
    ),
    _WorkflowContextVariable(
      key: 'loop-number',
      name: '当前轮次',
      expression: 'context.loopNumber',
      previewValue: _contextPreview(loopNumber),
      description: '当前运行轮次。',
    ),
    _WorkflowContextVariable(
      key: 'total-loops',
      name: '总轮数',
      expression: 'context.totalLoops',
      previewValue: _contextPreview(totalLoops),
      description: '本次运行总轮数。',
    ),
    _WorkflowContextVariable(
      key: 'has-screenshot',
      name: '已有截图',
      expression: 'context.hasScreenshot',
      previewValue: latestScreenshotAt == null ? '否' : '是',
      description: '是否已有本机截图。',
    ),
    _WorkflowContextVariable(
      key: 'connection-status',
      name: '设备状态',
      expression: 'context.connectionStatus',
      previewValue: _deviceStatusLabel(connectionStatus),
      description: '当前设备状态。',
    ),
    _WorkflowContextVariable(
      key: 'run-status',
      name: '运行状态',
      expression: 'context.runStatus',
      previewValue: _runStatusLabel(runStatus),
      description: '当前运行状态。',
    ),
    const _WorkflowContextVariable(
      key: 'sub-workflow-inputs',
      name: '子流程参数',
      expression: 'context.inputs.xxx',
      previewValue: '按参数名',
      description: '子流程传入参数。',
    ),
    _WorkflowContextVariable(
      key: 'execution-loop-index',
      name: '内部索引',
      expression: 'context.execution.loopIndex',
      previewValue: _contextPreview(loopIndex),
      description: '内部轮次索引。',
    ),
    _WorkflowContextVariable(
      key: 'execution-loop-number',
      name: '内部轮次',
      expression: 'context.execution.loopNumber',
      previewValue: _contextPreview(loopNumber),
      description: '内部轮次。',
    ),
    _WorkflowContextVariable(
      key: 'execution-total-loops',
      name: '内部总数',
      expression: 'context.execution.totalLoops',
      previewValue: _contextPreview(totalLoops),
      description: '内部总轮数。',
    ),
  ];
}

// 生成可复制的变量摘要，只包含安全表达式和脱敏预览值。
String _workflowContextVariablesSummary(
  List<_WorkflowContextVariable> variables,
) {
  final lines = <String>['可用变量'];
  for (final variable in variables) {
    lines.add(
      '- ${variable.name}: ${variable.expression} = ${variable.previewValue}',
    );
  }
  return lines.join('\n');
}

// 将空值显示成友好文案，避免用户看到 null 这类工程词。
String _contextPreview(Object? value) {
  if (value == null) return '未运行';
  return value.toString();
}
