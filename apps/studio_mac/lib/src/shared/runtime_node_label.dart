part of '../studio_mac_workspace.dart';

// 把 Runtime 节点类型转成短中文，避免主界面展示底层枚举。
String _runtimeNodeTypeLabel(String nodeType) {
  return switch (nodeType) {
    'tap' => '点击',
    'wait' => '等待',
    'swipe' => '滑动',
    'input' => '输入',
    'snapshot' => '截图',
    'condition' => '条件',
    'visualBranch' => '看图',
    'loop' => '重复',
    'catch' => '兜底',
    'subWorkflow' => '子流程',
    _ => '节点',
  };
}
