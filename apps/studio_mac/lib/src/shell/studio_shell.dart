part of '../studio_mac_workspace.dart';

// 主框架组件，负责连接 Runtime、全局快捷键和 L1-L6 页面编排。
class StudioShell extends StatefulWidget {
  const StudioShell({
    super.key,
    this.controllerFactory,
    this.previewScreenshot,
  });

  final StudioRuntimeController Function()? controllerFactory;
  final StudioRuntimeSnapshot? previewScreenshot;

  // 创建 Shell 状态，集中管理主入口生命周期。
  @override
  State<StudioShell> createState() => _StudioShellState();
}

// Shell 状态机，负责快照订阅、导航和全局抽屉。
class _StudioShellState extends State<StudioShell> {
  late final StudioRuntimeController _controller;
  late StudioRuntimeSnapshot _snapshot;
  StreamSubscription<StudioRuntimeSnapshot>? _snapshotSubscription;
  int _selectedIndex = 0;
  bool _commandCenterOpen = false;

  static const _items = <_NavItem>[
    _NavItem('总览', '总览', Icons.dashboard_outlined),
    _NavItem('设备', '设备', Icons.phone_iphone_outlined),
    _NavItem('录制', '录制', Icons.radio_button_checked),
    _NavItem('流程', '流程', Icons.account_tree_outlined),
    _NavItem('运行', '运行', Icons.play_circle_outline),
    _NavItem('记录', '记录', Icons.monitor_heart_outlined),
  ];

  // 初始化运行时控制器并订阅本机快照。
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _controller = _createRuntimeController();
    final previewScreenshot = widget.previewScreenshot;
    _snapshot = previewScreenshot ?? _controller.snapshot;
    if (previewScreenshot == null) {
      _snapshotSubscription = _controller.snapshots.listen((snapshot) {
        if (mounted) {
          setState(() => _snapshot = snapshot);
        }
      });
      unawaited(_controller.refreshRunHistory());
    }
  }

  // 创建真实或测试注入的 Runtime，配置缺失时降级到空控制器。
  StudioRuntimeController _createRuntimeController() {
    final injectedController = widget.controllerFactory?.call();
    if (injectedController != null) return injectedController;

    try {
      final config = _discoverStudioProjectConfig();
      return StudioRuntimeController.fromProjectConfig(config);
    } on Object catch (error) {
      return StudioRuntimeController(
        dependencyChecker: _ProjectConfigMissingDependencyChecker(error),
      );
    }
  }

  // 从常见启动位置向上查找项目配置。
  // 双击应用时当前目录可能不是项目目录，因此额外从可执行文件位置查找。
  StudioProjectConfig _discoverStudioProjectConfig() {
    return StudioProjectConfig.discoverFrom(
      startDirectories: _projectConfigStartDirectories(),
    );
  }

  // 生成项目配置查找起点。
  // 候选只用于本机定位，不进入 UI 展示，避免泄露完整路径。
  List<Directory> _projectConfigStartDirectories() {
    final starts = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
      ..._scriptStartDirectories(),
      ..._environmentStartDirectories(),
      ..._homeWorkspaceFallbackDirectories(),
    ];
    final visited = <String>{};
    return starts
        .where((directory) {
          return visited.add(directory.absolute.path);
        })
        .toList(growable: false);
  }

  // 尝试从脚本 URI 提供的路径向上找项目。
  // AOT 或打包运行时该路径可能不可用，因此失败时直接忽略。
  List<Directory> _scriptStartDirectories() {
    final script = Platform.script;
    if (!script.isScheme('file')) return const <Directory>[];
    try {
      return [File(script.toFilePath()).parent];
    } on Object {
      return const <Directory>[];
    }
  }

  // 读取常见环境变量中的项目起点。
  // 这些变量便于本机调试和后续打包，不作为用户必填项。
  List<Directory> _environmentStartDirectories() {
    const keys = [
      'IOS_ASSIST_STUDIO_ROOT',
      'STUDIO_PROJECT_ROOT',
      'INIT_CWD',
      'PWD',
    ];
    return keys
        .map((key) => Platform.environment[key])
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .map((value) => Directory(value))
        .toList(growable: false);
  }

  // 开发期兜底查找 Home 下常见工作区名。
  // 这只用于定位本机项目，不在界面、日志或文档示例中展示绝对路径。
  List<Directory> _homeWorkspaceFallbackDirectories() {
    final home = Platform.environment['HOME'];
    if (home == null || home.trim().isEmpty) return const <Directory>[];
    return [
      Directory('$home/Documents/Codex/ios-assist-studio'),
      Directory('$home/Documents/ios-assist-studio'),
    ];
  }

  // 释放快捷键、快照订阅和 Runtime 资源。
  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    unawaited(_snapshotSubscription?.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  // 处理全局命令中心快捷键。
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyK) return false;
    final keyboard = HardwareKeyboard.instance;
    if (!keyboard.isMetaPressed && !keyboard.isControlPressed) return false;
    if (mounted) {
      _openCommandCenter();
    }
    return true;
  }

  // 切换一级导航页，所有 Shell 内部入口统一走这里修改索引。
  void _selectNavIndex(int index) {
    setState(() => _selectedIndex = index);
  }

  // 渲染工作站主布局：顶部状态、侧栏、工作区和底部控制台。
  @override
  Widget build(BuildContext context) {
    final selected = _items[_selectedIndex];
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: StudioColors.background),
        child: Column(
          children: [
            _TopStatusBar(
              snapshot: _snapshot,
              onOpenCommandCenter: _openCommandCenter,
            ),
            Expanded(
              child: Row(
                children: [
                  _SideNav(
                    selectedIndex: _selectedIndex,
                    items: _items,
                    onSelect: _selectNavIndex,
                    onOpenSettings: _openSettingsDrawer,
                  ),
                  Expanded(
                    child: _Workspace(
                      title: selected.label,
                      snapshot: _snapshot,
                      controller: _controller,
                      selectedIndex: _selectedIndex,
                      onNavigate: _selectNavIndex,
                    ),
                  ),
                ],
              ),
            ),
            _BottomConsole(snapshot: _snapshot),
          ],
        ),
      ),
    );
  }

  // 打开命令中心，并避免重复弹出。
  void _openCommandCenter() {
    if (_commandCenterOpen) return;
    _commandCenterOpen = true;
    unawaited(
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '关闭命令',
        barrierColor: Colors.black.withValues(alpha: 0.52),
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Center(
            child: _CommandCenterDialog(commands: _commandCenterCommands()),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          );
        },
      ).whenComplete(() => _commandCenterOpen = false),
    );
  }

  // 打开设置抽屉，设置更新仍由 Runtime 统一保存。
  void _openSettingsDrawer() {
    unawaited(
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '关闭设置',
        barrierColor: Colors.black.withValues(alpha: 0.42),
        transitionDuration: const Duration(milliseconds: 160),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: _SettingsDrawer(
              snapshot: _snapshot,
              controller: _controller,
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: child,
          );
        },
      ),
    );
  }
}

// 项目配置缺失时的本机检查兜底。
// 它只暴露短中文原因，不把本机绝对路径写入 UI。
class _ProjectConfigMissingDependencyChecker implements LocalDependencyChecker {
  const _ProjectConfigMissingDependencyChecker(this.error);

  final Object error;

  /// 返回项目配置缺失报告。
  /// 用户下一步是从项目目录启动，或配置项目根目录。
  @override
  Future<LocalDependencyReport> check({
    required AppiumProcessConfig appiumProcess,
  }) async {
    final check = _projectConfigCheckFor(error);
    return LocalDependencyReport(
      checks: [check],
      checkedAt: DateTime.now(),
      message: '项目配置未就绪。',
    );
  }
}

// 将项目配置发现异常转成用户可操作的短提示。
LocalDependencyCheck _projectConfigCheckFor(Object error) {
  if (error case final StudioProjectConfigDiscoveryException discoveryError) {
    return LocalDependencyCheck(
      id: 'project-config',
      label: '项目配置',
      status: LocalDependencyStatus.error,
      summary: discoveryError.summary,
      nextStep: discoveryError.nextStep,
      detail: _projectConfigDetailFor(discoveryError),
    );
  }
  return const LocalDependencyCheck(
    id: 'project-config',
    label: '项目配置',
    status: LocalDependencyStatus.error,
    summary: '未找到项目配置。',
    nextStep: '请从项目目录启动，或设置项目根目录。',
  );
}

// 只在配置不可读时补充沙盒/权限方向，不暴露路径。
String? _projectConfigDetailFor(StudioProjectConfigDiscoveryException error) {
  if (error.reason != StudioProjectConfigDiscoveryReason.notReadable) {
    return null;
  }
  return '可能是沙盒或文件权限限制。';
}
