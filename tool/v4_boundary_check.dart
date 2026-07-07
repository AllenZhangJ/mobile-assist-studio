import 'dart:convert';
import 'dart:io';

const _scanRoots = [
  'apps/studio_mac/lib',
  'packages/appium_client/lib',
  'packages/studio_design_system/lib',
  'packages/studio_runtime/lib',
  'packages/workflow_dsl/lib',
];

const _requiredFiles = [
  'docs/V4.0-PRD-Mobile-Automation-Workstation.md',
  'docs/V4.0-Architecture-Integrated-Mobile-Workstation.md',
  'docs/V4.0-Open-Source-Integration-Plan.md',
  'docs/V4.0-Development-Roadmap.md',
  'docs/V4.0-Legacy-Node-Exit-Plan.md',
  'docs/decisions/ADR-002-v4-open-source-fusion-and-node-exit.md',
  'THIRD_PARTY_NOTICES.md',
  'third_party/README.md',
];

const _internalPubspecFiles = [
  'pubspec.yaml',
  'apps/studio_mac/pubspec.yaml',
  'packages/appium_client/pubspec.yaml',
  'packages/studio_design_system/pubspec.yaml',
  'packages/studio_runtime/pubspec.yaml',
  'packages/workflow_dsl/pubspec.yaml',
];

const _metadataTemplateFiles = [
  ..._internalPubspecFiles,
  'packages/studio_design_system/LICENSE',
];

const _packageJsonPath = 'package.json';

const _reservedLegacyScriptNames = [
  'init:connected',
  'console:connected',
  'click:connected',
  'record:connected',
  'record:html:connected',
  'pick-d:connected',
  'dry-run:connected',
  'start:connected',
  'dry-run',
  'start',
  'validate:connected',
  'validate',
];

final _forbiddenProductRules = [
  _BoundaryRule(
    RegExp(r'\bios-assist-console\b'),
    'V4 主路径不得引用 Legacy Web Console',
  ),
  _BoundaryRule(RegExp(r'\bios-coordinate-[\w-]+'), 'V4 主路径不得调用 Legacy 坐标 CLI'),
  _BoundaryRule(
    RegExp(r'\bnode\s+(?:src|legacy/node/src)/'),
    'V4 主路径不得通过 Node 脚本作为中间层',
  ),
  _BoundaryRule(
    RegExp(
      r'\bnpm\s+run\s+(?:legacy:)?(?:console|click|record|init|pick(?:-d)?|start|dry-run|validate)(?::connected)?\b',
    ),
    'V4 主路径不得调用 Legacy npm 入口',
  ),
  _BoundaryRule(
    RegExp(r'\b(?:127\.0\.0\.1|localhost):4877\b'),
    'V4 主路径不得调用 Legacy Web Console 端口',
  ),
  _BoundaryRule(
    RegExp(
      r'/api/(?:status|workflow|run|runs|events|logs|device|connect|disconnect|init|execute|record|screenshot)\b',
    ),
    'V4 主路径不得调用 Legacy Web API',
  ),
  _BoundaryRule(
    RegExp(r'''Process\.(?:run|start)\s*\(\s*['"]node['"]'''),
    'V4 Dart Runtime 不得启动 Node 作为产品中间层',
  ),
  _BoundaryRule(
    RegExp(r'\bmcp-appium-visual\b'),
    'V4 不得把 appium-mcp 的 Node 运行时接入主路径',
  ),
];

final _privacyRules = [
  _BoundaryRule(RegExp(r'/Users/[A-Za-z0-9._-]+'), '文档不得写入本机绝对用户路径'),
  _BoundaryRule(RegExp(r'0000[0-9A-Fa-f]{4,}'), '文档不得写入完整设备标识'),
  _BoundaryRule(RegExp(r'DEVICE_UDID'), '文档不得保留真实设备标识占位误导'),
  _BoundaryRule(RegExp(r'Hangzhou\s+\w+'), '文档不得写入完整证书主体'),
];

final _metadataTemplateRules = [
  _BoundaryRule(RegExp(r'TODO:\s*Add your license here'), '包级许可证不得保留模板 TODO'),
  _BoundaryRule(RegExp(r'flutter pub publish'), '内部包 pubspec 不得保留发布模板注释'),
  _BoundaryRule(
    RegExp(r'images/a_dot_burr'),
    'pubspec 不得保留 Flutter sample 资源注释',
  ),
  _BoundaryRule(RegExp(r'\bSchyler\b'), 'pubspec 不得保留 Flutter sample 字体注释'),
  _BoundaryRule(RegExp(r'\bTrajan Pro\b'), 'pubspec 不得保留 Flutter sample 字体注释'),
  _BoundaryRule(
    RegExp(r'Remove this line if you wish to publish'),
    '内部包 pubspec 不得提示可发布到 pub.dev',
  ),
];

final _v4DocExpectations = [
  _DocExpectation('docs/V4.0-PRD-Mobile-Automation-Workstation.md', [
    'Android 真机',
    '不恢复 Node',
    'Airtest',
    'Pyxelator',
    'Appium Inspector',
    'appium-mcp',
  ]),
  _DocExpectation('docs/V4.0-Architecture-Integrated-Mobile-Workstation.md', [
    'Python Sidecar',
    'Android Adapter',
    'TargetResolver',
    'Node Exit Boundary',
  ]),
  _DocExpectation('docs/V4.0-Open-Source-Integration-Plan.md', [
    'third_party',
    'THIRD_PARTY_NOTICES.md',
    '依赖优先',
    'AppiumAir',
  ]),
  _DocExpectation('docs/V4.0-Development-Roadmap.md', [
    'Batch 0',
    'Batch 8',
    'Android 真机',
    'Stop Conditions',
  ]),
  _DocExpectation('docs/V4.0-Legacy-Node-Exit-Plan.md', [
    'V4 boundary',
    'Delete Gate',
    'Android 真机',
    'Python Sidecar',
  ]),
  _DocExpectation(
    'docs/decisions/ADR-002-v4-open-source-fusion-and-node-exit.md',
    ['Accepted', 'Node', 'Android', 'Python Sidecar'],
  ),
];

// 描述一条边界规则，用于扫描产品源码或文档。
class _BoundaryRule {
  const _BoundaryRule(this.pattern, this.reason);

  final RegExp pattern;
  final String reason;
}

// 描述一份 V4 文档必须包含的关键词，用于守住真源完整性。
class _DocExpectation {
  const _DocExpectation(this.path, this.requiredSnippets);

  final String path;
  final List<String> requiredSnippets;
}

// 程序入口：执行 V4 真源、隐私、Node 退出和第三方治理检查。
Future<void> main() async {
  final violations = <String>[];
  violations.addAll(_checkRequiredFiles());
  violations.addAll(await _checkProductBoundaries());
  violations.addAll(await _checkV4Docs());
  violations.addAll(await _checkPrivacy());
  violations.addAll(await _checkPackageMetadata());
  violations.addAll(await _checkPackageScripts());
  violations.addAll(_checkThirdPartyGovernance());

  if (violations.isNotEmpty) {
    _fail('V4 boundary check failed:\n${violations.join('\n')}');
  }

  stdout.writeln('V4 boundary check passed');
}

// 检查 V4 Batch 0 要求的真源文件是否存在。
List<String> _checkRequiredFiles() {
  final violations = <String>[];
  for (final path in _requiredFiles) {
    if (!FileSystemEntity.typeSync(path).exists) {
      violations.add('$path missing required V4 file');
    }
  }
  return violations;
}

// 扫描 Flutter / Dart 主路径，确保 Node 和 Legacy 能力没有回流。
Future<List<String>> _checkProductBoundaries() async {
  final files = <File>[];
  final violations = <String>[];
  for (final root in _scanRoots) {
    final directory = Directory(root);
    if (!directory.existsSync()) {
      violations.add('$root missing product scan root');
      continue;
    }
    files.addAll(_listDartFiles(directory));
  }

  if (files.isEmpty) {
    violations.add('V4 boundary check should scan Dart source files');
    return violations;
  }

  for (final file in files) {
    final lines = await file.readAsLines();
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
      for (final rule in _forbiddenProductRules) {
        if (rule.pattern.hasMatch(lines[lineIndex])) {
          final path = file.path.replaceAll('\\', '/');
          violations.add('$path:${lineIndex + 1} ${rule.reason}');
        }
      }
    }
  }
  return violations;
}

// 检查 V4 文档是否包含不可缺失的核心决策关键词。
Future<List<String>> _checkV4Docs() async {
  final violations = <String>[];
  for (final expectation in _v4DocExpectations) {
    final file = File(expectation.path);
    if (!file.existsSync()) {
      continue;
    }
    final text = await file.readAsString();
    for (final snippet in expectation.requiredSnippets) {
      if (!text.contains(snippet)) {
        violations.add(
          '${expectation.path} missing required V4 topic: $snippet',
        );
      }
    }
  }
  return violations;
}

// 扫描 V4 真源和入口文档，避免写入敏感本机信息。
Future<List<String>> _checkPrivacy() async {
  final files = [
    ..._requiredFiles.map(File.new),
    File('AI_PROJECT_CONTEXT.md'),
    File('AGENTS.md'),
    File('PRODUCT.md'),
    File('README.md'),
    File('docs/README.md'),
  ];
  final violations = <String>[];
  for (final file in files.where((file) => file.existsSync())) {
    final lines = await file.readAsLines();
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
      for (final rule in _privacyRules) {
        if (rule.pattern.hasMatch(lines[lineIndex])) {
          final path = file.path.replaceAll('\\', '/');
          violations.add('$path:${lineIndex + 1} ${rule.reason}');
        }
      }
    }
  }
  return violations;
}

// 检查内部包发布边界和模板残留，避免 Batch 0 法务真源退回脚手架状态。
Future<List<String>> _checkPackageMetadata() async {
  final violations = <String>[];
  for (final path in _internalPubspecFiles) {
    final file = File(path);
    if (!file.existsSync()) {
      violations.add('$path missing internal package pubspec');
      continue;
    }
    final text = await file.readAsString();
    if (!RegExp(
      r'''^publish_to:\s*['"]?none['"]?\s*$''',
      multiLine: true,
    ).hasMatch(text)) {
      violations.add('$path internal package must declare publish_to: none');
    }
  }

  for (final path in _metadataTemplateFiles) {
    final file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    final lines = await file.readAsLines();
    for (var lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
      for (final rule in _metadataTemplateRules) {
        if (rule.pattern.hasMatch(lines[lineIndex])) {
          violations.add('$path:${lineIndex + 1} ${rule.reason}');
        }
      }
    }
  }
  return violations;
}

// 检查根 package.json 脚本，防止无前缀旧入口或默认脚本绕回 Legacy Node。
Future<List<String>> _checkPackageScripts() async {
  final violations = <String>[];
  final file = File(_packageJsonPath);
  if (!file.existsSync()) {
    violations.add('package.json missing root script manifest');
    return violations;
  }

  final content = await file.readAsString();
  final json = jsonDecode(content);
  if (json is! Map<String, Object?>) {
    violations.add('package.json must be a JSON object');
    return violations;
  }
  final scripts = json['scripts'];
  if (scripts is! Map<String, Object?>) {
    violations.add('package.json missing scripts object');
    return violations;
  }

  for (final name in _reservedLegacyScriptNames) {
    if (scripts.containsKey(name)) {
      violations.add(
        'package.json script "$name" must stay under legacy:* prefix',
      );
    }
  }

  for (final entry in scripts.entries) {
    final name = entry.key;
    final command = entry.value;
    if (command is! String || name.startsWith('legacy:')) {
      continue;
    }
    if (RegExp(r'\blegacy/node/src/').hasMatch(command) ||
        RegExp(r'\bnpm\s+run\s+legacy:').hasMatch(command) ||
        RegExp(r'\bnode\s+src/').hasMatch(command)) {
      violations.add(
        'package.json script "$name" must not route the V4 path through Legacy Node',
      );
    }
  }

  return violations;
}

// 检查 third_party 治理目录和 notice 是否保持一致。
List<String> _checkThirdPartyGovernance() {
  final violations = <String>[];
  final thirdParty = Directory('third_party');
  if (!thirdParty.existsSync()) {
    violations.add('third_party missing governance directory');
    return violations;
  }

  final notice = File('THIRD_PARTY_NOTICES.md');
  if (!notice.existsSync()) {
    violations.add('THIRD_PARTY_NOTICES.md missing third-party notice file');
    return violations;
  }

  final sourceFiles = thirdParty
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => !_isAllowedGovernanceFile(file))
      .toList();
  final noticeText = notice.readAsStringSync();
  if (sourceFiles.isNotEmpty &&
      noticeText.contains('no third-party source code has been copied')) {
    violations.add(
      'third_party contains copied files but THIRD_PARTY_NOTICES.md still says none copied',
    );
  }
  return violations;
}

// 递归列出 Dart 源文件，排除生成和缓存目录。
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

// 判断 third_party 中是否只是治理说明文件。
bool _isAllowedGovernanceFile(File file) {
  final path = file.path.replaceAll('\\', '/');
  return path == 'third_party/README.md' || path.endsWith('/README.md');
}

// 统一失败出口，保证脚本在本机和 CI 中都返回非零状态。
Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

extension on FileSystemEntityType {
  // 判断文件系统实体类型是否存在，避免重复写 type 判断。
  bool get exists => this != FileSystemEntityType.notFound;
}
