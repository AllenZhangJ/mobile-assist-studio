part of '../../studio_mac_workspace.dart';

// 录制证据预览组件，负责截图 reveal 和本地内存画面展示。
// 该组件不持久化截图，也不把截图写入 Project DSL。

// 证据预览占位，默认只展示绑定状态，用户主动操作后才显示截图。
class _RecorderEvidencePreview extends StatefulWidget {
  const _RecorderEvidencePreview({required this.action});

  final _RecordedActions action;

  // 创建证据预览状态，用于控制截图是否主动显示。
  @override
  State<_RecorderEvidencePreview> createState() =>
      _RecorderEvidencePreviewState();
}

// 证据预览状态，只保存用户是否展开截图。
class _RecorderEvidencePreviewState extends State<_RecorderEvidencePreview> {
  bool _revealed = false;

  // 渲染本地预览线索，当前阶段不持久化截图画面。
  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final evidenceImage = _decodeScreenshot(action.evidence.imageBase64);
    final canReveal = action.evidence.hasImage && evidenceImage != null;
    return Container(
      height: 168,
      decoration: BoxDecoration(
        color: const Color(0xFF030609),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: _revealed && canReveal
                  ? Image.memory(
                      evidenceImage,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    )
                  : Text(
                      canReveal ? '已绑定${action.evidenceSummary}' : '暂无截图证据',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: StudioColors.muted),
                    ),
            ),
          ),
          const Divider(color: StudioColors.border, height: 1),
          SizedBox(
            height: 42,
            child: Center(
              child: TextButton.icon(
                key: const ValueKey('recorder-evidence-reveal'),
                onPressed: canReveal
                    ? () => setState(() => _revealed = !_revealed)
                    : null,
                icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
                label: Text(_revealed ? '隐藏截图' : '显示截图'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
