part of '../studio_mac_workspace.dart';

// 通用内容容器，负责统一主界面面板的边框、背景和内边距。
class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  // 委托设计系统渲染一级面板，App 侧只保留私有兼容壳。
  @override
  Widget build(BuildContext context) {
    return StudioSurface(child: child);
  }
}

// 通用内嵌面板，负责统一卡片内部的浅层信息块样式。
class _InsetSurface extends StatelessWidget {
  const _InsetSurface({super.key, required this.child, this.width});

  final Widget child;
  final double? width;

  // 委托设计系统渲染二级信息块，保留原有调用名降低迁移风险。
  @override
  Widget build(BuildContext context) {
    return StudioInsetSurface(width: width, child: child);
  }
}

// 状态色边框容器，供就绪卡和详情卡复用同一套紧凑视觉。
class _ToneBorderSurface extends StatelessWidget {
  const _ToneBorderSurface({
    required this.tone,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderAlpha = 0.4,
  });

  final StudioStatusTone tone;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderAlpha;

  // 渲染带状态色边框的二级面板，避免各处重复 BoxDecoration。
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1118),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _colorForTone(tone).withValues(alpha: borderAlpha),
        ),
      ),
      child: child,
    );
  }
}
