part of '../../studio_mac_workspace.dart';

// Workflow Source 编辑视图，负责 DSL 文本编辑和保存入口。
class _WorkflowSourceView extends StatelessWidget {
  const _WorkflowSourceView({
    required this.controller,
    required this.draft,
    required this.dirty,
    required this.saving,
    required this.locked,
    required this.onReset,
    required this.onSave,
  });

  final TextEditingController controller;
  final _WorkflowSourceDraft draft;
  final bool dirty;
  final bool saving;
  final bool locked;
  final VoidCallback onReset;
  final VoidCallback? onSave;

  // 渲染 Source 编辑区、保存入口和源码诊断列表。
  @override
  Widget build(BuildContext context) {
    final canSave =
        dirty && !saving && !locked && draft.workflow != null && draft.isValid;
    return Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(
                  label: draft.statusLabel,
                  tone: draft.isValid
                      ? StudioStatusTone.ready
                      : StudioStatusTone.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    locked
                        ? '运行中流程已锁定。'
                        : dirty
                        ? '草稿保存后生效。'
                        : '源码已同步。',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StudioColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: dirty && !saving ? onReset : null,
                    icon: const Icon(Icons.restore_outlined, size: 18),
                    label: const Text('重置'),
                  ),
                  FilledButton.icon(
                    key: const ValueKey('workflow-source-save'),
                    onPressed: canSave ? onSave : null,
                    icon: saving
                        ? const Icon(Icons.hourglass_top_outlined, size: 18)
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF030609),
                    border: Border.all(color: StudioColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    key: const ValueKey('workflow-source-editor'),
                    controller: controller,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    keyboardType: TextInputType.multiline,
                    enabled: !saving,
                    style: const TextStyle(
                      color: StudioColors.text,
                      fontFamily: 'Menlo',
                      fontSize: 12,
                      height: 1.35,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
              if (draft.message != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    draft.message!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: draft.isValid
                          ? StudioColors.muted
                          : StudioColors.amber,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (draft.diagnostics.isNotEmpty) ...[
                const SizedBox(height: 10),
                Flexible(
                  child: _WorkflowSourceDiagnostics(
                    diagnostics: draft.diagnostics,
                    onSelect: (diagnostic) =>
                        _selectWorkflowSourceDiagnostic(controller, diagnostic),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
