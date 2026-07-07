part of '../../studio_mac_workspace.dart';

// Workflow 子流程模板分片，承载 Inspector 注册用的安全子流程。
// 子流程模板不进入普通模板抽屉，避免误以为会直接运行。

/// 生成本地示例子流程。
/// 子流程只包含等待节点，避免注册后默认产生点击。
WorkflowDefinition _starterSubWorkflowTemplate() {
  return const WorkflowDefinition(
    id: 'starter-sub-workflow',
    name: '示例子流程',
    entryNodesId: 'start',
    nodes: [
      WorkflowNode(
        id: 'start',
        type: WorkflowNodeType.start,
        label: '开始',
        next: ['wait_ready'],
      ),
      WorkflowNode(
        id: 'wait_ready',
        type: WorkflowNodeType.wait,
        label: '等一下',
        next: ['end'],
        parameters: {'ms': 300},
      ),
      WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
    ],
  );
}
