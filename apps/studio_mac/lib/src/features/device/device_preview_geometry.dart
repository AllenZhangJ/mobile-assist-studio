part of '../../studio_mac_workspace.dart';

// 计算设备预览中截图实际显示区域，并应用展示缩放。
Rect _devicePreviewDisplayRect({
  required Size containerSize,
  required Size? screenshotSize,
  required double scale,
}) {
  final contentRect = _previewContentRect(containerSize, screenshotSize);
  if (scale <= 1 || contentRect.isEmpty) return contentRect;
  final scaledSize = Size(
    contentRect.width * scale,
    contentRect.height * scale,
  );
  return Rect.fromCenter(
    center: contentRect.center,
    width: scaledSize.width,
    height: scaledSize.height,
  );
}

// 将预览局部坐标转换为 0 到 1 的手机屏幕比例坐标。
Offset? _devicePreviewRatioForPosition({
  required Offset localPosition,
  required Size containerSize,
  required Size? screenshotSize,
  required double scale,
  required bool clampToContent,
}) {
  final contentRect = _devicePreviewDisplayRect(
    containerSize: containerSize,
    screenshotSize: screenshotSize,
    scale: scale,
  );
  if (!clampToContent && !contentRect.contains(localPosition)) return null;
  if (contentRect.width <= 0 || contentRect.height <= 0) return null;
  final dx =
      (clampToContent
              ? localPosition.dx.clamp(contentRect.left, contentRect.right)
              : localPosition.dx)
          .toDouble();
  final dy =
      (clampToContent
              ? localPosition.dy.clamp(contentRect.top, contentRect.bottom)
              : localPosition.dy)
          .toDouble();
  return Offset(
    ((dx - contentRect.left) / contentRect.width).clamp(0.0, 1.0).toDouble(),
    ((dy - contentRect.top) / contentRect.height).clamp(0.0, 1.0).toDouble(),
  );
}
