import 'dart:io';

const _steps = [
  _VerifyStep('V4 边界检查', 'fvm', ['dart', 'run', 'tool/v4_boundary_check.dart']),
  _VerifyStep('V2 完整验证', 'fvm', ['dart', 'run', 'tool/v2_verify.dart']),
];

// 描述一个 V4 验证步骤，保持输出稳定易读。
class _VerifyStep {
  const _VerifyStep(this.name, this.command, this.args);

  final String name;
  final String command;
  final List<String> args;
}

// 程序入口：先验证 V4 边界，再复用既有 V2 完整验证矩阵。
Future<void> main() async {
  for (final step in _steps) {
    stdout.writeln('\n== ${step.name} ==');
    await _run(step.command, step.args);
  }
  stdout.writeln('\nV4 verification passed');
}

// 执行命令并继承输出，任何一步失败都会停止后续验证。
Future<void> _run(String command, List<String> args) async {
  try {
    final child = await Process.start(
      command,
      args,
      environment: {
        ...Platform.environment,
        'DART_SUPPRESS_ANALYTICS': 'true',
        'FLUTTER_SUPPRESS_ANALYTICS': 'true',
      },
    );

    await Future.wait([
      stdout.addStream(child.stdout),
      stderr.addStream(child.stderr),
    ]);
    final code = await child.exitCode;
    if (code != 0) {
      _fail('$command ${args.join(' ')} exited with code $code');
    }
  } on ProcessException catch (error) {
    _fail('Failed to run $command: ${error.message}');
  }
}

// 统一失败出口，保证本机和 CI 中表现一致。
Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
