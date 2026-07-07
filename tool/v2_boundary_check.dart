import 'dart:io';

const _scanRoots = [
  'apps/studio_mac/lib',
  'packages/appium_client/lib',
  'packages/studio_design_system/lib',
  'packages/studio_runtime/lib',
  'packages/workflow_dsl/lib',
];

final _forbiddenRules = [
  _BoundaryRule(
    RegExp(r'\bios-assist-console\b'),
    'V2 主路径不得引用 Legacy Web Console',
  ),
  _BoundaryRule(RegExp(r'\bios-coordinate-[\w-]+'), 'V2 主路径不得调用 Legacy 坐标 CLI'),
  _BoundaryRule(
    RegExp(r'\bnode\s+(?:src|legacy/node/src)/'),
    'V2 主路径不得通过 Node 脚本作为中间层',
  ),
  _BoundaryRule(
    RegExp(
      r'\bnpm\s+run\s+(?:legacy:)?(?:console|click|record|init|pick(?:-d)?|start|dry-run|validate)(?::connected)?\b',
    ),
    'V2 主路径不得调用 Legacy npm 入口',
  ),
  _BoundaryRule(
    RegExp(r'\b(?:127\.0\.0\.1|localhost):4877\b'),
    'V2 主路径不得调用 Legacy Web Console 端口',
  ),
  _BoundaryRule(
    RegExp(
      r'/api/(?:status|workflow|run|runs|events|logs|device|connect|disconnect|init|execute|record|screenshot)\b',
    ),
    'V2 主路径不得调用 Legacy Web API',
  ),
  _BoundaryRule(
    RegExp(r'''Process\.(?:run|start)\s*\(\s*['"]node['"]'''),
    'Dart Runtime 不得启动 Node 作为产品中间层',
  ),
];

// 描述一条产品边界规则，用于扫描 Dart 产品源码。
class _BoundaryRule {
  const _BoundaryRule(this.pattern, this.reason);

  final RegExp pattern;
  final String reason;
}

// 程序入口：扫描 V2 产品源码并输出边界结果。
Future<void> main() async {
  final files = <File>[];
  for (final root in _scanRoots) {
    final directory = Directory(root);
    if (!directory.existsSync()) {
      _fail('V2 boundary check missing scan root: $root');
    }
    files.addAll(_listDartFiles(directory));
  }

  if (files.isEmpty) {
    _fail('V2 boundary check should scan Dart source files');
  }

  final violations = <String>[];
  for (final file in files) {
    violations.addAll(await _scanFile(file));
  }

  if (violations.isNotEmpty) {
    _fail('V2 boundary check failed:\n${violations.join('\n')}');
  }

  stdout.writeln(
    'V2 boundary check passed (${files.length} Dart files scanned)',
  );
}

// 递归列出 Dart 源文件，避免把 build、缓存或测试产物算作产品源码。
List<File> _listDartFiles(Directory root) {
  final files = <File>[];
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files.add(entity);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

// 扫描单文件并返回命中边界的行号与原因。
Future<List<String>> _scanFile(File file) async {
  final text = await file.readAsString();
  final lines = text.split(RegExp(r'\r?\n'));
  final violations = <String>[];
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    final line = lines[lineIndex];
    for (final rule in _forbiddenRules) {
      if (rule.pattern.hasMatch(line)) {
        final path = file.path.replaceAll('\\', '/');
        violations.add('$path:${lineIndex + 1} ${rule.reason}');
      }
    }
  }
  return violations;
}

// 统一失败出口，保证脚本在 CI 和本机都返回非零状态。
Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
