import 'dart:async';
import 'dart:convert';
import 'dart:io';

// V4 final acceptance 串联 readiness、archive 和最终门禁，并生成本地审计报告。
// 它不执行真实 Tap / Swipe / Input，只复用现有只读验收工具做最终状态判定。
Future<void> main(List<String> args) async {
  final options = _AcceptanceOptions.parse(args);
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }

  final timestamp = DateTime.now().toUtc();
  await options.reportDir.create(recursive: true);
  final results = <_AcceptanceStepResult>[];
  for (final step in _buildSteps(options)) {
    stdout.writeln('\n== ${step.name} ==');
    final result = await _runStep(step, options.stepTimeout);
    stdout.writeln('${step.name}：${result.statusLabel}');
    results.add(result);
  }

  final report = _AcceptanceReport(
    timestamp: timestamp,
    gitStatus: await _currentGitStatus(options.probeTimeout),
    requireComplete: options.requireComplete,
    outDir: _redactText(options.outDir.path),
    evidence: await _AcceptanceEvidenceSummary.load(
      outDir: options.outDir,
      archiveDir: options.archiveDir,
    ),
    results: results,
  );
  final base =
      '${options.reportDir.path}/FINAL_ACCEPTANCE_${_safeTimestamp(timestamp)}';
  final jsonFile = File('$base.json');
  final markdownFile = File('$base.md');
  await jsonFile.writeAsString(report.toJsonString(), flush: true);
  await markdownFile.writeAsString(report.toMarkdown(), flush: true);
  stdout
    ..writeln('\nFinal acceptance report: ${_redactText(markdownFile.path)}')
    ..writeln('Final acceptance json: ${_redactText(jsonFile.path)}');

  if (!report.auditOk) {
    stderr.writeln('V4 final acceptance audit failed: 基础审计工具未能成功生成。');
    exit(1);
  }
  if (options.requireComplete && !report.complete) {
    stderr.writeln('V4 final acceptance failed: 最终验收尚未通过。');
    for (final failure in report.finalFailures) {
      stderr.writeln('- $failure');
    }
    if (report.gateGaps.isNotEmpty) {
      stderr.writeln('终验门禁缺口：');
      for (final gap in report.gateGaps) {
        stderr.writeln('- ${gap.stderrLine}');
      }
    }
    if (report.fieldChecklist.isNotEmpty) {
      stderr.writeln('现场补验清单：');
      for (final item in report.fieldChecklist) {
        stderr.writeln('- ${item.stderrLine}');
      }
    }
    exit(2);
  }
}

// 生成固定顺序的最终验收步骤；后续步骤即使前一步失败也会继续留档。
List<_AcceptanceStep> _buildSteps(_AcceptanceOptions options) {
  return <_AcceptanceStep>[
    _AcceptanceStep(
      name: '生成 readiness',
      arguments: <String>[
        'tool/v4_smoke_readiness.dart',
        '--out-dir',
        options.outDir.path,
        '--timeout',
        '${options.probeTimeout.inSeconds}',
      ],
      requiredForAudit: true,
    ),
    _AcceptanceStep(
      name: '生成 archive',
      arguments: <String>[
        'tool/v4_smoke_archive.dart',
        '--out-dir',
        options.outDir.path,
        '--archive-dir',
        options.archiveDir.path,
        '--timeout',
        '${options.probeTimeout.inSeconds}',
      ],
      requiredForAudit: true,
    ),
    _AcceptanceStep(
      name: '完成审计',
      arguments: <String>[
        'tool/v4_smoke_readiness.dart',
        '--out-dir',
        options.outDir.path,
        '--timeout',
        '${options.probeTimeout.inSeconds}',
        '--require-complete',
      ],
    ),
    _AcceptanceStep(
      name: '归档终验',
      arguments: <String>[
        'tool/v4_smoke_archive.dart',
        '--out-dir',
        options.outDir.path,
        '--archive-dir',
        options.archiveDir.path,
        '--timeout',
        '${options.probeTimeout.inSeconds}',
        '--require-complete',
        '--require-screenshot',
        '--require-platform-runs',
      ],
    ),
  ];
}

// 执行单个验收步骤并捕获脱敏输出。
Future<_AcceptanceStepResult> _runStep(
  _AcceptanceStep step,
  Duration timeout,
) async {
  final startedAt = DateTime.now().toUtc();
  try {
    final process = await Process.start(
      Platform.resolvedExecutable,
      step.arguments,
      environment: <String, String>{
        ...Platform.environment,
        'DART_SUPPRESS_ANALYTICS': 'true',
        'FLUTTER_SUPPRESS_ANALYTICS': 'true',
      },
    );
    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stdoutBuffer.write)
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(stderrBuffer.write)
        .asFuture<void>();

    var exitCode = 0;
    var timedOut = false;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      exitCode = 124;
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
      }
    }
    await _settleOutput(stdoutDone, stderrDone);
    return _AcceptanceStepResult(
      step: step,
      exitCode: exitCode,
      timedOut: timedOut,
      startedAt: startedAt,
      finishedAt: DateTime.now().toUtc(),
      stdoutText: _redactText(stdoutBuffer.toString()),
      stderrText: _redactText(stderrBuffer.toString()),
    );
  } on ProcessException catch (error) {
    return _AcceptanceStepResult(
      step: step,
      exitCode: 127,
      timedOut: false,
      startedAt: startedAt,
      finishedAt: DateTime.now().toUtc(),
      stdoutText: '',
      stderrText: _redactText(error.message),
    );
  }
}

// 等待子进程输出收尾，避免报告漏掉最后一行失败信息。
Future<void> _settleOutput(
  Future<void> stdoutDone,
  Future<void> stderrDone,
) async {
  try {
    await Future.wait(<Future<void>>[
      stdoutDone,
      stderrDone,
    ]).timeout(const Duration(seconds: 2));
  } on Object {
    // 输出收尾失败不覆盖主退出码，报告保留已收集内容。
  }
}

// 当前 Git 状态只保留短提交、分支和干净度，不保存文件列表。
Future<_GitStatus> _currentGitStatus(Duration timeout) async {
  final upstream = await _currentGitUpstream(timeout);
  final remoteState = upstream == null
      ? const _GitRemoteState.unknown()
      : await _currentGitRemoteState(upstream, timeout);
  return _GitStatus(
    revision: await _currentGitCommit(timeout),
    branch: await _currentGitBranch(timeout),
    dirty: await _currentGitDirty(timeout),
    upstream: upstream,
    remoteState: remoteState,
  );
}

// 当前 Git commit 只保留短 hash。
Future<String> _currentGitCommit(Duration timeout) async {
  try {
    final result = await Process.run('git', const <String>[
      'rev-parse',
      '--short',
      'HEAD',
    ]).timeout(timeout);
    if (result.exitCode != 0) return 'unknown';
    final value = _redactText('${result.stdout}').trim();
    return value.isEmpty ? 'unknown' : value;
  } on Object {
    return 'unknown';
  }
}

// 当前 Git 分支只保留分支名；detached HEAD 用固定短文案。
Future<String> _currentGitBranch(Duration timeout) async {
  final current = await _runGitProbe(const <String>[
    'branch',
    '--show-current',
  ], timeout);
  if (current != null && current.trim().isNotEmpty) return current.trim();
  final fallback = await _runGitProbe(const <String>[
    'rev-parse',
    '--abbrev-ref',
    'HEAD',
  ], timeout);
  final value = fallback?.trim();
  if (value == null || value.isEmpty) return 'unknown';
  return value == 'HEAD' ? 'detached' : value;
}

// 判断工作区是否有未提交改动；未知时返回 null。
Future<bool?> _currentGitDirty(Duration timeout) async {
  final status = await _runGitProbe(const <String>[
    'status',
    '--porcelain',
    '--untracked-files=all',
  ], timeout);
  if (status == null) return null;
  return status.trim().isNotEmpty;
}

// 当前上游分支只作为同步证明，不写远端 URL。
Future<String?> _currentGitUpstream(Duration timeout) async {
  final upstream = await _runGitProbe(const <String>[
    'rev-parse',
    '--abbrev-ref',
    '--symbolic-full-name',
    '@{upstream}',
  ], timeout);
  final value = upstream?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

// 读取 ahead / behind 计数，证明提交是否已同步到上游。
Future<_GitRemoteState> _currentGitRemoteState(
  String upstream,
  Duration timeout,
) async {
  final counts = await _runGitProbe(<String>[
    'rev-list',
    '--left-right',
    '--count',
    '$upstream...HEAD',
  ], timeout);
  final parts = counts?.trim().split(RegExp(r'\s+'));
  if (parts == null || parts.length < 2) {
    return const _GitRemoteState.unknown();
  }
  final behind = int.tryParse(parts[0]);
  final ahead = int.tryParse(parts[1]);
  if (ahead == null || behind == null) {
    return const _GitRemoteState.unknown();
  }
  return _GitRemoteState(ahead: ahead, behind: behind);
}

// 执行只读 Git 探针并脱敏输出。
Future<String?> _runGitProbe(List<String> arguments, Duration timeout) async {
  try {
    final result = await Process.run('git', arguments).timeout(timeout);
    if (result.exitCode != 0) return null;
    return _redactText('${result.stdout}');
  } on Object {
    return null;
  }
}

// 裁剪长输出，保留首尾上下文。
String _shortBlock(String value, {int limit = 1800}) {
  final trimmed = value.trim();
  if (trimmed.length <= limit) return trimmed;
  final head = trimmed.substring(0, limit ~/ 2);
  final tail = trimmed.substring(trimmed.length - (limit ~/ 2));
  return '$head\n...\n$tail';
}

// 生成文件名安全时间戳。
String _safeTimestamp(DateTime value) {
  return value.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
}

// 脱敏本机路径、长设备号和 UUID。
String _redactText(String value) {
  return value
      .replaceAll(RegExp(r'/Users/[^/\s]+'), '<home>')
      .replaceAll(RegExp(r'/private/tmp/[^\s`)]+'), '<tmp>')
      .replaceAll(RegExp(r'/tmp/[^\s`)]+'), '<tmp>')
      .replaceAll(RegExp(r'/var/folders/[^\s`)]+'), '<tmp>')
      .replaceAll(RegExp(r'/private/var/folders/[^\s`)]+'), '<tmp>')
      .replaceAll(
        RegExp(
          r'[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}',
        ),
        '<device-id>',
      )
      .replaceAll(RegExp(r'\b[0-9A-Fa-f]{24,}\b'), '<device-id>');
}

// 脱敏任意 JSON 值，保留结构以便最终报告嵌入上游报告摘要。
Object? _redactJsonValue(Object? value) {
  if (value is String) return _redactText(value);
  if (value is num || value is bool || value == null) return value;
  if (value is List) {
    return value.map(_redactJsonValue).toList(growable: false);
  }
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _redactJsonValue(entry.value),
    };
  }
  return _redactText(value.toString());
}

// 验收参数。
final class _AcceptanceOptions {
  const _AcceptanceOptions({
    required this.outDir,
    required this.archiveDir,
    required this.reportDir,
    required this.probeTimeout,
    required this.stepTimeout,
    required this.requireComplete,
    required this.help,
  });

  final Directory outDir;
  final Directory archiveDir;
  final Directory reportDir;
  final Duration probeTimeout;
  final Duration stepTimeout;
  final bool requireComplete;
  final bool help;

  // 解析命令行参数。
  static _AcceptanceOptions parse(List<String> args) {
    var outDir = Directory('recordings/v4-smoke');
    Directory? archiveDir;
    Directory? reportDir;
    var probeTimeoutSeconds = 4;
    var stepTimeoutSeconds = 60;
    var requireComplete = false;
    var help = false;

    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      switch (arg) {
        case '--help':
        case '-h':
          help = true;
        case '--out-dir':
          outDir = Directory(_nextValue(args, index, arg));
          index += 1;
        case '--archive-dir':
          archiveDir = Directory(_nextValue(args, index, arg));
          index += 1;
        case '--report-dir':
          reportDir = Directory(_nextValue(args, index, arg));
          index += 1;
        case '--probe-timeout':
          probeTimeoutSeconds = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--step-timeout':
          stepTimeoutSeconds = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--require-complete':
          requireComplete = true;
        default:
          throw ArgumentError('未知参数：$arg');
      }
    }

    return _AcceptanceOptions(
      outDir: outDir,
      archiveDir: archiveDir ?? Directory('${outDir.path}/archives'),
      reportDir: reportDir ?? Directory('${outDir.path}/acceptance'),
      probeTimeout: Duration(seconds: probeTimeoutSeconds),
      stepTimeout: Duration(seconds: stepTimeoutSeconds),
      requireComplete: requireComplete,
      help: help,
    );
  }
}

// 参数读取 helper。
String _nextValue(List<String> args, int index, String name) {
  if (index + 1 >= args.length) {
    throw ArgumentError('$name 缺少参数值。');
  }
  return args[index + 1];
}

// 验收步骤定义。
final class _AcceptanceStep {
  const _AcceptanceStep({
    required this.name,
    required this.arguments,
    this.requiredForAudit = false,
  });

  final String name;
  final List<String> arguments;
  final bool requiredForAudit;

  String get commandLine {
    return _redactText('${Platform.resolvedExecutable} ${arguments.join(' ')}');
  }

  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'name': name,
      'command': commandLine,
      'requiredForAudit': requiredForAudit,
    };
  }
}

// 验收步骤结果。
final class _AcceptanceStepResult {
  const _AcceptanceStepResult({
    required this.step,
    required this.exitCode,
    required this.timedOut,
    required this.startedAt,
    required this.finishedAt,
    required this.stdoutText,
    required this.stderrText,
  });

  final _AcceptanceStep step;
  final int exitCode;
  final bool timedOut;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String stdoutText;
  final String stderrText;

  bool get passed => exitCode == 0 && !timedOut;

  Duration get duration => finishedAt.difference(startedAt);

  String get statusLabel {
    if (timedOut) return '超时';
    return passed ? '通过' : '未通过';
  }

  String get failureLabel {
    final issue = stderrText.trim().isEmpty ? stdoutText : stderrText;
    final shortIssue = _shortBlock(
      issue,
      limit: 260,
    ).replaceAll('\n', ' ').trim();
    if (shortIssue.isEmpty) return '${step.name}：$statusLabel';
    return '${step.name}：$statusLabel，$shortIssue';
  }

  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'step': step.toJsonObject(),
      'status': statusLabel,
      'passed': passed,
      'exitCode': exitCode,
      'timedOut': timedOut,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'stdoutPreview': _shortBlock(stdoutText),
      'stderrPreview': _shortBlock(stderrText),
    };
  }
}

// 最终验收报告。
final class _AcceptanceReport {
  const _AcceptanceReport({
    required this.timestamp,
    required this.gitStatus,
    required this.requireComplete,
    required this.outDir,
    required this.evidence,
    required this.results,
  });

  final DateTime timestamp;
  final _GitStatus gitStatus;
  final bool requireComplete;
  final String outDir;
  final _AcceptanceEvidenceSummary evidence;
  final List<_AcceptanceStepResult> results;

  bool get auditOk {
    return results
        .where((result) => result.step.requiredForAudit)
        .every((result) => result.passed);
  }

  bool get complete =>
      results.every((result) => result.passed) && gitStatus.ready;

  List<String> get finalFailures {
    final failures = results
        .where((result) => !result.passed)
        .map((result) => result.failureLabel)
        .toList();
    failures.addAll(gitStatus.failures);
    return failures;
  }

  // 根据最终失败摘要生成可执行下一步，不读取本机隐私信息。
  List<String> get nextSteps {
    if (finalFailures.isEmpty) {
      return const <String>['保留本次报告，进入交付复核。'];
    }
    return _nextStepsForFailures(
      failures: finalFailures,
      auditOk: auditOk,
      evidence: evidence,
    );
  }

  // 生成现场补验清单；它只重排安全命令，不执行真实设备动作。
  List<_AcceptanceChecklistItem> get fieldChecklist {
    return _fieldChecklistForNextSteps(
      nextSteps,
      complete: complete,
      evidence: evidence,
    );
  }

  // 生成结构化终验门禁缺口，便于 AI / 人工按证据补齐。
  List<_AcceptanceGateGap> get gateGaps {
    return <_AcceptanceGateGap>[
      ...gitStatus.gateGaps,
      ..._gateGapsFromEvidence(evidence),
    ];
  }

  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(toJsonObject())}\n';
  }

  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'schemaVersion': 1,
      'kind': 'v4FinalAcceptance',
      'timestamp': timestamp.toIso8601String(),
      'git': gitStatus.revision,
      'gitStatus': gitStatus.toJsonObject(),
      'requireComplete': requireComplete,
      'outDir': outDir,
      'completion': <String, Object?>{
        'auditOk': auditOk,
        'complete': complete,
        'label': complete
            ? '最终验收通过'
            : auditOk
            ? '最终验收未完成'
            : '基础审计失败',
        'failures': finalFailures,
      },
      'evidence': evidence.toJsonObject(),
      'gateGaps': gateGaps
          .map((gap) => gap.toJsonObject())
          .toList(growable: false),
      'nextSteps': nextSteps,
      'fieldChecklist': fieldChecklist
          .map((item) => item.toJsonObject())
          .toList(growable: false),
      'steps': results.map((result) => result.toJsonObject()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# V4 Final Acceptance')
      ..writeln()
      ..writeln('- 时间：${timestamp.toIso8601String()}')
      ..writeln('- 提交：${gitStatus.revision}')
      ..writeln('- 分支：${gitStatus.branch}')
      ..writeln('- 工作区：${gitStatus.worktreeLabel}')
      ..writeln('- 远端：${gitStatus.remoteLabel}')
      ..writeln('- 来源：`$outDir`')
      ..writeln('- 完成：${complete ? '通过' : '未完成'}')
      ..writeln('- 基础审计：${auditOk ? '通过' : '失败'}')
      ..writeln()
      ..writeln('## 步骤')
      ..writeln()
      ..writeln('| 步骤 | 结果 | 退出码 | 耗时 |')
      ..writeln('|---|---|---:|---:|');
    for (final result in results) {
      buffer.writeln(
        '| ${result.step.name} | ${result.statusLabel} | ${result.exitCode} | ${result.duration.inSeconds}s |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## 结论')
      ..writeln();
    if (finalFailures.isEmpty) {
      buffer.writeln('- 最终验收通过。');
    } else {
      for (final failure in finalFailures) {
        buffer.writeln('- $failure');
      }
    }
    buffer.write(evidence.toMarkdown());
    buffer
      ..writeln()
      ..writeln('## 终验门禁')
      ..writeln()
      ..writeln('| 项目 | 当前问题 | 通过标准 | 建议命令 |')
      ..writeln('|---|---|---|---|');
    if (gateGaps.isEmpty) {
      buffer.writeln('| 全部门禁 | 无缺口 | 终验可通过 | - |');
    } else {
      for (final gap in gateGaps) {
        buffer.writeln(
          '| ${gap.title} | ${gap.current} | ${gap.required} | ${gap.commandMarkdown} |',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('## 现场补验清单')
      ..writeln()
      ..writeln('| 顺序 | 操作 | 命令 | 通过标准 |')
      ..writeln('|---:|---|---|---|');
    for (final item in fieldChecklist) {
      buffer.writeln(
        '| ${item.order} | ${item.title} | ${item.commandMarkdown} | ${item.proof} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## 下一步')
      ..writeln();
    for (final step in nextSteps) {
      buffer.writeln('- $step');
    }
    return buffer.toString();
  }
}

// GitStatus 是终验报告的代码版本指纹，不包含具体文件列表。
final class _GitStatus {
  const _GitStatus({
    required this.revision,
    required this.branch,
    required this.dirty,
    required this.upstream,
    required this.remoteState,
  });

  final String revision;
  final String branch;
  final bool? dirty;
  final String? upstream;
  final _GitRemoteState remoteState;

  String get worktreeLabel {
    return switch (dirty) {
      true => '有未提交改动',
      false => '干净',
      null => '未知',
    };
  }

  String get remoteLabel {
    final value = remoteState.synced;
    if (value == true) return '已同步';
    if (value == false) {
      if (remoteState.ahead > 0 && remoteState.behind > 0) {
        return '已分叉';
      }
      if (remoteState.ahead > 0) return '未推送';
      if (remoteState.behind > 0) return '落后远端';
      return '未同步';
    }
    return '未知';
  }

  bool get ready => dirty == false && remoteState.synced == true;

  List<String> get failures {
    final failures = <String>[];
    if (dirty != false) {
      failures.add('代码工作区：$worktreeLabel。');
    }
    if (remoteState.synced != true) {
      failures.add('远端同步：$remoteLabel。');
    }
    return failures;
  }

  List<_AcceptanceGateGap> get gateGaps {
    final gaps = <_AcceptanceGateGap>[];
    if (dirty != false) {
      gaps.add(
        _AcceptanceGateGap(
          title: '代码工作区',
          current: worktreeLabel,
          required: '工作区干净，无未提交改动',
        ),
      );
    }
    if (remoteState.synced != true) {
      gaps.add(
        _AcceptanceGateGap(
          title: '远端同步',
          current:
              '$remoteLabel，ahead ${remoteState.aheadLabel}，behind ${remoteState.behindLabel}',
          required: '当前提交已推送并与上游同步',
        ),
      );
    }
    return gaps;
  }

  // 转为 JSON，保持旧顶层 git 字段之外的扩展指纹。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'revision': revision,
      'branch': branch,
      'dirty': dirty,
      'worktree': worktreeLabel,
      'upstream': upstream,
      'ahead': remoteState.ahead,
      'behind': remoteState.behind,
      'synced': remoteState.synced,
      'remote': remoteLabel,
    };
  }
}

// GitRemoteState 只记录 ahead / behind 数字，不保存远端 URL。
final class _GitRemoteState {
  const _GitRemoteState({required this.ahead, required this.behind});

  const _GitRemoteState.unknown() : ahead = -1, behind = -1;

  final int ahead;
  final int behind;

  bool? get synced {
    if (ahead < 0 || behind < 0) return null;
    return ahead == 0 && behind == 0;
  }

  String get aheadLabel => ahead < 0 ? '未知' : '$ahead';

  String get behindLabel => behind < 0 ? '未知' : '$behind';
}

// 终验门禁缺口，描述还差哪类证据才能完成。
final class _AcceptanceGateGap {
  const _AcceptanceGateGap({
    required this.title,
    required this.current,
    required this.required,
    this.command,
  });

  final String title;
  final String current;
  final String required;
  final String? command;

  String get commandMarkdown {
    final value = command;
    if (value == null || value.isEmpty) return '-';
    return '`$value`';
  }

  String get stderrLine {
    final value = command;
    final suffix = value == null || value.isEmpty ? '' : '；建议命令：$value';
    return '$title：${_trimForStderr(current)}；通过标准：${_trimForStderr(required)}$suffix';
  }

  // 转为 JSON，保持短命令和脱敏短文案。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'title': title,
      'current': current,
      'required': required,
      'command': command,
    };
  }
}

// 现场补验项，用于把多条下一步整理成稳定执行顺序。
final class _AcceptanceChecklistItem {
  const _AcceptanceChecklistItem({
    required this.order,
    required this.title,
    required this.proof,
    this.command,
  });

  final int order;
  final String title;
  final String proof;
  final String? command;

  String get commandMarkdown {
    final value = command;
    if (value == null || value.isEmpty) return '-';
    return '`$value`';
  }

  String get stderrLine {
    final value = command;
    final commandPart = value == null || value.isEmpty ? '无需命令' : value;
    return '$order. $title：$commandPart；通过标准：$proof';
  }

  // 转为 JSON，命令保持短 npm 入口，不写本机路径或设备标识。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'order': order,
      'title': title,
      'command': command,
      'proof': proof,
    };
  }
}

// 清理终端单行拼接前的收尾标点，避免出现“。；”这类噪声。
String _trimForStderr(String value) {
  return value.replaceFirst(RegExp(r'[。；;，,.\s]+$'), '');
}

// AcceptanceEvidenceSummary 汇总刚生成的 readiness 和 archive 脱敏摘要。
final class _AcceptanceEvidenceSummary {
  const _AcceptanceEvidenceSummary({
    required this.readiness,
    required this.archive,
  });

  final Map<String, Object?>? readiness;
  final Map<String, Object?>? archive;

  // 从本地报告目录读取最新 readiness / archive JSON，只读结构化摘要。
  static Future<_AcceptanceEvidenceSummary> load({
    required Directory outDir,
    required Directory archiveDir,
  }) async {
    return _AcceptanceEvidenceSummary(
      readiness: await _loadLatestReadiness(outDir),
      archive: await _loadLatestArchive(archiveDir),
    );
  }

  // 转为机器可读摘要，缺失报告时显式为 null。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{'readiness': readiness, 'archive': archive};
  }

  // 转为 Markdown 现场摘要，便于最终报告直接复盘。
  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln()
      ..writeln('## 现场摘要')
      ..writeln();
    if (readiness == null && archive == null) {
      buffer.writeln('- 未读取到 readiness 或 archive 摘要。');
      return buffer.toString();
    }
    if (readiness != null) {
      final localState = _jsonMapAt(readiness!, 'localState');
      buffer
        ..writeln('### 本机状态')
        ..writeln()
        ..writeln('| 项目 | 摘要 |')
        ..writeln('|---|---|');
      for (final entry in <String, String>{
        'Appium': 'appium',
        'iOS 隧道': 'iosTunnel',
        'iOS 手机': 'iosDevice',
        'Android 手机': 'androidDevice',
      }.entries) {
        buffer.writeln(
          '| ${entry.key} | ${_localStateLabel(localState[entry.value])} |',
        );
      }
      buffer.writeln();
      final artifacts = _jsonMapAt(readiness!, 'artifacts');
      final androidPreflight = _jsonMapAt(artifacts, 'latestAndroidPreflight');
      final batches = _jsonMapList(readiness!['batches']);
      if (batches.isNotEmpty) {
        buffer
          ..writeln('### 批次验收')
          ..writeln()
          ..writeln('| 批次 | 判定 | 证据 |')
          ..writeln('|---|---|---|');
        for (final batch in batches) {
          buffer.writeln(
            '| ${_plainText(batch['name']?.toString() ?? '未知批次')} | '
            '${_plainText(batch['status']?.toString() ?? '未知')} | '
            '${_plainText(batch['evidence']?.toString() ?? '无')} |',
          );
        }
        buffer.writeln();
      }
      if (androidPreflight.isNotEmpty) {
        buffer
          ..writeln('### Android smoke 前置诊断')
          ..writeln()
          ..writeln(
            '- 最近：${_plainText(androidPreflight['summary']?.toString() ?? '无摘要')}',
          );
        final blockers = _jsonStringList(androidPreflight['blockers']);
        if (blockers.isNotEmpty) {
          buffer.writeln('- 阻断：${blockers.join('、')}');
        }
        buffer.writeln();
      }
    }
    if (archive != null) {
      final latestFullSmoke = _jsonMapAt(archive!, 'latestFullSmoke');
      if (latestFullSmoke.isNotEmpty) {
        buffer
          ..writeln('### 最近完整冒烟')
          ..writeln()
          ..writeln('- 最近：${_latestFullSmokeLine(latestFullSmoke)}');
        final blockers = _jsonStringList(latestFullSmoke['blockers']);
        if (blockers.isNotEmpty) {
          buffer.writeln('- 阻断：${blockers.join('、')}');
        }
        buffer.writeln();
      }
      final counts = _jsonMapAt(archive!, 'counts');
      buffer
        ..writeln('### 留档数量')
        ..writeln()
        ..writeln('| 项目 | 数量 |')
        ..writeln('|---|---:|')
        ..writeln('| 截图 | ${counts['screenshots'] ?? 0} |')
        ..writeln('| iOS 运行 | ${counts['iosRuns'] ?? 0} |')
        ..writeln('| Android 运行 | ${counts['androidRuns'] ?? 0} |')
        ..writeln('| Full smoke | ${counts['fullSmokeReports'] ?? 0} |')
        ..writeln();

      final screenshotArtifacts = _jsonMapList(archive!['screenshotArtifacts']);
      if (screenshotArtifacts.isNotEmpty) {
        buffer
          ..writeln('### 截图留档')
          ..writeln();
        for (final screenshot in screenshotArtifacts.take(10)) {
          final path = _plainText(
            screenshot['relativePath']?.toString() ?? '未知截图',
          );
          final bytes = screenshot['bytes']?.toString();
          final suffix = bytes == null || bytes.isEmpty
              ? ''
              : ' (${bytes} bytes)';
          buffer.writeln('- `$path`$suffix');
        }
        if (screenshotArtifacts.length > 10) {
          buffer.writeln(
            '- 其余 ${screenshotArtifacts.length - 10} 张见 archive JSON。',
          );
        }
        buffer.writeln();
      }
    }
    return buffer.toString();
  }
}

// 格式化 archive 中最近 full smoke 的短摘要。
String _latestFullSmokeLine(Map<String, Object?> summary) {
  final label = _plainText(summary['label']?.toString() ?? '未知');
  final timestamp = _plainText(summary['timestamp']?.toString() ?? '无时间');
  return '$label，时间 $timestamp';
}

// 从 archive warnings 和 readiness 最近平台状态生成终验门禁缺口。
List<_AcceptanceGateGap> _gateGapsFromEvidence(
  _AcceptanceEvidenceSummary evidence,
) {
  final archive = evidence.archive;
  final readinessArtifacts = _jsonMapAt(
    evidence.readiness ?? const <String, Object?>{},
    'artifacts',
  );
  final localState = _jsonMapAt(
    evidence.readiness ?? const <String, Object?>{},
    'localState',
  );
  final latestFullSmoke = _jsonMapAt(
    archive ?? const <String, Object?>{},
    'latestFullSmoke',
  );
  final iosTunnelNeeded = _jsonStringList(
    latestFullSmoke['blockers'],
  ).any((blocker) => blocker.contains('iOS 隧道'));
  final gaps = <_AcceptanceGateGap>[
    if (archive != null)
      ..._jsonStringList(
        archive['warnings'],
      ).map((warning) => _gateGapFromWarning(warning, iosTunnelNeeded)),
  ];

  void addOrReplace(_AcceptanceGateGap gap) {
    final index = gaps.indexWhere((item) => item.title == gap.title);
    if (index < 0) {
      gaps.add(gap);
    } else {
      gaps[index] = gap;
    }
  }

  if (readinessArtifacts.isNotEmpty) {
    final latestIos = _jsonMapAt(readinessArtifacts, 'latestIos');
    if (_platformSmokeNeedsGap(latestIos)) {
      addOrReplace(
        _platformSmokeGateGap(
          title: 'iOS smoke',
          platformLabel: 'iOS',
          latest: latestIos,
          localDevice: _jsonMapAt(localState, 'iosDevice'),
          command: iosTunnelNeeded
              ? 'npm run v4:ios-smoke:full:password-prompt'
              : 'npm run v4:ios-smoke:full',
        ),
      );
    }

    final latestAndroid = _jsonMapAt(readinessArtifacts, 'latestAndroid');
    if (_platformSmokeNeedsGap(latestAndroid)) {
      addOrReplace(
        _platformSmokeGateGap(
          title: 'Android smoke',
          platformLabel: 'Android',
          latest: latestAndroid,
          localDevice: _jsonMapAt(localState, 'androidDevice'),
          command: 'npm run v4:android-smoke:full',
        ),
      );
    }
  }

  return gaps;
}

// 判断最近平台 smoke 是否缺失或未完整通过。
bool _platformSmokeNeedsGap(Map<String, Object?> latest) {
  return latest.isEmpty || latest['fullPassed'] != true;
}

// 将最近平台 smoke 状态转成终验门禁项。
_AcceptanceGateGap _platformSmokeGateGap({
  required String title,
  required String platformLabel,
  required Map<String, Object?> latest,
  required Map<String, Object?> localDevice,
  required String command,
}) {
  final currentParts = <String>[
    if (localDevice.isNotEmpty)
      '$platformLabel 当前状态：${_localStateLabel(localDevice)}',
    latest.isEmpty
        ? '未发现 $platformLabel 平台 smoke run。'
        : '$platformLabel 最近未完整通过：${_plainText(latest['summary']?.toString() ?? latest['status']?.toString() ?? '无摘要')}',
  ];
  return _AcceptanceGateGap(
    title: title,
    current: currentParts.join('；'),
    required: '$platformLabel 真机 smoke run 完整通过',
    command: command,
  );
}

// 将 archive 提醒映射成用户能执行的门禁项。
_AcceptanceGateGap _gateGapFromWarning(String warning, bool iosTunnelNeeded) {
  final text = _plainText(warning);
  if (text.contains('readiness JSON')) {
    return _AcceptanceGateGap(
      title: 'Readiness',
      current: text,
      required: '生成 readiness JSON 留档',
      command: 'npm run v4:smoke-readiness',
    );
  }
  if (text.contains('full smoke JSON')) {
    return _AcceptanceGateGap(
      title: 'Full smoke',
      current: text,
      required: '生成双平台 full smoke JSON 留档',
      command: iosTunnelNeeded
          ? 'npm run v4:smoke:full:password-prompt'
          : 'npm run v4:smoke:full',
    );
  }
  if (text.contains('截图')) {
    return _AcceptanceGateGap(
      title: '截图',
      current: text,
      required: '至少保留一张 Mac App 或设备 smoke 截图',
    );
  }
  if (text.contains('iOS 平台')) {
    return _AcceptanceGateGap(
      title: 'iOS smoke',
      current: text,
      required: 'iOS 真机 smoke run 留档存在',
      command: iosTunnelNeeded
          ? 'npm run v4:ios-smoke:full:password-prompt'
          : 'npm run v4:ios-smoke:full',
    );
  }
  if (text.contains('Android 平台')) {
    return _AcceptanceGateGap(
      title: 'Android smoke',
      current: text,
      required: 'Android 真机 smoke run 留档存在',
      command: 'npm run v4:android-smoke:full',
    );
  }
  if (text.contains('full smoke')) {
    return _AcceptanceGateGap(
      title: 'Full smoke',
      current: text,
      required: '最近双平台 full smoke 完整通过',
      command: iosTunnelNeeded
          ? 'npm run v4:smoke:full:password-prompt'
          : 'npm run v4:smoke:full',
    );
  }
  return _AcceptanceGateGap(
    title: '其它门禁',
    current: text,
    required: '按 archive 提醒补齐对应证据',
  );
}

// 读取最新 readiness 报告的关键摘要。
Future<Map<String, Object?>?> _loadLatestReadiness(Directory outDir) async {
  final json = await _loadLatestJson(
    outDir,
    RegExp(r'^SMOKE_READINESS_.*\.json$'),
  );
  if (json == null) return null;
  return <String, Object?>{
    'completion': _redactJsonValue(_jsonMapAt(json, 'completion')),
    'localState': _redactJsonValue(_jsonMapAt(json, 'localState')),
    'batches': _redactJsonValue(json['batches']),
    'artifacts': <String, Object?>{
      'androidPreflightReports':
          _jsonMapAt(json, 'artifacts')['androidPreflightReports'] ?? 0,
      'latestIos': _redactJsonValue(_jsonMapAt(json, 'artifacts')['latestIos']),
      'latestAndroid': _redactJsonValue(
        _jsonMapAt(json, 'artifacts')['latestAndroid'],
      ),
      'latestAndroidPreflight': _redactJsonValue(
        _jsonMapAt(json, 'artifacts')['latestAndroidPreflight'],
      ),
    },
    'nextSteps': _redactJsonValue(json['nextSteps']),
  };
}

// 读取最新 archive 报告的关键摘要。
Future<Map<String, Object?>?> _loadLatestArchive(Directory archiveDir) async {
  final json = await _loadLatestJson(
    archiveDir,
    RegExp(r'^SMOKE_ARCHIVE_.*\.json$'),
  );
  if (json == null) return null;
  final summary = _jsonMapAt(json, 'summary');
  final artifacts = _jsonMapList(json['artifacts']);
  final screenshots = artifacts
      .where((entry) => entry['kind'] == 'screenshot')
      .take(20)
      .map(_redactJsonValue)
      .toList(growable: false);
  return <String, Object?>{
    'counts': <String, Object?>{
      'screenshots': summary['screenshots'] ?? 0,
      'iosRuns': summary['iosRuns'] ?? 0,
      'androidRuns': summary['androidRuns'] ?? 0,
      'fullSmokeReports': summary['fullSmokeReports'] ?? 0,
    },
    'latestFullSmoke': _redactJsonValue(summary['latestFullSmoke']),
    'screenshotArtifacts': screenshots,
    'warnings': _redactJsonValue(json['warnings']),
  };
}

// 读取目录下最新匹配 JSON，按文件名时间戳倒序挑选。
Future<Map<String, Object?>?> _loadLatestJson(
  Directory dir,
  RegExp namePattern,
) async {
  if (!await dir.exists()) return null;
  final files = <File>[];
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (namePattern.hasMatch(name)) files.add(entity);
  }
  if (files.isEmpty) return null;
  files.sort(
    (left, right) =>
        right.uri.pathSegments.last.compareTo(left.uri.pathSegments.last),
  );
  try {
    final decoded = jsonDecode(await files.first.readAsString());
    if (decoded is! Map) return null;
    return Map<String, Object?>.from(decoded);
  } on Object {
    return null;
  }
}

// 安全读取嵌套 Map。
Map<String, Object?> _jsonMapAt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return const <String, Object?>{};
}

// 读取 JSON 对象列表，坏值过滤；用于嵌入 Batch 0-8 验收索引。
List<Map<String, Object?>> _jsonMapList(Object? value) {
  if (value is! Iterable) return const <Map<String, Object?>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: false);
}

// 读取 JSON 字符串列表，坏值直接过滤并脱敏。
List<String> _jsonStringList(Object? value) {
  if (value is! Iterable) return const <String>[];
  return value
      .map((item) => _plainText(item?.toString() ?? ''))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

// 生成适合 Markdown 单行展示的脱敏文本。
String _plainText(String value) {
  return _redactText(value).replaceAll(RegExp(r'\s+'), ' ').trim();
}

// 生成本机状态短摘要，避免 Markdown 报告铺满底层字段。
String _localStateLabel(Object? value) {
  if (value is! Map) return '未知';
  final map = Map<String, Object?>.from(value);
  final status = map['status']?.toString();
  final detail = map['detail']?.toString();
  if ((status == null || status.isEmpty) &&
      (detail == null || detail.isEmpty)) {
    return '未知';
  }
  if (detail == null || detail.isEmpty) return status ?? '未知';
  if (status == null || status.isEmpty) return detail;
  return '$status，$detail';
}

// 从失败文本中提炼下一步命令，保证最终报告能直接指导现场补验。
List<String> _nextStepsForFailures({
  required List<String> failures,
  required bool auditOk,
  required _AcceptanceEvidenceSummary evidence,
}) {
  final joined = failures.join('\n');
  final steps = <String>[];
  final counts = _jsonMapAt(
    evidence.archive ?? const <String, Object?>{},
    'counts',
  );
  final readinessArtifacts = _jsonMapAt(
    evidence.readiness ?? const <String, Object?>{},
    'artifacts',
  );
  final latestFullSmoke = _jsonMapAt(
    evidence.archive ?? const <String, Object?>{},
    'latestFullSmoke',
  );
  final needsIosSmoke =
      joined.contains('iOS 平台') ||
      (counts.isNotEmpty && (counts['iosRuns'] ?? 0) == 0) ||
      _reportIsNotFullPassed(readinessArtifacts['latestIos']);
  final needsAndroidSmoke =
      joined.contains('Android 平台') ||
      (counts.isNotEmpty && (counts['androidRuns'] ?? 0) == 0) ||
      _reportIsNotFullPassed(readinessArtifacts['latestAndroid']);
  final needsFullSmoke =
      joined.contains('full smoke') ||
      joined.contains('双平台完整 smoke') ||
      (latestFullSmoke.isNotEmpty && latestFullSmoke['complete'] != true);
  final latestFullSmokeBlockers = _jsonStringList(latestFullSmoke['blockers']);
  final latestFullSmokeNeedsIosTunnel = latestFullSmokeBlockers.any(
    (blocker) => blocker.contains('iOS 隧道'),
  );
  if (!auditOk) {
    steps.add(
      '基础：先运行 `npm run v4:smoke-readiness` 和 `npm run v4:smoke-archive`。',
    );
  }
  if (joined.contains('代码工作区')) {
    steps.add('代码：提交或撤销本地改动，保持工作区干净。');
  }
  if (joined.contains('远端同步')) {
    steps.add('远端：推送当前提交，并确认本地与上游同步。');
  }
  if (needsIosSmoke) {
    if (latestFullSmokeNeedsIosTunnel) {
      steps.add(
        'iOS：先用 Mac App 点连接设备，或运行 `npm run v4:ios-smoke:full:password-prompt` 输入 Mac 密码后补验。',
      );
    } else {
      steps.add('iOS：连接并信任一台 iPhone，运行 `npm run v4:ios-smoke:full`。');
    }
  }
  if (needsAndroidSmoke) {
    steps.add('Android：连接一台已开启 USB 调试的手机，运行 `npm run v4:android-smoke:full`。');
  }
  if (joined.contains('截图') ||
      (counts.isNotEmpty && (counts['screenshots'] ?? 0) == 0)) {
    steps.add('截图：保留 Mac App 或设备 smoke 截图，再重新生成 archive。');
  }
  if (needsFullSmoke) {
    final command = latestFullSmokeNeedsIosTunnel
        ? 'npm run v4:smoke:full:password-prompt'
        : 'npm run v4:smoke:full';
    steps.add('双平台：iOS 和 Android 单平台 smoke 都通过后，运行 `$command`。');
  }
  steps.add('终验：补齐留档后运行 `npm run v4:acceptance-final`。');
  return steps.toSet().toList(growable: false);
}

// 根据下一步生成现场执行顺序，避免用户在多条命令间来回试错。
List<_AcceptanceChecklistItem> _fieldChecklistForNextSteps(
  List<String> nextSteps, {
  required bool complete,
  required _AcceptanceEvidenceSummary evidence,
}) {
  if (complete) {
    return const <_AcceptanceChecklistItem>[
      _AcceptanceChecklistItem(
        order: 1,
        title: '保留报告',
        proof: '最终验收已通过，保留本次 Markdown、JSON、截图和平台 smoke 留档。',
      ),
    ];
  }

  final joined = nextSteps.join('\n');
  final localState = _jsonMapAt(
    evidence.readiness ?? const <String, Object?>{},
    'localState',
  );
  final iosDevice = _jsonMapAt(localState, 'iosDevice');
  final androidDevice = _jsonMapAt(localState, 'androidDevice');
  final items = <_AcceptanceChecklistItem>[];
  var order = 1;

  void add({required String title, required String proof, String? command}) {
    items.add(
      _AcceptanceChecklistItem(
        order: order,
        title: title,
        command: command,
        proof: proof,
      ),
    );
    order += 1;
  }

  if (joined.contains('提交或撤销本地改动')) {
    add(title: '清代码', proof: '工作区干净，没有未提交改动。');
  }

  if (joined.contains('推送当前提交')) {
    add(title: '推远端', proof: '当前提交已推送，ahead 0 且 behind 0。');
  }

  if (joined.contains('v4:ios-smoke:full:password-prompt')) {
    add(
      title: '补 iOS',
      command: 'npm run v4:ios-smoke:full:password-prompt',
      proof: _iosChecklistProof(iosDevice, needsPasswordPrompt: true),
    );
  } else if (joined.contains('v4:ios-smoke:full')) {
    add(
      title: '补 iOS',
      command: 'npm run v4:ios-smoke:full',
      proof: _iosChecklistProof(iosDevice, needsPasswordPrompt: false),
    );
  }

  if (joined.contains('v4:android-smoke:full')) {
    add(
      title: '补 Android',
      command: 'npm run v4:android-smoke:full',
      proof: _androidChecklistProof(androidDevice),
    );
  }

  if (joined.contains('v4:smoke:full:password-prompt')) {
    add(
      title: '跑全量',
      command: 'npm run v4:smoke:full:password-prompt',
      proof: _fullSmokeChecklistProof(iosDevice, androidDevice),
    );
  } else if (joined.contains('v4:smoke:full')) {
    add(
      title: '跑全量',
      command: 'npm run v4:smoke:full',
      proof: _fullSmokeChecklistProof(iosDevice, androidDevice),
    );
  }

  if (joined.contains('v4:acceptance-final')) {
    add(
      title: '做终验',
      command: 'npm run v4:acceptance-final',
      proof: '终验返回 0，并保留 FINAL_ACCEPTANCE Markdown / JSON。',
    );
  }

  if (items.isEmpty) {
    add(
      title: '重跑审计',
      command: 'npm run v4:acceptance-audit',
      proof: '重新生成现场摘要，按新的下一步继续补验。',
    );
  }

  return items;
}

// 生成 iOS 补验通过标准；有现场状态时优先提示当前阻断点。
String _iosChecklistProof(
  Map<String, Object?> device, {
  required bool needsPasswordPrompt,
}) {
  final state = _localChecklistState(device);
  if (state == null) {
    return needsPasswordPrompt
        ? '隐藏输入 Mac 密码，手机解锁并点允许，生成 iOS smoke 留档。'
        : 'iPhone 已连接、已信任，生成 iOS smoke 留档。';
  }
  if (state.available) {
    return needsPasswordPrompt
        ? '当前 iOS 可用（${state.label}）。手机保持解锁并点允许，生成 iOS smoke 留档。'
        : '当前 iOS 可用（${state.label}）。生成 iOS smoke 留档。';
  }
  return needsPasswordPrompt
      ? '当前 iOS 未就绪（${state.label}）。先插线、解锁并信任，再输入 Mac 密码补验。'
      : '当前 iOS 未就绪（${state.label}）。先插线、解锁并信任，再补验。';
}

// 生成 Android 补验通过标准；只提示 USB 调试和授权，不展开 ADB 细节。
String _androidChecklistProof(Map<String, Object?> device) {
  final state = _localChecklistState(device);
  if (state == null) {
    return '只连接一台已允许 USB 调试的 Android 手机，生成 Android smoke 留档。';
  }
  if (state.available) {
    return '当前 Android 可用（${state.label}）。生成 Android smoke 留档。';
  }
  return '当前 Android 未就绪（${state.label}）。先插线、开 USB 调试并点允许，再补验。';
}

// 生成双平台 full smoke 通过标准；设备未就绪时先引导补单平台留档。
String _fullSmokeChecklistProof(
  Map<String, Object?> iosDevice,
  Map<String, Object?> androidDevice,
) {
  final iosState = _localChecklistState(iosDevice);
  final androidState = _localChecklistState(androidDevice);
  final missing = <String>[
    if (iosState != null && !iosState.available) 'iOS',
    if (androidState != null && !androidState.available) 'Android',
  ];
  if (missing.isNotEmpty) {
    return '当前 ${missing.join('、')} 未就绪。先补齐单平台 smoke，再跑全量。';
  }
  return 'iOS 和 Android 单平台 smoke 都通过，双平台 full smoke 完整通过。';
}

// 把 readiness 本机状态收敛成清单可展示的短句，缺失时允许降级。
_ChecklistLocalState? _localChecklistState(Map<String, Object?> device) {
  if (device.isEmpty) return null;
  return _ChecklistLocalState(
    available: device['available'] == true,
    label: _plainText(_localStateLabel(device)),
  );
}

// 现场清单里的本机设备短状态。
final class _ChecklistLocalState {
  const _ChecklistLocalState({required this.available, required this.label});

  final bool available;
  final String label;
}

// 判断单平台 smoke 摘要是否存在但尚未完整通过。
bool _reportIsNotFullPassed(Object? value) {
  if (value == null) return false;
  if (value is Map<String, Object?>) return value['fullPassed'] != true;
  if (value is Map)
    return Map<String, Object?>.from(value)['fullPassed'] != true;
  return false;
}

const _usage = '''
V4 final acceptance

用法：
  fvm dart run tool/v4_final_acceptance.dart [选项]

选项：
  --out-dir <path>          smoke 结果目录，默认 recordings/v4-smoke
  --archive-dir <path>      archive 输出目录，默认 <out-dir>/archives
  --report-dir <path>       final acceptance 输出目录，默认 <out-dir>/acceptance
  --probe-timeout <seconds> readiness / archive 探测超时，默认 4
  --step-timeout <seconds>  单步骤超时，默认 60
  --require-complete        最终验收未通过时返回非 0
  --help                    查看帮助
''';
