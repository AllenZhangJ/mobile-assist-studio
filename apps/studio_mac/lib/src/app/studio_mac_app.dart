part of '../studio_mac_workspace.dart';

// Flutter Mac App 根组件，负责注入主题和运行时工厂。
class StudioMacApp extends StatelessWidget {
  const StudioMacApp({
    super.key,
    this.controllerFactory,
    this.previewScreenshot,
  });

  final StudioRuntimeController Function()? controllerFactory;
  final StudioRuntimeSnapshot? previewScreenshot;

  // 构建应用外壳，保持入口只依赖 StudioShell。
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iOS 辅助工作台',
      theme: StudioTheme.dark(),
      home: StudioShell(
        controllerFactory: controllerFactory,
        previewScreenshot: previewScreenshot,
      ),
    );
  }
}
