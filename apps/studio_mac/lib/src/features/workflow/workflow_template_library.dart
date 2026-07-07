part of '../../studio_mac_workspace.dart';

// 本地模板库入口，只登记可导入的 Project DSL 模板。
// 具体模板结构按基础、视觉、控制流和子流程分片维护。
final _workflowTemplates = <_WorkflowTemplate>[
  _WorkflowTemplate(
    id: 'blank-workflow',
    name: '空白流程',
    category: '新建',
    description: '只有开始和结束，从这里搭建。',
    icon: Icons.note_add_outlined,
    workflow: _blankWorkflowTemplate(),
  ),
  _WorkflowTemplate(
    id: 'af-basic',
    name: 'A-F 基础模板',
    category: '旧版',
    description: '兼容旧坐标的 A-F 基础流程。',
    icon: Icons.account_tree_outlined,
    workflow: WorkflowDefinition.afTemplate(),
  ),
  _WorkflowTemplate(
    id: 'visual-guard',
    name: '视觉守卫',
    category: '视觉',
    description: '截图后做视觉判断，低置信会暂停。',
    icon: Icons.visibility_outlined,
    workflow: _visualGuardTemplate(),
  ),
  _WorkflowTemplate(
    id: 'condition-branch',
    name: '条件分支',
    category: '逻辑',
    description: '读取上下文字段，不执行脚本。',
    icon: Icons.fork_right_outlined,
    workflow: _conditionBranchTemplate(),
  ),
  _WorkflowTemplate(
    id: 'loop-batch',
    name: '批量循环',
    category: '循环',
    description: '按固定次数串行处理，循环结束后截图留证。',
    icon: Icons.repeat_outlined,
    workflow: _loopBatchTemplate(),
  ),
  _WorkflowTemplate(
    id: 'catch-retry',
    name: '异常兜底',
    category: '兜底',
    description: '动作失败时安全重试，超过次数走兜底分支。',
    icon: Icons.safety_check_outlined,
    workflow: _catchRetryTemplate(),
  ),
];
