library;

import 'package:flutter/material.dart';

// StudioColors 统一承载 V2.0 工作站色板。
// 业务页面只消费语义颜色，不在页面内散落基础色值。
final class StudioColors {
  const StudioColors._();

  static const background = Color(0xFF05070A);
  static const panel = Color(0xEE091019);
  static const panelSoft = Color(0xFF0D1620);
  static const border = Color(0xFF1A2A33);
  static const cyan = Color(0xFF00F5FF);
  static const green = Color(0xFF39FF14);
  static const amber = Color(0xFFFFAA00);
  static const red = Color(0xFFFF0055);
  static const text = Color(0xFFE6F7FF);
  static const muted = Color(0xFF8AA4B0);
}

// StudioTheme 统一承载 Flutter App 的基础主题。
// 后续主题演进优先在这里扩展，再由 App 入口注入。
final class StudioTheme {
  const StudioTheme._();

  // 构建 Tech Noir 暗色主题，保持全局文本和背景一致。
  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: StudioColors.cyan,
      brightness: Brightness.dark,
      surface: StudioColors.panel,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: StudioColors.background,
      fontFamily: 'SF Pro Display',
      textTheme: Typography.whiteCupertino.apply(
        bodyColor: StudioColors.text,
        displayColor: StudioColors.text,
      ),
    );
  }
}

// StudioStatusTone 表示 UI 层可理解的状态语义。
// 它只描述展示色调，不承载业务状态判断。
enum StudioStatusTone { ready, warning, error, offline, running }

// StatusPill 展示短状态标签。
// 页面负责传入文案和状态语义，组件只负责视觉表达。
class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, required this.tone, super.key});

  final String label;
  final StudioStatusTone tone;

  // 根据状态语义渲染紧凑胶囊，适配顶部栏和卡片内状态。
  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      StudioStatusTone.ready => StudioColors.green,
      StudioStatusTone.warning => StudioColors.amber,
      StudioStatusTone.error => StudioColors.red,
      StudioStatusTone.offline => StudioColors.muted,
      StudioStatusTone.running => StudioColors.cyan,
    };
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// StudioSurface 是一级内容面板。
// 它统一主工作区卡片的背景、边框和内边距。
class StudioSurface extends StatelessWidget {
  const StudioSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = StudioColors.panelSoft,
    this.borderColor = StudioColors.border,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final BorderRadiusGeometry borderRadius;

  // 渲染统一一级容器，让页面不再重复维护面板样式。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: borderRadius,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

// StudioInsetSurface 是二级内嵌信息块。
// 它用于主面板内部的浅层状态、摘要和详情区域。
class StudioInsetSurface extends StatelessWidget {
  const StudioInsetSurface({
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(12),
    this.baseColor = StudioColors.background,
    this.backgroundAlpha = 0.42,
    this.borderColor = StudioColors.border,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    super.key,
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final Color baseColor;
  final double backgroundAlpha;
  final Color borderColor;
  final BorderRadiusGeometry borderRadius;

  // 渲染轻量内嵌容器，支持窄列和固定宽度信息块复用。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: backgroundAlpha),
        border: Border.all(color: borderColor),
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

// WorkspacePanel 是页面级工作区容器。
// 它负责统一标题栏、阴影和内容区域边界。
class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  // 渲染带标题栏的工作区容器，供 L1-L6 页面外壳复用。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.panel,
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: StudioColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
