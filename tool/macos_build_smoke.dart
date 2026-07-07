import 'dart:io';

const _appDir = 'apps/studio_mac';
const _builtApp =
    'apps/studio_mac/build/macos/Build/Products/Debug/studio_mac.app';

// 程序入口：构建 Flutter macOS debug 包并确认产物存在。
Future<void> main() async {
  if (!Platform.isMacOS) {
    _fail('macOS build smoke must run on macOS.');
  }

  stdout.writeln('Building Flutter macOS debug app...');
  await _run('fvm', [
    'flutter',
    'build',
    'macos',
    '--debug',
  ], workingDirectory: _appDir);

  if (!Directory(_builtApp).existsSync()) {
    _fail('macOS build smoke did not produce studio_mac.app');
  }

  stdout.writeln('macOS build smoke passed');
}

// 运行外部命令并透传输出，失败时保留真实退出码语义。
Future<void> _run(
  String command,
  List<String> args, {
  String? workingDirectory,
}) async {
  try {
    final child = await Process.start(
      command,
      args,
      workingDirectory: workingDirectory,
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

// 统一失败出口，避免构建失败被误判为通过。
Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
