part of '../../studio_mac_workspace.dart';

// Workflow 控制流模板分片，承载条件、循环和异常兜底。
// 模板只声明安全 DSL 结构，不开放脚本或任意代码执行。

/// 生成条件分支模板。
/// 模板只示范读取 context 表达式，不开放脚本执行。
WorkflowDefinition _conditionBranchTemplate() {
  return const WorkflowDefinition(
    id: 'condition-branch-template',
    name: '条件分支',
    entryNodesId: 'start',
    nodes: [
      WorkflowNode(
        id: 'start',
        type: WorkflowNodeType.start,
        label: '开始',
        next: ['condition_1'],
      ),
      WorkflowNode(
        id: 'condition_1',
        type: WorkflowNodeType.condition,
        label: '有截图？',
        next: ['tap_continue', 'wait_review'],
        parameters: {'expression': 'context.hasScreenshot'},
      ),
      WorkflowNode(
        id: 'tap_continue',
        type: WorkflowNodeType.tap,
        label: '继续点击',
        next: ['end'],
        parameters: {'label': '继续', 'x': 160, 'y': 480},
      ),
      WorkflowNode(
        id: 'wait_review',
        type: WorkflowNodeType.wait,
        label: '等待确认',
        next: ['end'],
        parameters: {'ms': 500},
      ),
      WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
    ],
  );
}

/// 生成批量循环模板。
/// 模板展示 bounded Loop 的主体和循环后续分支。
WorkflowDefinition _loopBatchTemplate() {
  return const WorkflowDefinition(
    id: 'loop-batch-template',
    name: '批量循环',
    entryNodesId: 'start',
    nodes: [
      WorkflowNode(
        id: 'start',
        type: WorkflowNodeType.start,
        label: '开始',
        next: ['loop_batch'],
      ),
      WorkflowNode(
        id: 'loop_batch',
        type: WorkflowNodeType.loop,
        label: '循环 3 次',
        next: ['tap_item', 'snapshot_done'],
        parameters: {'count': 3},
      ),
      WorkflowNode(
        id: 'tap_item',
        type: WorkflowNodeType.tap,
        label: '处理一项',
        next: ['wait_item'],
        parameters: {'label': '处理', 'x': 180, 'y': 520},
      ),
      WorkflowNode(
        id: 'wait_item',
        type: WorkflowNodeType.wait,
        label: '等一下',
        next: ['loop_batch'],
        parameters: {'ms': 500},
      ),
      WorkflowNode(
        id: 'snapshot_done',
        type: WorkflowNodeType.snapshot,
        label: '完成截图',
        next: ['end'],
        parameters: {'saveEvidence': true},
      ),
      WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
    ],
  );
}

/// 生成异常兜底模板。
/// 模板展示 Catch 主路径和 onError 分支的安全重试边界。
WorkflowDefinition _catchRetryTemplate() {
  return const WorkflowDefinition(
    id: 'catch-retry-template',
    name: '异常兜底',
    entryNodesId: 'start',
    nodes: [
      WorkflowNode(
        id: 'start',
        type: WorkflowNodeType.start,
        label: '开始',
        next: ['catch_guard'],
      ),
      WorkflowNode(
        id: 'catch_guard',
        type: WorkflowNodeType.catchNodes,
        label: '失败重试',
        next: ['tap_primary'],
        parameters: {'maxRetries': 2, 'onError': 'wait_recover'},
      ),
      WorkflowNode(
        id: 'tap_primary',
        type: WorkflowNodeType.tap,
        label: '主要点击',
        next: ['end'],
        parameters: {'label': '主要', 'x': 180, 'y': 520},
      ),
      WorkflowNode(
        id: 'wait_recover',
        type: WorkflowNodeType.wait,
        label: '人工兜底',
        next: ['end'],
        parameters: {'ms': 1000},
      ),
      WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
    ],
  );
}
