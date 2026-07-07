part of '../../studio_mac_workspace.dart';

// 设备预览点击标记，负责把归一化坐标绘制成十字准星。
class _PreviewTapMarker extends StatelessWidget {
  const _PreviewTapMarker({
    required this.ratio,
    required this.contentRect,
    required this.sending,
  });

  final Offset ratio;
  final Rect contentRect;
  final bool sending;

  // 根据当前截图显示区域换算标记位置，并展示点击发送状态。
  @override
  Widget build(BuildContext context) {
    final point = Offset(
      contentRect.left + contentRect.width * ratio.dx,
      contentRect.top + contentRect.height * ratio.dy,
    );
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: point.dx - 24,
            top: point.dy - 24,
            width: 48,
            height: 48,
            child: DecoratedBox(
              key: const ValueKey('device-preview-tap-marker'),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StudioColors.cyan.withValues(
                  alpha: sending ? 0.18 : 0.1,
                ),
                border: Border.all(
                  color: sending ? StudioColors.green : StudioColors.cyan,
                  width: 1.6,
                ),
              ),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (sending ? StudioColors.green : StudioColors.cyan)
                          .withValues(alpha: 0.92),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: point.dx - 34,
            top: point.dy,
            width: 68,
            height: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: StudioColors.cyan.withValues(alpha: 0.7),
              ),
            ),
          ),
          Positioned(
            left: point.dx,
            top: point.dy - 34,
            width: 1,
            height: 68,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: StudioColors.cyan.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 设备预览滑动轨迹，负责把拖动起止点绘制成箭头线。
class _PreviewSwipeLine extends StatelessWidget {
  const _PreviewSwipeLine({
    required this.fromRatio,
    required this.toRatio,
    required this.contentRect,
    required this.sending,
  });

  final Offset fromRatio;
  final Offset toRatio;
  final Rect contentRect;
  final bool sending;

  // 根据截图显示区域换算起止点，并交给 painter 绘制方向。
  @override
  Widget build(BuildContext context) {
    final from = Offset(
      contentRect.left + contentRect.width * fromRatio.dx,
      contentRect.top + contentRect.height * fromRatio.dy,
    );
    final to = Offset(
      contentRect.left + contentRect.width * toRatio.dx,
      contentRect.top + contentRect.height * toRatio.dy,
    );
    return IgnorePointer(
      child: CustomPaint(
        key: const ValueKey('device-preview-swipe-line'),
        painter: _PreviewSwipePainter(
          from: from,
          to: to,
          color: sending ? StudioColors.green : StudioColors.cyan,
        ),
      ),
    );
  }
}

// 滑动轨迹 painter，负责线段、起点和箭头的低成本绘制。
class _PreviewSwipePainter extends CustomPainter {
  const _PreviewSwipePainter({
    required this.from,
    required this.to,
    required this.color,
  });

  final Offset from;
  final Offset to;
  final Color color;

  // 绘制带箭头的滑动方向，并用颜色表达是否正在发送。
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.86)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    canvas.drawCircle(from, 7, paint);

    final vector = to - from;
    if (vector.distance < 1) return;
    final direction = vector / vector.distance;
    final normal = Offset(-direction.dy, direction.dx);
    final arrowBase = to - direction * 16;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo((arrowBase + normal * 7).dx, (arrowBase + normal * 7).dy)
      ..moveTo(to.dx, to.dy)
      ..lineTo((arrowBase - normal * 7).dx, (arrowBase - normal * 7).dy);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      to,
      9,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
  }

  // 只有轨迹端点或颜色变化时才重绘，避免预览层无意义刷新。
  @override
  bool shouldRepaint(covariant _PreviewSwipePainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.color != color;
  }
}

// 设备预览空状态，提示用户先连接设备并采集截图。
class _PreviewEmptyState extends StatelessWidget {
  const _PreviewEmptyState();

  // 渲染简洁空态，避免主界面暴露底层会话细节。
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.phone_iphone_outlined,
            color: StudioColors.muted,
            size: 42,
          ),
          SizedBox(height: 12),
          Text(
            '连接设备并截图',
            textAlign: TextAlign.center,
            style: TextStyle(color: StudioColors.muted),
          ),
        ],
      ),
    );
  }
}
