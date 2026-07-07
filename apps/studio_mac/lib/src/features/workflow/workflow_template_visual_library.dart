part of '../../studio_mac_workspace.dart';

// Workflow 视觉模板分片，承载截图和视觉判断相关 Project DSL。
// 当前只做安全示例，不包含 OCR、CV 或 AI 自动修复。

/// 生成视觉守卫模板。
/// 模板展示 Snapshot 到 Visual Branch 的基础链路。
WorkflowDefinition _visualGuardTemplate() {
  return const WorkflowDefinition(
    id: 'visual-guard-template',
    name: '视觉守卫',
    entryNodesId: 'start',
    nodes: [
      WorkflowNode(
        id: 'start',
        type: WorkflowNodeType.start,
        label: '开始',
        next: ['snapshot_1'],
      ),
      WorkflowNode(
        id: 'snapshot_1',
        type: WorkflowNodeType.snapshot,
        label: '截图',
        next: ['visual_1'],
        parameters: {'saveEvidence': true},
      ),
      WorkflowNode(
        id: 'visual_1',
        type: WorkflowNodeType.visualBranch,
        label: '查屏幕',
        next: ['tap_safe'],
        parameters: {'confidenceThreshold': 0.72},
      ),
      WorkflowNode(
        id: 'tap_safe',
        type: WorkflowNodeType.tap,
        label: '安全点击',
        next: ['end'],
        parameters: {'label': '安全', 'x': 120, 'y': 420},
      ),
      WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
    ],
  );
}
