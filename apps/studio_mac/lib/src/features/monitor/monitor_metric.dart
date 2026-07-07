part of '../../studio_mac_workspace.dart';

// Monitor 紧凑指标组件，统一承载均值、峰值、样本等短指标。
class _MonitorCompactMetric extends StatelessWidget {
  const _MonitorCompactMetric({
    required this.label,
    required this.value,
    this.width = 58,
  });

  final String label;
  final String value;
  final double width;

  // 固定指标宽度，避免中文短词和数值挤压趋势图或列表标题。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
