part of '../../studio_mac_workspace.dart';

// 趋势窗口 helper，承载 Monitor 多个趋势面板共享的窗口语义。
List<RunHistoryDay> _trendRunsForWindow(
  RunHistorySummary history,
  _MonitorTrendWindow window,
) {
  return switch (window) {
    _MonitorTrendWindow.seven => history.dailyRuns,
    _MonitorTrendWindow.thirty => history.dailyRuns30,
    _MonitorTrendWindow.ninety => history.dailyRuns90,
  };
}

// 返回趋势卡片标题，保持界面短中文。
String _trendWindowTitle(_MonitorTrendWindow window) {
  return switch (window) {
    _MonitorTrendWindow.seven => '7日趋势',
    _MonitorTrendWindow.thirty => '30日趋势',
    _MonitorTrendWindow.ninety => '90日趋势',
  };
}

// 返回窗口切换按钮的短标签。
String _trendWindowShortLabel(_MonitorTrendWindow window) {
  return switch (window) {
    _MonitorTrendWindow.seven => '7日',
    _MonitorTrendWindow.thirty => '30日',
    _MonitorTrendWindow.ninety => '90日',
  };
}

// 根据柱子数量压缩间距，避免 90 日视图撑开。
double _trendBarGap(int count) {
  if (count > 45) return 2;
  if (count > 20) return 4;
  return 8;
}

// 把日期格式化为紧凑的月/日标签。
String _trendDayLabel(DateTime value) {
  return '${value.month}/${value.day}';
}
