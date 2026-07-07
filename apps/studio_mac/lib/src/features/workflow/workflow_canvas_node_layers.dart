part of '../../studio_mac_workspace.dart';

// Workflow 画布节点层，集中渲染节点卡片和输入/输出端口。
// 这里只组合现有交互入口，不直接写 Project DSL 或触发 Runtime 保存。

extension _WorkflowCanvasNodeLayers on _WorkflowVisualListState {
  // 构建节点卡片与端口层，保持主画布 build 只负责整体装配。
  List<Widget> _buildWorkflowCanvasNodeLayers(_WorkflowCanvasLayout layout) {
    return <Widget>[
      for (final node in widget.workflow.nodes)
        _buildWorkflowNodeCard(node, layout),
      for (final node in widget.workflow.nodes)
        ..._buildWorkflowNodePorts(node, layout),
    ];
  }

  // 渲染单个节点卡片，并把拖拽和选择事件交回画布动作分片。
  Widget _buildWorkflowNodeCard(
    WorkflowNode node,
    _WorkflowCanvasLayout layout,
  ) {
    return Positioned(
      left: layout.positions[node.id]?.dx ?? 0,
      top: layout.positions[node.id]?.dy ?? 0,
      width: _WorkflowCanvasLayout.nodeWidth,
      height: _WorkflowCanvasLayout.nodeHeight,
      child: GestureDetector(
        onPanUpdate: widget.locked
            ? null
            : (details) =>
                  _moveDragPosition(node, details.delta, layout.positions),
        onPanEnd: widget.locked
            ? null
            : (_) => _commitDragPosition(node, layout.positions),
        child: _WorkflowNodeRow(
          workflow: widget.workflow,
          node: node,
          entry: node.id == widget.workflow.entryNodesId,
          diagnostics:
              widget.diagnosticsByNodeId[node.id] ??
              const <_WorkflowSourceDiagnostic>[],
          executionState: _executionStateForNodes(
            node.id,
            widget.executionFocus,
          ),
          selected:
              node.id == widget.selectedNodeId ||
              widget.selectedNodeIds.contains(node.id),
          locked: widget.locked,
          onSelect: () => _selectNodeFromCanvas(node),
        ),
      ),
    );
  }

  // 构建节点的连接端口，End 节点只保留输入端口。
  Iterable<Widget> _buildWorkflowNodePorts(
    WorkflowNode node,
    _WorkflowCanvasLayout layout,
  ) sync* {
    if (node.type != WorkflowNodeType.end) {
      yield _buildWorkflowOutputPort(node, layout);
    }
    yield _buildWorkflowInputPort(node, layout);
  }

  // 渲染输出端口，支持点选连线和拖拽连线两种入口。
  Widget _buildWorkflowOutputPort(
    WorkflowNode node,
    _WorkflowCanvasLayout layout,
  ) {
    final outputPort = _WorkflowCanvasLayout.outputPortFor(
      layout.positions[node.id] ?? Offset.zero,
    );
    final canStartConnection =
        !widget.locked &&
        widget.workflow.nodes.any(
          (target) => _workflowCanAddEdge(
            widget.workflow,
            fromNodeId: node.id,
            toNodeId: target.id,
          ),
        );
    return _WorkflowCanvasPort(
      key: ValueKey('workflow-output-port-${node.id}'),
      position: outputPort,
      tone: node.id == _connectingFromNodesId
          ? StudioStatusTone.running
          : StudioStatusTone.ready,
      tooltip: '从 ${_workflowNodeDisplayLabel(widget.workflow, node.id)} 连接',
      onPressed: canStartConnection ? () => _startConnection(node) : null,
      onDragStart: canStartConnection
          ? (globalPosition) => _startDragConnection(
              source: node,
              outputPort: outputPort,
              globalPosition: globalPosition,
            )
          : null,
      onDragUpdate: canStartConnection ? _updateDragConnection : null,
      onDragEnd: canStartConnection
          ? () => _finishDragConnection(layout)
          : null,
    );
  }

  // 渲染输入端口，只有进入连接模式时才允许完成连接。
  Widget _buildWorkflowInputPort(
    WorkflowNode node,
    _WorkflowCanvasLayout layout,
  ) {
    return _WorkflowCanvasPort(
      key: ValueKey('workflow-input-port-${node.id}'),
      position: _WorkflowCanvasLayout.inputPortFor(
        layout.positions[node.id] ?? Offset.zero,
      ),
      tone: _connectingFromNodesId == null
          ? StudioStatusTone.offline
          : StudioStatusTone.warning,
      tooltip: '连接到 ${_workflowNodeDisplayLabel(widget.workflow, node.id)}',
      onPressed: widget.locked || _connectingFromNodesId == null
          ? null
          : () => _completeConnection(node),
    );
  }
}
