# workflow_dsl

`workflow_dsl` 是 iOS Assist Studio V2.0 的 Project DSL 模型与校验包。

Flutter UI、Dart Runtime、模板导入、Source View、Visual Canvas 和本地存储都应使用同一套 DSL 定义。

## 职责

- 定义 `WorkflowDefinition`、`WorkflowNode` 和节点类型。
- 支持 A-F 基础模板。
- 支持 legacy sequence 导入为 Project DSL。
- 支持 JSON 序列化和反序列化。
- 校验节点引用、入口 Start、End 终止、参数、分支数量和可执行边界。
- 校验安全表达式，只允许读取 `context.xxx`。
- 校验 Sub Workflow `inputMap`，只允许参数名映射到 `context.xxx`。
- 保存 `visual.position` 等仅用于画布展示的元数据。

## 节点类型

当前 DSL 覆盖：

- Start
- Tap
- Wait
- Swipe
- Input
- Snapshot
- Condition
- Visual Branch
- Loop
- Catch
- Sub Workflow
- End

## 边界

- 不执行工作流。
- 不连接设备。
- 不调用 Appium / WDA。
- 不读写本地文件。
- 不开放任意 JavaScript、Python 或用户脚本。
- 不把 `visual.position` 作为运行语义。

执行语义由 `studio_runtime` 负责。

## 包入口

使用：

```dart
import 'package:workflow_dsl/workflow_dsl.dart';
```

`lib/src/` 下按职责拆分：

- `workflow_models.dart`：节点类型、节点、画布位置和工作流定义。
- `workflow_json.dart`：Project DSL JSON 与旧 sequence 解析 helper。
- `workflow_templates.dart`：A-F 基础模板和 legacy sequence 导入。
- `workflow_validation.dart`：表达式白名单、入口结构、引用和可达性校验。
- `workflow_validation_node_parameters.dart`：按节点类型校验参数、分支数量和可执行边界。

`workflow_dsl.dart` 只作为公共入口和 part 汇总，不承载具体实现。

## 验证

```sh
fvm dart test
```

测试按职责拆分：

- `workflow_templates_test.dart`：A-F 模板和 legacy sequence 导入。
- `workflow_json_test.dart`：Project DSL JSON、视觉元数据和未知节点类型。
- `workflow_validator_structure_test.dart`：图结构、入口/终止节点、缺失引用、自引用和视觉位置完整性。
- `workflow_validator_expressions_test.dart`：安全表达式和 Sub Workflow `inputMap`。
- `workflow_validator_visual_test.dart`：Visual Branch 置信度和分支边界。
- `workflow_validator_control_nodes_test.dart`：Catch、Sub Workflow 和 Loop。
- `workflow_validator_action_nodes_test.dart`：Tap / Wait / Swipe / Input / Snapshot 动作节点参数。
