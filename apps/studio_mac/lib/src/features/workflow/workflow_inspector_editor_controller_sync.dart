part of '../../studio_mac_workspace.dart';

// Inspector 控制器同步扩展，负责节点切换时把 DSL 参数写入输入框。
extension _NodeInspectorEditorControllerSyncState on _NodeInspectorEditorState {
  // 从当前节点同步所有输入控制器，切换节点时保持草稿一致。
  void _syncFromNodes() {
    _labelController.text = widget.node.label;
    _xController.text = widget.node.parameters['x']?.toString() ?? '';
    _yController.text = widget.node.parameters['y']?.toString() ?? '';
    _msController.text = widget.node.parameters['ms']?.toString() ?? '';
    if (widget.node.type == WorkflowNodeType.waitForTarget) {
      _msController.text =
          widget.node.parameters['timeoutMs']?.toString() ?? '';
    }
    _fromXController.text = widget.node.parameters['fromX']?.toString() ?? '';
    _fromYController.text = widget.node.parameters['fromY']?.toString() ?? '';
    _toXController.text = widget.node.parameters['toX']?.toString() ?? '';
    _toYController.text = widget.node.parameters['toY']?.toString() ?? '';
    _durationController.text =
        widget.node.parameters['durationMs']?.toString() ?? '';
    _textController.text = widget.node.parameters['text']?.toString() ?? '';
    if (widget.node.type == WorkflowNodeType.waitForTarget) {
      _durationController.text =
          widget.node.parameters['intervalMs']?.toString() ?? '';
      _textController.text =
          widget.node.parameters['targetRef']?.toString() ?? '';
    }
    _loopCountController.text =
        widget.node.parameters['count']?.toString() ?? '';
    _expressionController.text =
        widget.node.parameters['expression']?.toString() ?? '';
    _confidenceController.text =
        widget.node.parameters['confidenceThreshold']?.toString() ?? '';
    _maxRetriesController.text =
        widget.node.parameters['maxRetries']?.toString() ?? '';
    _onErrorController.text =
        widget.node.parameters['onError']?.toString() ?? '';
    _workflowIdController.text =
        widget.node.parameters['workflowId']?.toString() ?? '';
    _inputMapController.text = _subWorkflowInputMapText(
      widget.node.parameters['inputMap'],
    );
    _saveEvidence = widget.node.parameters['saveEvidence'] != false;
    _syncEdgeTarget();
  }
}
