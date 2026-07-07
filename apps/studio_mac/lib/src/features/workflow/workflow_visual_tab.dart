part of '../../studio_mac_workspace.dart';

// Workflow 可视页签，负责节点库、画布主体和画布快捷键绑定。
class _WorkflowVisualTab extends StatelessWidget {
  const _WorkflowVisualTab({
    required this.workflow,
    required this.diagnosticsByNodeId,
    required this.executionFocus,
    required this.selectedNode,
    required this.selectedNodeId,
    required this.selectedNodeIds,
    required this.selectedEdge,
    required this.locked,
    required this.lockReason,
    required this.canvasFocusNode,
    required this.viewportCommand,
    required this.onDeleteSelection,
    required this.onDuplicateSelection,
    required this.onCopySelection,
    required this.onCutSelection,
    required this.onPasteSelection,
    required this.onUndoChange,
    required this.onRedoChange,
    required this.onSelectAllNodes,
    required this.onClearSelection,
    required this.onAutoLayoutShortcut,
    required this.onNudgeSelection,
    required this.onAddNodes,
    required this.onSelectNode,
    required this.onSelectNodes,
    required this.onSelectEdge,
    required this.onInsertNodesOnEdge,
    required this.onRetargetSelectedEdgeSource,
    required this.onRetargetSelectedEdge,
    required this.onMoveNode,
    required this.onMoveNodes,
    required this.onConnectNodes,
    required this.onRemoveEdge,
    required this.onAutoLayout,
  });

  final WorkflowDefinition workflow;
  final Map<String, List<_WorkflowSourceDiagnostic>> diagnosticsByNodeId;
  final RuntimeExecutionFocus executionFocus;
  final WorkflowNode? selectedNode;
  final String? selectedNodeId;
  final Set<String> selectedNodeIds;
  final _WorkflowSelectedEdge? selectedEdge;
  final bool locked;
  final String? lockReason;
  final FocusNode canvasFocusNode;
  final ValueNotifier<_WorkflowCanvasViewportCommand?> viewportCommand;
  final VoidCallback onDeleteSelection;
  final VoidCallback onDuplicateSelection;
  final VoidCallback onCopySelection;
  final VoidCallback onCutSelection;
  final VoidCallback onPasteSelection;
  final VoidCallback onUndoChange;
  final VoidCallback onRedoChange;
  final VoidCallback onSelectAllNodes;
  final VoidCallback onClearSelection;
  final VoidCallback onAutoLayoutShortcut;
  final ValueChanged<Offset> onNudgeSelection;
  final ValueChanged<WorkflowNodeType> onAddNodes;
  final ValueChanged<WorkflowNode> onSelectNode;
  final ValueChanged<Set<String>> onSelectNodes;
  final ValueChanged<_WorkflowSelectedEdge?> onSelectEdge;
  final ValueChanged<WorkflowNodeType> onInsertNodesOnEdge;
  final ValueChanged<String> onRetargetSelectedEdgeSource;
  final ValueChanged<String> onRetargetSelectedEdge;
  final void Function(WorkflowNode node, Offset position) onMoveNode;
  final ValueChanged<Map<String, Offset>> onMoveNodes;
  final void Function(String fromNodeId, String toNodeId) onConnectNodes;
  final ValueChanged<_WorkflowSelectedEdge> onRemoveEdge;
  final VoidCallback onAutoLayout;

  // 渲染可视页签，窄宽度下自动隐藏左侧节点库。
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.delete): onDeleteSelection,
        const SingleActivator(LogicalKeyboardKey.backspace): onDeleteSelection,
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
            onDuplicateSelection,
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
            onCopySelection,
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true):
            onCutSelection,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            onPasteSelection,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
            onUndoChange,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            onRedoChange,
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            onSelectAllNodes,
        const SingleActivator(LogicalKeyboardKey.escape): onClearSelection,
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true, shift: true):
            onAutoLayoutShortcut,
        const SingleActivator(LogicalKeyboardKey.equal, meta: true): () =>
            _sendViewportCommand(_WorkflowCanvasViewportCommand.zoomIn),
        const SingleActivator(
          LogicalKeyboardKey.equal,
          meta: true,
          shift: true,
        ): () =>
            _sendViewportCommand(_WorkflowCanvasViewportCommand.zoomIn),
        const SingleActivator(LogicalKeyboardKey.minus, meta: true): () =>
            _sendViewportCommand(_WorkflowCanvasViewportCommand.zoomOut),
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true): () =>
            _sendViewportCommand(_WorkflowCanvasViewportCommand.reset),
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
            _sendViewportCommand(_WorkflowCanvasViewportCommand.fit),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            onNudgeSelection(const Offset(0, -_workflowCanvasNudgeStep)),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            onNudgeSelection(const Offset(0, _workflowCanvasNudgeStep)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            onNudgeSelection(const Offset(-_workflowCanvasNudgeStep, 0)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            onNudgeSelection(const Offset(_workflowCanvasNudgeStep, 0)),
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): () =>
            onNudgeSelection(const Offset(0, -_workflowCanvasLargeNudgeStep)),
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): () =>
            onNudgeSelection(const Offset(0, _workflowCanvasLargeNudgeStep)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
            onNudgeSelection(const Offset(-_workflowCanvasLargeNudgeStep, 0)),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
            onNudgeSelection(const Offset(_workflowCanvasLargeNudgeStep, 0)),
      },
      child: Focus(
        key: const ValueKey('workflow-canvas-shortcuts'),
        focusNode: canvasFocusNode,
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showPalette = constraints.maxWidth >= 940;
            return Row(
              children: [
                if (showPalette) ...[
                  SizedBox(
                    width: 206,
                    child: _WorkflowNodePalette(
                      selectedNodes: selectedNode,
                      entryNodesId: workflow.entryNodesId,
                      locked: locked,
                      onAddNodes: onAddNodes,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _WorkflowVisualList(
                    workflow: workflow,
                    diagnosticsByNodeId: diagnosticsByNodeId,
                    executionFocus: executionFocus,
                    selectedNodeId: selectedNodeId,
                    selectedNodeIds: selectedNodeIds,
                    selectedEdge: selectedEdge,
                    locked: locked,
                    lockReason: lockReason,
                    viewportCommand: viewportCommand,
                    onSelectNode: onSelectNode,
                    onSelectNodes: onSelectNodes,
                    onSelectEdge: onSelectEdge,
                    onInsertNodesOnEdge: onInsertNodesOnEdge,
                    onRetargetSelectedEdgeSource: onRetargetSelectedEdgeSource,
                    onRetargetSelectedEdge: onRetargetSelectedEdge,
                    onMoveNode: onMoveNode,
                    onMoveNodes: onMoveNodes,
                    onConnectNodes: onConnectNodes,
                    onRemoveEdge: onRemoveEdge,
                    onAutoLayout: onAutoLayout,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 发送视口快捷命令。
  // 先置空再写入，确保连续触发同一命令也能通知画布。
  void _sendViewportCommand(_WorkflowCanvasViewportCommand command) {
    viewportCommand.value = null;
    viewportCommand.value = command;
  }
}
