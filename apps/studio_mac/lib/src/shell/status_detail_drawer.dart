part of '../studio_mac_workspace.dart';

// 状态胶囊按钮，负责把顶部摘要状态变成可点击入口。
class _StatusChipButton extends StatelessWidget {
  const _StatusChipButton({
    required this.controlKey,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final Key controlKey;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  // 渲染一个紧凑的胶囊按钮。
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: controlKey,
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: child,
      ),
    );
  }
}

enum _StatusDetailFocus { device, driver, workflow, run }

// 打开状态详情抽屉，详情只读展示当前快照。
Future<void> _openStatusDetailDrawer(
  BuildContext context,
  StudioRuntimeSnapshot snapshot,
  _StatusDetailFocus focus,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭状态',
    barrierColor: Colors.black.withValues(alpha: 0.42),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: _StatusDetailDrawer(snapshot: snapshot, focus: focus),
      );
    },
    transitionDuration: const Duration(milliseconds: 160),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
  );
}

// 状态详情抽屉，按当前焦点优先展示设备、驱动、流程或运行状态。
class _StatusDetailDrawer extends StatelessWidget {
  const _StatusDetailDrawer({required this.snapshot, required this.focus});

  final StudioRuntimeSnapshot snapshot;
  final _StatusDetailFocus focus;

  // 渲染状态详情抽屉，细节来自 Runtime 快照派生结果。
  @override
  Widget build(BuildContext context) {
    final sections = _statusDetailSections(snapshot, focus);
    final primary = sections.first;
    return Material(
      color: StudioColors.panel,
      child: SizedBox(
        key: const ValueKey('status-detail-drawer'),
        width: 420,
        height: double.infinity,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '状态详情',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  primary.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StudioColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(label: primary.status, tone: primary.tone),
                    StatusPill(
                      label: _runStatusLabel(snapshot.runStatus),
                      tone: _toneForLiveRunStatus(snapshot.runStatus),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    key: const ValueKey('status-detail-scroll'),
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      return _StatusDetailSectionCard(section: section);
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemCount: sections.length,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 状态详情分组，承载抽屉中一个状态卡所需的文案和字段。
class _StatusDetailSection {
  const _StatusDetailSection({
    required this.title,
    required this.status,
    required this.summary,
    required this.nextStep,
    required this.tone,
    required this.icon,
    required this.fields,
  });

  final String title;
  final String status;
  final String summary;
  final String nextStep;
  final StudioStatusTone tone;
  final IconData icon;
  final List<_StatusDetailField> fields;
}

// 状态详情字段，保持 label/value 的脱敏展示形式。
class _StatusDetailField {
  const _StatusDetailField(this.label, this.value);

  final String label;
  final String value;
}

// 状态详情卡片，展示一个状态分组和下一步动作。
class _StatusDetailSectionCard extends StatelessWidget {
  const _StatusDetailSectionCard({required this.section});

  final _StatusDetailSection section;

  // 渲染状态分组卡片，字段过长时由内部 DrawerField 处理省略。
  @override
  Widget build(BuildContext context) {
    return _ToneBorderSurface(
      tone: section.tone,
      padding: const EdgeInsets.all(14),
      borderAlpha: 0.42,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, size: 18, color: _colorForTone(section.tone)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: section.status, tone: section.tone),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            section.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, height: 1.35),
          ),
          const SizedBox(height: 10),
          _DrawerField(label: '下一步', value: section.nextStep),
          for (final field in section.fields)
            _DrawerField(label: field.label, value: field.value),
        ],
      ),
    );
  }
}
