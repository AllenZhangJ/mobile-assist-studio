part of '../../studio_mac_workspace.dart';

// Workflow 基础模板分片，承载从零开始的安全流程。
// 这些模板只生成 Project DSL，不连接设备、不启动执行。

/// 生成空白流程模板。
/// 这是从零创建工作流的安全起点，只包含开始和结束。
WorkflowDefinition _blankWorkflowTemplate() {
  return const WorkflowDefinition(
    id: 'blank-workflow-template',
    name: '空白流程',
    entryNodesId: 'start',
    nodes: [
      WorkflowNode(
        id: 'start',
        type: WorkflowNodeType.start,
        label: '开始',
        next: ['end'],
      ),
      WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
    ],
  );
}
