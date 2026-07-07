part of '../studio_mac_workspace.dart';

// 流程准备项 helper，负责把项目级校验结果转成跨页面状态。

/// 将项目级流程校验转成用户可懂的准备度条目。
/// 无效流程只给修正入口，不允许误导为可运行。
_ReadinessGuideEntry _workflowReadinessEntry(
  WorkflowValidateResult validation,
) {
  if (validation.isValid) {
    return const _ReadinessGuideEntry(
      label: '流程文件',
      status: '就绪',
      summary: '当前流程校验通过。',
      nextStep: '设备就绪后可运行测试。',
      tone: StudioStatusTone.ready,
      icon: Icons.account_tree_outlined,
    );
  }
  return const _ReadinessGuideEntry(
    label: '流程文件',
    status: '提醒',
    summary: '流程需先修正。',
    nextStep: '打开流程，修正后保存。',
    tone: StudioStatusTone.warning,
    icon: Icons.account_tree_outlined,
  );
}
