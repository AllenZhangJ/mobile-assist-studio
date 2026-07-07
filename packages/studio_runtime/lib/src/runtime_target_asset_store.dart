part of '../studio_runtime.dart';

// TargetAssetStore 负责 V4 目标模板资产的本地读写。
// 它只处理项目内相对路径，不保存设备标识、截图路径或账号信息。
abstract interface class TargetAssetStore {
  // 读取图片模板并返回 base64 内容，缺失或不可读时返回 null。
  Future<String?> readImageTemplateBase64(String imageRef);

  // 保存图片模板，返回可写入 target payload 的项目相对路径。
  Future<String> saveImageTemplateBase64({
    required String targetId,
    required String imageBase64,
  });
}

// NoopTargetAssetStore 用于测试和无项目目录环境。
final class NoopTargetAssetStore implements TargetAssetStore {
  const NoopTargetAssetStore();

  @override
  Future<String?> readImageTemplateBase64(String imageRef) async {
    return null;
  }

  @override
  Future<String> saveImageTemplateBase64({
    required String targetId,
    required String imageBase64,
  }) async {
    throw UnsupportedError('目标资产存储不可用。');
  }
}

// LocalTargetAssetStore 将模板图片保存到项目 targets/images 目录。
// 对外只暴露相对路径，避免目标库 JSON 泄露本机绝对路径。
final class LocalTargetAssetStore implements TargetAssetStore {
  const LocalTargetAssetStore({required Directory projectDirectory})
    : _projectDirectory = projectDirectory;

  final Directory _projectDirectory;

  // 从项目相对路径读取图片模板。
  @override
  Future<String?> readImageTemplateBase64(String imageRef) async {
    final file = _targetAssetFileForRef(imageRef);
    if (file == null || !await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) return null;
      return base64Encode(bytes);
    } on Object {
      return null;
    }
  }

  // 保存 base64 PNG 模板，返回 targets/images 下的相对路径。
  @override
  Future<String> saveImageTemplateBase64({
    required String targetId,
    required String imageBase64,
  }) async {
    final bytes = _decodeTargetImageAsset(imageBase64);
    final fileName = '${_safeTargetAssetName(targetId)}.png';
    final ref = 'targets/images/$fileName';
    final file = _targetAssetFileForRef(ref);
    if (file == null) {
      throw StateError('目标资产路径不可用。');
    }
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return ref;
  }

  // 将项目相对路径解析为真实文件，非法路径返回 null。
  File? _targetAssetFileForRef(String imageRef) {
    final normalized = imageRef.trim();
    if (!_isSafeTargetAssetRef(normalized)) return null;
    return File('${_projectDirectory.path}/$normalized');
  }
}

// 校验目标资产相对路径，禁止绝对路径、协议和目录穿越。
bool _isSafeTargetAssetRef(String imageRef) {
  final normalized = imageRef.trim();
  if (normalized.isEmpty || normalized.length > 180) return false;
  if (normalized.startsWith('/') || normalized.startsWith('file://')) {
    return false;
  }
  if (normalized.contains('\\') || normalized.contains('//')) return false;
  if (!RegExp(r'^[A-Za-z0-9._/-]+$').hasMatch(normalized)) return false;
  final segments = normalized.split('/');
  if (segments.length < 2) return false;
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.' || segment == '..') return false;
  }
  return segments.first == 'targets';
}

// 生成稳定安全的模板文件名。
String _safeTargetAssetName(String value) {
  final safe = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return safe.isEmpty ? 'target-template' : safe;
}

// 解码目标模板 base64，并要求内容看起来是 PNG。
Uint8List _decodeTargetImageAsset(String imageBase64) {
  late final Uint8List bytes;
  try {
    bytes = base64Decode(imageBase64);
  } on Object {
    throw StateError('图片模板不是有效内容。');
  }
  if (!_looksLikePng(bytes)) {
    throw StateError('图片模板必须是 PNG。');
  }
  if (bytes.length > 5 * 1024 * 1024) {
    throw StateError('图片模板过大。');
  }
  return bytes;
}

// 使用 PNG 签名做轻量校验。
bool _looksLikePng(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}
