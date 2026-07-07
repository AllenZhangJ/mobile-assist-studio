part of '../studio_mac_workspace.dart';

// Monitor 问题分析文案与色调 helper。
// 这里只处理用户可见的问题分类和原因，不读取运行详情或证据文件。

// 将问题分类映射成状态色，供问题分析和聚类面板复用。
StudioStatusTone _toneForAnalysisCategory(String category) {
  return switch (category) {
    'None' || '无' => StudioStatusTone.ready,
    'Paused' || 'Stopped' || '暂停' || '已停' => StudioStatusTone.warning,
    _ => StudioStatusTone.error,
  };
}

// 将 Runtime 问题分类转成短中文，避免界面暴露英文枚举。
String _analysisCategoryLabel(String category) {
  return switch (category) {
    'None' => '无',
    'Paused' => '暂停',
    'Stopped' => '已停',
    'Low Confidence' => '低置信',
    'Timeout' => '超时',
    'Unsupported Node' => '不支持',
    'Driver Error' => '驱动错误',
    'Session Error' => '会话错误',
    _ => category,
  };
}

// 将底层失败原因转成用户可读文案，未知内容走脱敏消息。
String _analysisReasonLabel(String? reason) {
  return switch (reason) {
    null => '未记录原因。',
    'Execution paused for manual intervention.' => '运行已暂停，等待人工处理。',
    'Condition confidence was too low.' => '条件置信度过低。',
    _ => _safeRuntimeEventMessage(reason),
  };
}
