part of '../studio_runtime.dart';

// MobileDriverSmokePlan 描述一次跨平台 driver 冒烟流程。
// 默认不执行真实动作，避免误触用户当前手机界面。
final class MobileDriverSmokePlan {
  // 创建 driver 冒烟计划。
  const MobileDriverSmokePlan({
    this.workflowName = 'V4 Mobile Driver Smoke',
    this.allowActions = false,
    this.inputText = 'ios-assist-smoke',
    this.workflow,
    this.useBasicWorkflow = false,
    this.maxWait = const Duration(seconds: 1),
  }) : assert(
         workflow == null || !useBasicWorkflow,
         'workflow 和 useBasicWorkflow 不能同时启用。',
       );

  final String workflowName;
  final bool allowActions;
  final String inputText;
  final WorkflowDefinition? workflow;
  final bool useBasicWorkflow;
  final Duration maxWait;
}

// MobileDriverSmokeReport 是一次冒烟运行的脱敏摘要。
// 它只暴露 runId、设备摘要和 evidence 相对引用。
final class MobileDriverSmokeReport {
  // 创建 driver 冒烟报告。
  const MobileDriverSmokeReport({
    required this.runId,
    required this.platform,
    required this.device,
    required this.status,
    required this.screenshotRef,
    required this.logs,
    required this.actionsExecuted,
  });

  final String runId;
  final MobilePlatform platform;
  final MobileDeviceSummary? device;
  final String status;
  final String? screenshotRef;
  final List<String> logs;
  final bool actionsExecuted;
}

// MobileDriverSmokeRunner 用统一 driver contract 跑最小冒烟并写入 evidence。
// 它不理解 Flutter UI，也不绕过 MobileDeviceDriver 的平台边界。
final class MobileDriverSmokeRunner {
  // 创建跨平台 driver 冒烟 runner。
  const MobileDriverSmokeRunner({
    required MobileDeviceDriver driver,
    required RunEvidenceStore evidenceStore,
  }) : _driver = driver,
       _evidenceStore = evidenceStore;

  final MobileDeviceDriver _driver;
  final RunEvidenceStore _evidenceStore;

  // 执行一次冒烟流程，并确保 driver 断开和 evidence 收尾。
  Future<MobileDriverSmokeReport> run(MobileDriverSmokePlan plan) async {
    final startedAt = DateTime.now();
    final runId = await _evidenceStore.startRun(
      workflowName: plan.workflowName,
      loops: 1,
      startedAt: startedAt,
    );
    MobileDriverSession? session;
    MobileScreenshot? screenshot;
    String? screenshotRef;
    var logs = const <String>[];

    try {
      await _record(runId, 'smokeStart', {
        'platform': _driver.platform.name,
        'actionsAllowed': plan.allowActions,
      });
      session = await _driver.connect();
      await _record(runId, 'smokeSession', {
        'platform': session.platform.name,
        'device': _deviceJson(session.device),
      });

      screenshot = await _driver.captureScreenshot();
      screenshotRef = await _evidenceStore.recordScreenshot(
        runId,
        fileName: 'smoke-initial.png',
        base64Png: screenshot.base64Png,
      );
      await _record(runId, 'smokeScreenshot', {
        'screenshot': screenshotRef,
        'viewport': _viewportJson(screenshot.viewport),
      });

      final workflow = plan.workflow ?? _basicWorkflow(screenshot, plan);
      if (plan.allowActions) {
        if (workflow != null) {
          await _runWorkflow(runId, workflow, plan);
        } else {
          await _runActions(runId, screenshot.viewport, plan.inputText);
        }
      } else {
        await _record(runId, 'smokeActionsSkipped', {
          'reason': 'actions require explicit opt-in',
          if (workflow != null) 'workflow': workflow.name,
        });
      }

      logs = await _driver.collectLogs();
      await _record(runId, 'smokeLogs', {
        'count': logs.length,
        'lines': logs.take(40).toList(growable: false),
      });

      await _finish(runId, status: 'success');
      return MobileDriverSmokeReport(
        runId: runId,
        platform: session.platform,
        device: session.device,
        status: 'success',
        screenshotRef: screenshotRef,
        logs: logs,
        actionsExecuted: plan.allowActions,
      );
    } on Object catch (error) {
      await _record(runId, 'smokeFailure', {
        'message': _redactConnectionDetail(error.toString()),
      });
      await _finish(runId, status: 'failed');
      rethrow;
    } finally {
      if (plan.allowActions && screenshot != null) {
        await _safeRelease(runId);
      }
      try {
        await _driver.disconnect();
      } on Object catch (error) {
        await _record(runId, 'smokeDisconnectWarning', {
          'message': _redactConnectionDetail(error.toString()),
        });
      }
    }
  }

  // 执行最小动作 workflow：Tap -> Swipe -> Input。
  Future<void> _runActions(
    String runId,
    ViewportSize? viewport,
    String inputText,
  ) async {
    if (viewport == null) {
      throw StateError('缺少屏幕尺寸，无法执行动作冒烟。');
    }
    final center = ViewportPoint(
      x: (viewport.width / 2).round(),
      y: (viewport.height / 2).round(),
    );
    try {
      await _driver.tap(center);
    } finally {
      await _driver.releaseActions();
    }
    await _record(runId, 'smokeAction', {'action': 'tap'});

    try {
      await _driver.swipe(
        ViewportPoint(
          x: (viewport.width / 2).round(),
          y: (viewport.height * 0.72).round(),
        ),
        ViewportPoint(
          x: (viewport.width / 2).round(),
          y: (viewport.height * 0.42).round(),
        ),
        duration: const Duration(milliseconds: 360),
      );
    } finally {
      await _driver.releaseActions();
    }
    await _record(runId, 'smokeAction', {'action': 'swipe'});

    await _driver.inputText(inputText);
    await _record(runId, 'smokeAction', {'action': 'input'});
  }

  // 执行一段受控线性 Project DSL workflow，用于真机基础冒烟。
  Future<void> _runWorkflow(
    String runId,
    WorkflowDefinition workflow,
    MobileDriverSmokePlan plan,
  ) async {
    final validation = const WorkflowValidator().validate(workflow);
    if (!validation.isValid) {
      throw StateError('冒烟流程无效：${validation.errors.length} 个问题。');
    }
    await _record(runId, 'smokeWorkflowStart', {
      'workflowId': workflow.id,
      'workflowName': workflow.name,
    });
    final nodesById = {for (final node in workflow.nodes) node.id: node};
    var current = nodesById[workflow.entryNodesId];
    final visited = <String>[];
    final stepLimit = workflow.nodes.length + 1;

    while (current != null) {
      if (visited.length > stepLimit) {
        throw StateError('冒烟流程超出线性步数限制。');
      }
      visited.add(current.id);
      await _runWorkflowNode(runId, current, plan);
      if (current.type == WorkflowNodeType.end) break;
      if (current.next.length > 1) {
        throw StateError('冒烟流程只支持线性节点：${current.id}。');
      }
      current = current.next.isEmpty ? null : nodesById[current.next.single];
    }

    await _record(runId, 'smokeWorkflowEnd', {
      'workflowId': workflow.id,
      'steps': visited.length,
    });
  }

  // 按当前截图尺寸生成一条基础 Project DSL 冒烟流程。
  WorkflowDefinition? _basicWorkflow(
    MobileScreenshot screenshot,
    MobileDriverSmokePlan plan,
  ) {
    if (!plan.useBasicWorkflow) return null;
    final viewport = screenshot.viewport;
    if (viewport == null) {
      throw StateError('缺少屏幕尺寸，无法生成基础 workflow 冒烟。');
    }
    final centerX = (viewport.width / 2).round();
    final centerY = (viewport.height / 2).round();
    final swipeStartY = (viewport.height * 0.72).round();
    final swipeEndY = (viewport.height * 0.42).round();
    return WorkflowDefinition(
      id: 'v4-basic-smoke',
      name: 'V4 基础冒烟流程',
      entryNodesId: 'start',
      nodes: [
        const WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['snapshot'],
        ),
        const WorkflowNode(
          id: 'snapshot',
          type: WorkflowNodeType.snapshot,
          label: '截图',
          next: ['tap'],
        ),
        WorkflowNode(
          id: 'tap',
          type: WorkflowNodeType.tap,
          label: '点按',
          next: const ['wait'],
          parameters: {'x': centerX, 'y': centerY, 'durationMs': 80},
        ),
        const WorkflowNode(
          id: 'wait',
          type: WorkflowNodeType.wait,
          label: '等待',
          next: ['swipe'],
          parameters: {'ms': 120},
        ),
        WorkflowNode(
          id: 'swipe',
          type: WorkflowNodeType.swipe,
          label: '滑动',
          next: const ['input'],
          parameters: {
            'fromX': centerX,
            'fromY': swipeStartY,
            'toX': centerX,
            'toY': swipeEndY,
            'durationMs': 360,
          },
        ),
        WorkflowNode(
          id: 'input',
          type: WorkflowNodeType.input,
          label: '输入',
          next: const ['end'],
          parameters: {'text': plan.inputText},
        ),
        const WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
  }

  // 执行一个受控基础节点，不支持分支和子流程。
  Future<void> _runWorkflowNode(
    String runId,
    WorkflowNode node,
    MobileDriverSmokePlan plan,
  ) async {
    switch (node.type) {
      case WorkflowNodeType.start:
        await _record(runId, 'smokeWorkflowStep', {
          'nodeId': node.id,
          'nodeType': node.type.name,
          'status': 'ok',
        });
      case WorkflowNodeType.end:
        await _record(runId, 'smokeWorkflowStep', {
          'nodeId': node.id,
          'nodeType': node.type.name,
          'status': 'ok',
        });
      case WorkflowNodeType.tap:
        final point = ViewportPoint(
          x: _requiredInt(node, 'x'),
          y: _requiredInt(node, 'y'),
        );
        try {
          await _driver.tap(point, duration: _optionalDuration(node));
        } finally {
          await _driver.releaseActions();
        }
        await _record(runId, 'smokeWorkflowStep', {
          'nodeId': node.id,
          'nodeType': node.type.name,
          'status': 'ok',
          'x': point.x,
          'y': point.y,
        });
      case WorkflowNodeType.wait:
        final wait = Duration(milliseconds: _requiredInt(node, 'ms'));
        await Future<void>.delayed(_clampWait(wait, plan.maxWait));
        await _record(runId, 'smokeWorkflowStep', {
          'nodeId': node.id,
          'nodeType': node.type.name,
          'status': 'ok',
          'ms': wait.inMilliseconds,
        });
      case WorkflowNodeType.swipe:
        final from = ViewportPoint(
          x: _requiredInt(node, 'fromX'),
          y: _requiredInt(node, 'fromY'),
        );
        final to = ViewportPoint(
          x: _requiredInt(node, 'toX'),
          y: _requiredInt(node, 'toY'),
        );
        try {
          await _driver.swipe(from, to, duration: _optionalDuration(node));
        } finally {
          await _driver.releaseActions();
        }
        await _record(runId, 'smokeWorkflowStep', {
          'nodeId': node.id,
          'nodeType': node.type.name,
          'status': 'ok',
        });
      case WorkflowNodeType.input:
        final text = node.parameters['text']?.toString();
        if (text == null) {
          throw StateError('输入节点 ${node.id} 需要文本。');
        }
        await _driver.inputText(text);
        await _record(runId, 'smokeWorkflowStep', {
          'nodeId': node.id,
          'nodeType': node.type.name,
          'status': 'ok',
          'textLength': text.length,
        });
      case WorkflowNodeType.snapshot:
        final screenshot = await _driver.captureScreenshot();
        final ref = await _evidenceStore.recordScreenshot(
          runId,
          fileName: '${node.id}.png',
          base64Png: screenshot.base64Png,
        );
        await _record(runId, 'smokeWorkflowStep', {
          'nodeId': node.id,
          'nodeType': node.type.name,
          'status': 'ok',
          'screenshot': ref,
        });
      case WorkflowNodeType.condition:
      case WorkflowNodeType.visualBranch:
      case WorkflowNodeType.waitForTarget:
      case WorkflowNodeType.loop:
      case WorkflowNodeType.catchNodes:
      case WorkflowNodeType.subWorkflow:
        throw StateError('冒烟流程暂不支持节点类型：${node.type.name}。');
    }
  }

  // 释放 W3C actions，失败时只写 warning。
  Future<void> _safeRelease(String runId) async {
    try {
      await _driver.releaseActions();
      await _record(runId, 'smokeActionRelease', {'ok': true});
    } on Object catch (error) {
      await _record(runId, 'smokeActionRelease', {
        'ok': false,
        'message': _redactConnectionDetail(error.toString()),
      });
    }
  }

  // 读取节点必填整数参数。
  int _requiredInt(WorkflowNode node, String key) {
    final value = node.parameters[key];
    if (value is int) return value;
    if (value is num && value.isFinite) return value.round();
    throw StateError('节点 ${node.id} 缺少整数参数 $key。');
  }

  // 读取节点可选 durationMs。
  Duration? _optionalDuration(WorkflowNode node) {
    final value = node.parameters['durationMs'];
    if (value is int) return Duration(milliseconds: value);
    if (value is num && value.isFinite) {
      return Duration(milliseconds: value.round());
    }
    return null;
  }

  // 限制 smoke wait 时间，避免现场冒烟被长等待卡住。
  Duration _clampWait(Duration wait, Duration maxWait) {
    if (wait.isNegative) return Duration.zero;
    if (wait > maxWait) return maxWait;
    return wait;
  }

  // 写入一条 smoke evidence 事件。
  Future<void> _record(
    String runId,
    String type,
    Map<String, Object?> payload,
  ) {
    return _evidenceStore.recordEvent(runId, {'type': type, ...payload});
  }

  // 结束 smoke run，统一 completedLoops 为 1 或 0。
  Future<void> _finish(String runId, {required String status}) {
    return _evidenceStore.finishRun(
      runId,
      status: status,
      completedLoops: status == 'success' ? 1 : 0,
      finishedAt: DateTime.now(),
    );
  }

  // 把设备摘要转换成 evidence 可存储的脱敏字段。
  Map<String, Object?>? _deviceJson(MobileDeviceSummary? device) {
    if (device == null) return null;
    return {
      'platform': device.platform.name,
      'name': device.displayName,
      'id': device.maskedIdentifier,
      'version': device.osVersion,
      'connection': device.connectionKind.name,
    };
  }

  // 把 viewport 转成简单 JSON。
  Map<String, Object?>? _viewportJson(ViewportSize? viewport) {
    if (viewport == null) return null;
    return {'width': viewport.width, 'height': viewport.height};
  }
}
