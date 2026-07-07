# studio_design_system

`studio_design_system` 是 iOS Assist Studio V2.0 的 Flutter 视觉基础包。

它提供 Tech Noir Enterprise Workstation 风格下的颜色、主题和基础工作台组件。

## 职责

- 提供 `StudioColors` 统一色板。
- 提供 `StudioTheme.dark()` 暗色主题。
- 提供 `StudioStatusTone` 状态语义。
- 提供 `StatusPill` 状态胶囊。
- 提供 `StudioSurface` 一级内容面板。
- 提供 `StudioInsetSurface` 二级内嵌信息块。
- 提供 `WorkspacePanel` 工作区面板容器。

## 设计边界

- 面向本地 Mac 工作站 UI。
- 文案由业务页面提供，本包不承载业务状态判断。
- 不调用 Runtime。
- 不连接设备。
- 不保存设置或运行数据。
- 不承载业务文案、设备状态或 workflow 状态判断。

## 包入口

使用：

```dart
import 'package:studio_design_system/studio_design_system.dart';
```

## 验证

```sh
fvm flutter test
```

测试覆盖基础组件渲染和设计系统导出能力。
