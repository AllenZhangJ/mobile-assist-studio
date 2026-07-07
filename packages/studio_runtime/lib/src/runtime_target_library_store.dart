part of '../studio_runtime.dart';

// TargetLibraryStore 负责当前项目目标库持久化。
// Store 只读写本地 JSON，不连接设备、不启动驱动。
abstract interface class TargetLibraryStore {
  Future<void> saveTargets(List<RuntimeTargetDefinition> targets);
}

// NoopTargetLibraryStore 用于测试和无项目文件环境。
final class NoopTargetLibraryStore implements TargetLibraryStore {
  const NoopTargetLibraryStore();

  @override
  Future<void> saveTargets(List<RuntimeTargetDefinition> targets) async {}
}

// LocalTargetLibraryStore 将目标库保存到项目本地 JSON 文件。
// 读取时只恢复 validator 通过的目标列表，坏文件不会阻断主流程。
final class LocalTargetLibraryStore implements TargetLibraryStore {
  const LocalTargetLibraryStore({required File file}) : _file = file;

  final File _file;

  // 同步读取本地目标库，供项目启动阶段恢复 Runtime snapshot。
  List<RuntimeTargetDefinition> loadTargetsSync() {
    if (!_file.existsSync()) return const <RuntimeTargetDefinition>[];
    try {
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        return const <RuntimeTargetDefinition>[];
      }
      final rawTargets = decoded['targets'];
      if (rawTargets is! List<Object?>) {
        return const <RuntimeTargetDefinition>[];
      }
      final targets = <RuntimeTargetDefinition>[];
      for (final item in rawTargets) {
        if (item is! Map<String, Object?>) continue;
        targets.add(RuntimeTargetDefinition.fromJson(item));
      }
      final issues = const TargetLibraryValidator().validate(targets);
      if (issues.isNotEmpty) return const <RuntimeTargetDefinition>[];
      targets.sort((a, b) => a.id.compareTo(b.id));
      return List<RuntimeTargetDefinition>.unmodifiable(targets);
    } on Object {
      return const <RuntimeTargetDefinition>[];
    }
  }

  // 将目标库按 ID 稳定排序后写入本地，减少无意义文件抖动。
  @override
  Future<void> saveTargets(List<RuntimeTargetDefinition> targets) async {
    await _file.parent.create(recursive: true);
    final sorted = List<RuntimeTargetDefinition>.of(targets)
      ..sort((a, b) => a.id.compareTo(b.id));
    const encoder = JsonEncoder.withIndent('  ');
    final payload = <String, Object?>{
      'version': 1,
      'targets': sorted.map((target) => target.toJson()).toList(),
    };
    await _file.writeAsString('${encoder.convert(payload)}\n');
  }
}
