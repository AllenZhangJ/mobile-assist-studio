# iOS Assist Studio项目文档v1.0

## 0. TL;DR

- 本文档用于快速理解 `iOS Assist Studio` 的总体结构、入口差异、状态机和改动边界。
- 命中“该改 Web 看板还是 CLI”“初始化到底做了什么”“连接问题应该落在哪一层”“新需求应该落在哪个模块”时，先读本文。
- 本文是项目总纲和当前实现真源，不替代代码本身，但优先于零散口头约定。

## 1. Task Router

| 如果任务是... | 先看哪里 | 默认优先改哪里 | 不要直接做什么 |
|---|---|---|---|
| 判断入口差异、初始化语义 | 本文档 | 先判 Web 看板 / CLI 边界 | 直接改某个按钮或脚本 |
| 设备发现、Appium、WDA、证书信任、连接状态 | 本文档 | `legacy/node/src/ios-assist-session.mjs` | 先改点击执行 |
| 看板 UI、按钮行为、状态文案、日志交互 | 本文档 | `legacy/node/src/ios-assist-console.mjs` | 让页面逻辑绕回 CLI 子进程 |
| 工作流画布 MVP、节点属性查看 | 本文档 | `legacy/node/src/ios-assist-console.mjs` | 把前端拖拽布局伪装成会修改运行真值的完整编辑器 |
| 常驻会话上的 A-F 点击、停止、循环 | 本文档 | `legacy/node/src/ios-assist-runner.mjs` | 在多个入口复制点击逻辑 |
| 运行事件、截图证据、失败现场留存 | 本文档 | `legacy/node/src/ios-assist-evidence.mjs` | 把截图长期散落到任意目录 |
| 视觉守卫、已知弹窗识别、挂起/继续 | 本文档 | `legacy/node/src/ios-assist-visual.mjs` / `legacy/node/src/ios-assist-runner.mjs` | 让视觉层绕过运行时直接点击 |
| 工作流 DSL、旧序列兼容、图校验 | 本文档 | `legacy/node/src/ios-assist-workflow.mjs` | 使用任意 JS / eval 表达式 |
| CLI 初始化、CLI 点击前置规则 | 本文档 | `legacy/node/src/ios-coordinate-init.mjs` / `legacy/node/src/ios-coordinate-click.mjs` | 把 CLI 和 Web 看板的初始化混成一个概念 |
| 序列、等待、运行参数 | 本文档 | `config/connected-device.sequence.json` | 在文档里手改真值而不更新配置 |
| 录制、拾点、截图辅助流程 | 本文档 | `legacy/node/src/ios-coordinate-record*.mjs` / `legacy/node/src/ios-coordinate-pick-point.mjs` | 先动主连接器 |

## 2. Source of Truth

- 本文档是项目总体架构、状态边界和当前实现规则的真源。
- 产品方向、UI/UX 定调和未来架构演进分别由专题文档承载，本文只保留当前实现总纲。
- 关键路径：
  - `config/connected-device.sequence.json`：运行真值
  - `legacy/node/src/ios-assist-console.mjs`：Web 看板入口
  - `legacy/node/src/ios-assist-session.mjs`：常驻连接控制器
  - `legacy/node/src/ios-assist-runner.mjs`：常驻点击执行器
  - `legacy/node/src/ios-assist-evidence.mjs`：本地运行证据存储
  - `legacy/node/src/ios-assist-visual.mjs`：轻量视觉分析和已知阻断识别
  - `legacy/node/src/ios-assist-workflow.mjs`：工作流 DSL、旧序列包装和图合法性校验
  - `legacy/node/src/ios-coordinate-init.mjs`：CLI 初始化入口
  - `legacy/node/src/ios-coordinate-click.mjs`：CLI 点击入口
- 根 `README.md` 只负责快速启动和文档入口，不承载实现细节。

专题真源：

- `docs/产品与工程边界v1.0.md`：产品、设备、执行安全、视觉、DSL、隐私、UI/UX 和验证边界
- `docs/三阶段开发计划v1.0.md`：最多三阶段的完整开发计划与验收边界
- `docs/产品定位与旗舰化方向v1.0.md`：产品定调、能力边界、阶段优先级
- `docs/Web控制台UIUX规范v1.0.md`：Web 控制台视觉语言、布局与交互原则
- `docs/视觉状态驱动编排架构路线v1.0.md`：视觉状态驱动、工作流节点、异常拦截与时间轴路线

## 3. Key Paths

- `config/`：连接配置、签名配置、点击序列
- `legacy/node/src/ios-assist-console.mjs`：本地 Web 看板、HTTP API、SSE 日志与状态推送
- `legacy/node/src/ios-assist-session.mjs`：设备发现、Appium 启停、WDA 连接、证书信任等待态
- `legacy/node/src/ios-assist-runner.mjs`：基于常驻 driver 的串行点击执行
- `legacy/node/src/ios-assist-evidence.mjs`：本地 evidence store，负责截图、事件和运行记录的滚动留存
- `legacy/node/src/ios-assist-visual.mjs`：轻量视觉守卫，负责截图元数据校验和已知 iOS 系统弹窗识别
- `legacy/node/src/ios-assist-workflow.mjs`：自定义工作流 DSL，负责节点校验、旧序列映射、闭环检测和受限上下文表达式
- `legacy/node/src/ios-coordinate-*.mjs`：CLI 及辅助工具
- `recordings/`：本地运行证据默认目录，默认不进入版本管理
- `docs/`：长期维护文档真源

## 4. Boundary

- Web 看板负责：连接控制、状态展示、任务触发、日志聚合。
- 常驻连接器负责：设备发现、Appium、WDA、WebDriver 会话、证书信任等待逻辑。
- 常驻执行器负责：A-F 串行点击、循环、停止控制。
- Evidence store 负责：运行事件、截图快照、失败现场摘要和滚动清理。
- Visual guard 负责：动作前后截图分析、已知阻断态识别、向运行时返回挂起建议。
- Workflow layer 负责：把旧 `sequence` 包装为标准节点树，校验节点图和表达式安全边界。
- CLI 负责：保留传统脚本入口和单次执行逻辑，不作为看板内部实现依赖。
- 配置文件负责：序列、等待、运行参数、连接能力真值。

## 5. Current Architecture Snapshot

项目现在有两条入口：

- `Web 看板`
  - 推荐入口
  - 初始化时完成设备发现、Appium 启动、WDA 预热和 WebDriver 常驻连接
  - 连接成功后，点击任务直接发送到常驻会话

- `CLI`
  - 兼容保留
  - 仍然遵循“先 init，再 click”的旧规则
  - 每次执行走独立检查和独立连接链路

当前 Web 看板不是 CLI 的可视化壳，而是常驻连接模式。

## 6. State Model

看板主状态：

- `disconnected`
- `initializing`
- `connecting`
- `waitingForDeveloperTrust`
- `connected`
- `disconnecting`
- `error`

运行状态：

- `idle`
- `running`
- `paused`
- `stopping`

设计意图：

- 连接状态和运行状态分离维护
- 证书信任问题必须在连接阶段显式暴露
- 点击任务只在 `connected` 状态下允许进入
- 视觉守卫发现高置信阻断态时，运行状态进入 `paused`
- `paused` 状态下只能继续任务或停止任务，不能重连或断开

## 7. Entry Semantics

### 7.1 Web 看板的“初始化并连接”

这是一个完整连接动作，不只是初始化标记。

它的职责包括：

- 发现 USB iPhone
- 更新当前设备初始化信息
- 启动或复用 Appium
- 构建、安装并启动 WDA
- 建立 WebDriver 会话
- 保持连接常驻
- Appium 状态探测必须有超时，不允许卡死 Web 状态接口
- 断开连接请求必须能取消正在等待中的 Appium 启动探测

如果 iPhone 尚未信任开发者证书：

- 看板进入 `waitingForDeveloperTrust`
- 后台在限定次数内自动重试
- 看板状态应展示当前重试次数和重试上限
- 用户在重试窗口内完成系统信任后，看板可自动进入 `connected`
- 如果超过重试上限仍未信任，看板进入可操作错误态，用户信任后点击“重新连接”

### 7.2 CLI 的 `init:connected`

CLI 初始化只做设备发现和配置更新。

它负责：

- 从 usbmux 发现当前第一台 USB 设备
- 更新当前配置中的设备标记

它不负责：

- 启动 Appium
- 启动 WDA
- 建立 WebDriver 会话
- 执行点击

### 7.3 CLI 的 `click:connected`

CLI 点击保留旧规则：

- 没有成功初始化就直接失败
- 初始化过但当前设备不在 usbmux 中也直接失败
- 这些失败发生时，不启动 Appium，不执行点击

## 8. Sequence Rules

当前点击链路的核心约束：

- 点击作用于 iPhone 当前前台屏幕
- 序列按配置定义的顺序执行
- 多轮时严格串行：`ABCDEF -> ABCDEF`
- 不允许并行点击
- 停止任务时在安全边界停下，不做粗暴中断
- 视觉守卫可在 Tap 前暂停主流程；暂停发生在点击前，避免盲点点击
- 用户在 iPhone 上处理阻断后，可从 Web 看板继续任务
- Tap 前视觉守卫连续 2 次要求暂停后，用户再次继续会被视为人工确认，运行时记录 warning 后继续该 Tap
- 每次点击动作结束后必须释放 WebDriver pointer actions；动作失败时也要尽力释放，避免残留触控状态影响后续执行

Web 看板和 CLI 都应遵守这些规则。

## 9. Evidence And Retention

Web 看板会把关键运行证据沉淀到本机默认 evidence 目录。

证据类型包括：

- 结构化运行事件
- 手动截图
- 连接后截图
- 动作前截图
- 动作后截图
- 视觉分析结果
- 失败现场截图
- 运行完成或异常结束摘要

留存原则：

- 只保存在本机。
- 默认目录不进入版本管理。
- 证据路径对外展示时使用相对路径。
- 事件日志不重复写入截图的大体积 base64 内容。
- 视觉分析只保存规则命中、置信度、决策和截图引用，不保存完整 pageSource。
- 运行中的截图和视觉采集在超时后仍需等待底层 WDA 命令结算或硬上限释放，避免证据采集和后续 Tap 并发抢占同一个 WebDriver 通道。
- 默认保留最近 50 条记录或最近 24 小时内记录。
- 文档和 UI 不长期暴露完整设备标识、本机绝对路径、账号或证书主体。

## 10. Configuration Rules

配置真值集中在 `config/connected-device.sequence.json`。

本文档只描述规则，不复写具体私有值。

配置层承载的信息类型包括：

- 当前设备标记
- Appium / WDA 能力
- 运行参数
- A-F 序列与等待
- 可选工作流节点树

工作流兼容规则：

- 旧 `sequence` 仍然有效，并会自动映射为 `Tap` / `Wait` 节点树。
- 新 `workflow` 使用项目内自定义 DSL。
- 当前 runner 可直接执行旧 `sequence`、线性 Tap / Wait workflow，以及包含 `Snapshot`、`Visual_Branch`、`If_Else`、`Catch` 的基础节点图。
- `Catch` 支持显式 `onError` 分支：节点失败且声明 `onError` 时，运行时记录已处理错误并跳转到对应 Catch/恢复节点；未声明 `onError` 的异常仍会让任务失败退出。
- `Sub_Workflow` 先保留节点类型和 hook 边界，后续再扩展完整子流程调度。
- 条件表达式只允许读取 `context.xxx` 字段，右值允许字面量或 `context.xxx`，不允许任意 JS。
- `Tap`、`Wait`、`Snapshot` 等节点参数也只允许字面量或 `context.xxx` 字段读取，运行时解析后再执行。
- `Visual_Branch` 在无可靠判断结果或低置信度时默认进入挂起态，人工确认后才允许继续到后续分支。
- workflow 图必须有合法入口、无重复节点、引用存在、无闭环，且所有节点可从入口到达。
- Web 控制台保存或清除 workflow 时会进入短暂写入态；写入期间后端拒绝并发写入和任务启动。
- 看板摘要会区分 workflow 是否可运行，以及是否是线性图；非线性图不再被误判为不可执行。
- 第一批节点类型保持为 `Tap`、`Wait`、`Snapshot`、`Visual_Branch`、`If_Else`、`Catch`、`Sub_Workflow`。
- 离线 validator 接受合法非线性节点图；线性化状态只用于摘要展示，不代表配置是否可运行。
- 旧 click CLI 兼容入口优先读取 workflow；只能执行线性 `Tap` / `Wait` workflow，非线性图应使用 Web 控制台 runner。

文档维护原则：

- 说明“哪些字段负责什么”
- 不在文档中长期复制具体私有值
- 若某个等待时间或流程是业务关键约束，可在文档描述规则，但仍以配置文件为最终真值

## 11. Web Dashboard Contract

看板当前承担的用户能力：

- 初始化并连接
- 断开连接
- 重新连接
- 测试 1 轮
- 执行 N 轮
- 停止任务
- 挂起后继续任务
- 手动分析当前画面
- 查看、复制、清除诊断日志
- 查看当前序列摘要和连接摘要
- 查看工作流摘要和当前线性可执行状态
- 查看工作流画布、节点类型、节点参数和节点出口
- 在前端临时拖拽整理节点布局；该布局不写回配置，不改变执行真值
- 加载、校验、保存和清除当前 workflow JSON
- 查看最近截图、最近点击、最近错误和视觉守卫摘要
- 查看失败热力图，并可通过只读分析接口获取失败坐标 / 失败节点聚合结果
- 将关键截图和运行事件保存在本机 evidence 目录
- 服务关闭时主动结束 SSE 日志流和 HTTP 长连接
- 配置异常时状态接口降级返回结构化错误，看板保持可打开和可诊断
- 公共 API 错误信息必须脱敏，不向前端暴露本机绝对路径
- Web 实时日志必须统一脱敏，不向前端暴露本机绝对路径或设备标识
- Workflow API 在配置异常时只返回结构化校验结果，不回传原始无效 workflow，配置面板保持可诊断
- USB 设备探测超时时状态接口降级返回，并通过 single-flight 与冷却后重试避免刷新风暴堆积底层探针或永久挂死
- 设备初始化和 workflow 保存写配置时必须原子写入，避免进程中断造成配置半写

看板文档应优先描述：

- 状态机
- 交互意图
- 按钮语义
- 错误流
- 视觉守卫的置信度、决策和人工介入边界
- 工作流配置面板仍是当前唯一写入 workflow 子树的编辑入口；画布拖拽只整理前端视图，不承载设备、证书、账号等私密配置
- workflow 保存前必须经过 DSL validator 和规范化，只持久化当前节点类型白名单字段，丢弃额外字段
- 连接初始化、WDA 连接、等待证书信任、断开连接和任务运行期间，后端必须拒绝 workflow 写入
- 完整画布编辑、节点新增删除的可视化交互仍属于后续阶段

不应在文档中堆积页面样式细节或代码片段。

## 12. CLI Contract

CLI 当前承担的用户能力：

- 初始化连接设备
- 单次或多次点击
- `dry-run`
- 录制坐标
- 单点拾取
- `step` / `batch` 两种执行模式

CLI 文档关注点：

- 前置条件
- 参数语义
- 与 Web 看板的职责差异

## 13. Common Error Classes

项目当前需要显式对待的错误类型包括：

- 未初始化
- 当前 USB/usbmux 不可见
- Appium 未就绪
- WDA 启动失败
- iPhone 未信任开发者证书
- 会话已丢失

文档中应优先描述：

- 这类错误属于哪一层
- 应该先看哪个模块
- 修复时不要误改到哪一层

## 13. Change Playbooks

### 13.1 新增连接阶段能力

例如：

- 新的预检
- 新的证书处理
- 新的重连策略

默认落点：

- `legacy/node/src/ios-assist-session.mjs`

同步要求：

- 更新本文档的状态机或连接职责说明

### 13.2 新增点击行为

例如：

- 新的执行模式
- 新的停止边界
- 新的进度反馈

默认落点：

- `legacy/node/src/ios-assist-runner.mjs`

同步要求：

- 更新本文档的执行规则和入口边界

### 13.3 新增看板交互

例如：

- 新按钮
- 新状态提示
- 新日志筛选

默认落点：

- `legacy/node/src/ios-assist-console.mjs`

同步要求：

- 更新本文档的 Dashboard Contract

### 13.4 修改运行真值

例如：

- 坐标
- 等待时间
- 默认 loops

默认落点：

- `config/connected-device.sequence.json`

同步要求：

- 如果这是重要规则变化，更新本文档的规则描述
- 如果只是具体数值变动，不在文档里重复记录私有值

## 14. Documentation Rules

- 文档优先服务 AI 和后续维护者的快速决策。
- 文档优先写边界、职责、状态、落点、规则。
- 文档不默认承载具体代码片段。
- 文档不写隐私信息，不写绝对路径，不写账号、证书主体等私有数据。
- 文档与实现不一致时，应优先修正文档和真值关系。
