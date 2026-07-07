# studio_runtime

`studio_runtime` 是 iOS Assist Studio V2.0 的本地运行时包。

它为 Flutter Desktop Mac App 提供设备连接、Appium 进程、WebDriver 会话、工作流执行、本地证据和本机诊断能力。

## 职责

- 管理 Appium 进程生命周期。
- 建立和关闭 WebDriver 会话。
- 执行 Project DSL 工作流。
- 以受限 `inputMap` 支持子流程读取 `context.inputs.xxx`。
- 保持单设备、串行执行和安全停止边界。
- 写入本地运行事件、截图证据和运行摘要；子流程传参证据只保存字段名和数量。
- 读取本地运行历史和详情，并为 Monitor 提供脱敏事件摘要和关联运行筛选所需的强类型字段；读取历史前会应用本地证据保留策略，保证重启后旧证据不会继续出现在记录页。
- 从本地运行详情派生本地运行报告，提供摘要、问题、时间线、视觉检查、截图胶片、日志统计和平台差异摘要，并可把脱敏 JSON 写入当前运行目录内的 `exports/`。
- 提供受控 AI / MCP-compatible 工具入口：读屏摘要、流程草稿、失败解释、目标建议、Locator 建议、模板修复建议和运行交接；AI 工具只生成草稿或解释，危险动作必须确认且仍交给 Runtime 主命令执行。
- 在 Runtime snapshot 中保留最近 AI 行为审计日志，记录工具、风险、状态和确认状态，不保存截图 base64、完整设备号、本机路径或长 session。
- 管理本地工作流、子流程和设置。
- 管理本地 Target Library，支持坐标、selector、图片、区域和文本目标的受控项目数据。
- 管理图片目标模板资产，目标库只保存项目内相对引用，解析时再读取模板。
- 通过受控 Appium Source 摘要解析 selector 目标，不开放 XPath、CSS、脚本或任意表达式。
- 通过 Appium Source 中的 label / value 精确匹配解析 text 目标；显式开启 Python 视觉增强后，可用 Python OCR provider 作为后续增强。
- 使用最近截图测试图片目标是否可命中，诊断不刷新截图、不启动驱动、不执行点击。
- 在一键连接中自动对齐当前唯一 USB 手机；必要时重新绑定并写回本地项目配置。
- 在创建会话前拦截脱敏或示例设备占位符，防止假设备标识进入 Appium。
- 区分应用受控 Appium 和外部已存在 Appium，避免把未接管的外部驱动误报为已停止。
- 对受控驱动的 WDA 代理瞬时断开执行一次安全恢复，不自动重试签名、证书、USB、隧道或外部驱动问题。
- 将 WDA 构建、签名和会话启动失败拆成结构化诊断，输出短中文原因和下一步。
- 按最大运行条数和最大保留天数滚动清理本地 evidence。
- 输出脱敏的 Runtime snapshot 给 Flutter UI，其中连接失败通过结构化诊断字段提供短原因和下一步。

## 边界

- 不提供自建 Node API。
- 不实现云端同步。
- 不做多用户或多设备调度。
- 不绕过 iOS Developer Mode、证书信任或 WDA 签名限制。
- 不长期暴露完整设备标识、完整 session、账号、证书主体或本机绝对路径。
- AI 不直接点击、不直接启动运行、不绕过 Runtime、不默认上传截图。

## 包入口

Flutter App 应只从 `package:studio_runtime/studio_runtime.dart` 导入运行时能力。

`lib/src/` 下的文件是内部实现分片，按职责拆为模型、依赖探测、Appium 进程、会话管理、设备动作、证据存储、项目命令、执行规划、节点参数、引用校验、视觉守卫和工作流执行。

模型继续按职责拆分：

- `runtime_settings_models.dart`：本机设置、证据保留策略和隐私硬边界。
- `runtime_dependency_models.dart`：本机依赖检查摘要。
- `runtime_run_history_models.dart`：运行历史基础摘要、单日聚合和总汇总。
- `runtime_run_issue_models.dart`：问题分类和关联运行摘要。
- `runtime_run_duration_models.dart`：节点耗时统计、趋势和关联运行摘要。
- `runtime_run_failure_models.dart`：失败聚类和关联运行摘要。
- `runtime_run_event_models.dart`：运行证据事件、视觉判断证据链、子流程传参摘要和脱敏平台摘要字段。
- `runtime_run_trace_models.dart`：节点执行路径和本地截图证据相对引用。
- `runtime_run_analysis_models.dart`：失败分析、详情指标和问题类型归类。
- `runtime_run_detail_models.dart`：从事件流聚合完整运行详情。
- `runtime_run_report_models.dart`：从运行详情派生本地报告、视觉检查、截图胶片、日志摘要、平台摘要、导出结果和脱敏导出 JSON。
- `runtime_execution_state_models.dart`：连接、运行、Appium 来源、快照和执行焦点。
- `runtime_execution_internal_models.dart`：执行器内部 Catch、暂停和子流程目标。
- `runtime_connection_diagnostics.dart`：连接失败分类、短中文摘要、下一步和脱敏详情。
- `device_binding.dart`：当前 USB 手机发现、localNetwork 设备过滤和项目配置写回。

`runtime_models.dart` 只保留入口说明，不承载新增模型。

V4.0 合同层继续按职责拆分：

- `runtime_mobile_driver_models.dart`：跨平台移动设备、资源锁和能力报告模型。
- `runtime_mobile_driver_contracts.dart`：平台中立 `MobileDeviceDriver` 接口和会话 / 心跳 / 截图合同。
- `runtime_android_adb.dart`：Android ADB 设备发现、状态归类、serial 脱敏和 logcat 摘要。
- `runtime_mobile_driver_smoke.dart`：跨平台 driver 冒烟 runner、driver 能力摘要、脱敏报告和本地 evidence 写入。
- `runtime_mobile_driver_adapters.dart`：iOS Appium adapter 包装、Android 安全骨架和 Android UiAutomator2 adapter。
- `runtime_vision_contracts.dart`：Target Resolver、Vision Provider、目标定义和解析结果模型。
- `runtime_vision_providers.dart`：Composite TargetResolver、坐标 provider、区域 provider、selector provider、text source provider、Python OCR text provider、Pyxelator fixture provider、Airtest fixture provider、小尺寸 PNG 模板匹配兜底，以及“视觉增强”开启后的 Pyxelator / Airtest / builtin Python sidecar 解析链。
- `runtime_target_library_models.dart`：Target Library 快照、validator、workflow `targetRef` 引用诊断和脱敏 payload 规则。
- `runtime_target_library_store.dart`：本地目标库 JSON store，无效文件降级为空目标库。
- `runtime_target_asset_store.dart`：本地图片目标模板资产读写、安全相对路径和 PNG 轻量校验。
- `runtime_inspector_models.dart`：Inspector 快照和元素摘要模型。
- `runtime_inspector_source_parser.dart`：Appium source 脱敏解析、元素树摘要和 Source 预览。
- `runtime_inspector_commands.dart`：当前界面检查命令，负责截图、source、资源锁和失败兜底。
- `runtime_ai_tool_models.dart`：AI / MCP-compatible 工具注册表、权限风险、调用请求、门禁决策、调用结果和审计模型。
- `runtime_ai_tool_commands.dart`：Runtime 受控 AI 工具入口，负责读屏摘要、流程草稿、失败解释、目标建议、Locator 建议、模板修复建议和危险动作交接。
- `runtime_python_sidecar.dart`：Python Sidecar 能力探测、Airtest / Pyxelator 包可用性摘要、后端选择、图片模板定位和 OCR 文本定位的短生命周期 Python 视觉 JSON 调用；缺少包或 API 不匹配时只返回结构化不可用结果，不阻断坐标、selector、text source 和内置匹配链路。

依赖探测继续按职责拆分：

- `dependency_probe.dart`：Appium / 本机依赖检查公共契约和探测入口。
- `dependency_command_probe.dart`：本机命令执行、输出裁剪和路径脱敏。
- `dependency_tunnel_probe.dart`：本机隧道进程检查，不启动命令、不请求权限。
- `dependency_wda_prerequisites.dart`：把工具链和隧道状态汇总为会话准备状态。
- `appium_availability_probe.dart`：Appium `/status` 可用性检查。

控制器继续按命令分片：

- `runtime_controller.dart`：Runtime 依赖、快照和广播中心。
- `runtime_appium_commands.dart`：本机环境、Appium 启停、外部驱动识别、设备会话、WDA 瞬断恢复和一键连接重试收口。
- `runtime_device_binding_commands.dart`：当前 USB 手机自动对齐、无效设备占位符拦截、手动重绑和 Runtime 会话配置同步。
- `runtime_device_preview_commands.dart`：设备预览命令路由说明。
- `runtime_device_preview_capture_commands.dart`：设备预览截图。
- `runtime_device_preview_tap_commands.dart`：设备预览点击、双击和长按。
- `runtime_device_preview_gesture_commands.dart`：设备预览滑动和双指缩放。
- `runtime_device_preview_input_commands.dart`：设备预览当前焦点输入和受控主页键。
- `runtime_mobile_driver_adapters.dart`：iOS / Android Appium driver adapter，承载截图、点击、滑动、输入、页面结构、App 生命周期和平台日志能力。
- `runtime_device_preview_helpers.dart`：设备预览共用的会话校验、坐标校验、时长校验、pinch 坐标构造和 actions 释放。
- `runtime_run_commands.dart`：工作流启动、安全停止和暂停收口。
- `runtime_workflow_project_commands.dart`：当前 workflow 保存、复制和重置。
- `runtime_sub_workflow_project_commands.dart`：本地子流程注册、当前流程转子流程和删除。
- `runtime_target_library_commands.dart`：目标新增、坐标目标生成、图片目标模板生成、图片目标试找、删除保护和目标库保存。
- `runtime_settings_project_commands.dart`：本机设置、收藏和证据保留策略。
- `runtime_evidence_project_commands.dart`：运行历史、运行详情、本地报告读取、报告文件导出和截图证据读取。
- `runtime_project_helpers.dart`：流程和子流程副本命名 helper。

证据存储继续按数据路径分片：

- `evidence_store.dart`：证据接口、Noop、Local store 对外委托和保留策略应用。
- `evidence_store_writer.dart`：metadata、events、screenshots 和 finish 写入。
- `evidence_store_history.dart`：运行摘要读取、读前保留策略清理和 Monitor 聚合编排。
- `evidence_store_detail.dart`：单次运行详情、事件解析、子流程传参元数据解析、平台摘要字段解析和截图资产读取。
- `evidence_store_report_export.dart`：单次运行脱敏报告 JSON 写入；导出文件位于该运行目录的 `exports/`，随运行证据生命周期清理。
- `evidence_store_aggregations.dart`：日期趋势、问题分类、失败聚类和节点耗时聚合。
- `evidence_store_helpers.dart`：安全路径、文件名清洗和轻量字段解析。

工作流执行继续按语义分片：

- `runtime_workflow_execution.dart`：工作流主循环、串行推进和 Catch 路由。
- `runtime_workflow_node_execution.dart`：单节点调度、成功和失败焦点收口。
- `runtime_workflow_action_nodes.dart`：Tap、Tap Target、Wait、Swipe、Input 和 Snapshot 动作节点。
- `runtime_workflow_control_nodes.dart`：控制节点路由说明，不承载具体节点实现。
- `runtime_workflow_decision_nodes.dart`：Condition、Visual Branch 和 Wait For Target 判断节点；视觉节点只解析目标和写证据，不直接执行点击。
- `runtime_workflow_flow_nodes.dart`：Catch、Sub Workflow 和 Loop 流程编排节点。
- `runtime_workflow_execution_helpers.dart`：节点查找和短中文运行文案。

## 验证

常规修改后运行：

```sh
fvm dart test
```

V4 真机冒烟入口：

```sh
npm run v4:smoke:full
npm run v4:smoke:full:dry-run
npm run v4:ios-smoke
npm run v4:ios-smoke:full
npm run v4:ios-smoke -- --allow-actions
npm run v4:ios-smoke -- --workflow-basic --allow-actions
npm run v4:android-smoke
npm run v4:android-smoke:full
npm run v4:android-smoke -- --allow-actions
npm run v4:android-smoke -- --workflow-basic --allow-actions
```

`npm run v4:smoke:full` 是最终现场验收入口，会先检查 Appium 平台 driver，做只读前置检查，再顺序执行 iOS 与 Android 的真实 Tap、Swipe、Input 和基础 Project DSL workflow，并在最后生成 full smoke Markdown / JSON、readiness / completion audit 留档。Android 纳入 full smoke 且前置阻断时，会同步生成 `ANDROID_SMOKE_PREFLIGHT` 诊断，供 readiness / acceptance 展示最新 Android 阻断。`npm run v4:ios-smoke:full` 和 `npm run v4:android-smoke:full` 也走同一个编排器，只跳过另一个平台，适合单平台排障。`npm run v4:smoke:full:dry-run` 只展示命令，不执行真实动作。

full smoke 编排器会为每个平台设置步骤超时；超时后会终止子进程并继续生成脱敏汇总，避免现场验证卡死或留下孤儿进程。

不带 `--allow-actions` 时只创建会话、截图并写入本地 evidence；加上后会在当前手机屏幕上执行真实 Tap、Swipe 和 Input。`--workflow-basic` 会把动作冒烟切换为基础 Project DSL workflow，用于验证 DSL、driver 和 evidence 是同一条链路。单平台完整排障优先使用 `npm run v4:ios-smoke:full` 或 `npm run v4:android-smoke:full`，它们会自动准备本机驱动和对应平台前置条件。

Android 单平台 smoke 在驱动不可达、无手机、未授权、离线或多设备时会失败退出，并在输出目录写入 `ANDROID_SMOKE_PREFLIGHT` 脱敏 Markdown / JSON。该文件用于排障和 readiness 索引，不会计作一次真实 Android run。

测试文件按职责拆分：

- `test/runtime_snapshot_test.dart`：Runtime 初始快照和只读摘要。
- `test/runtime_v4_contracts_test.dart`：V4 平台、视觉、Python Sidecar 和 AI 工具合同。
- `test/runtime_ai_tool_test.dart`：Batch 8 AI / MCP Core 权限门禁、危险工具确认、读屏摘要、目标 / Locator 草稿、失败解释、模板修复建议、行为审计和不持久化边界。
- `test/runtime_vision_provider_test.dart`：坐标 / 区域 / selector / text source / Python OCR 解析、Pyxelator fixture、Airtest fixture、Python sidecar JSON 映射、Pyxelator / Airtest / builtin 后端分派、Python 内置后端真实脚本冒烟和 Python 优先 resolver 目标解析。
- `test/runtime_v4_driver_adapter_test.dart`：V4 iOS adapter 包装和 Android 骨架。
- `test/runtime_v4_android_adapter_test.dart`：Android ADB 发现、UiAutomator2 session、截图 / 动作 / 日志和授权阻断。
- `test/runtime_v4_smoke_runner_test.dart`：跨平台 driver 冒烟 evidence、默认跳过动作、基础 workflow 和失败释放兜底。
- `test/runtime_inspector_test.dart`：Inspector source 脱敏解析、当前界面检查、未连接阻断和失败不污染连接态。
- `test/runtime_target_library_test.dart`：目标库 store、图片模板资产 store、图片目标试找、坏文件兜底、缺失 target 诊断、删除保护、坐标 / 区域 / selector 目标点击。
- `test/runtime_workflow_visual_test.dart`：Visual Branch、Wait For Target、Tap Target 的 targetRef 解析、低置信暂停、未找到暂停和视觉节点串行执行边界。
- `test/runtime_sub_workflow_store_test.dart`：子流程注册、转存、删除和引用保护。
- `test/runtime_sub_workflow_reference_test.dart`：子流程引用完整性、自引用和循环引用校验。
- `test/runtime_sub_workflow_guard_test.dart`：控制器对子流程非法引用的保存、注册和执行前拦截。
- `test/runtime_appium_lifecycle_test.dart`：Appium 进程、依赖探测和连接等待。
- `test/runtime_device_binding_test.dart`：当前 USB 手机发现、Wi-Fi 设备过滤、配置写回和绑定后 session 配置同步。
- `test/runtime_project_workflow_test.dart`：workflow 项目命令、本地 workflow store 和运行中写入保护。
- `test/runtime_project_settings_test.dart`：本机设置、隐私硬边界和证据保留策略。
- `test/runtime_project_config_test.dart`：项目配置恢复、子流程恢复和 legacy sequence 导入。
- `test/runtime_workflow_execution_test.dart`：工作流执行、节点语义和运行证据。
- `test/device_session_test.dart`：Appium session、设备连接状态、截图和 Device Preview 归一化手势 / 输入。
- `test/evidence_store_retention_test.dart`：本地 evidence 保留数量和运行历史刷新。
- `test/evidence_store_summary_test.dart`：本地 evidence 摘要、暂停统计和失败聚类。
- `test/evidence_store_duration_test.dart`：节点耗时聚合和趋势。
- `test/evidence_store_detail_test.dart`：运行详情、失败分析、截图证据、安全读取和脱敏报告文件导出。
- `test/support/runtime_test_harness.dart`：fake Appium session server、fake dependency / process / device actions 等跨 Runtime 测试夹具。

涉及 Flutter App 调用链时，还应运行 `apps/studio_mac` 的 widget 测试和全项目静态分析。
