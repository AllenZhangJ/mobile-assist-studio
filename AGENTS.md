# AGENTS

本文件是 `iOS Assist Studio` 的本地协作规则，用于帮助 Codex、其他 AI 工具和后续维护者稳定进入项目。

它不替代系统级指令，也不替代 `docs/` 真源。进入本项目后，应把本文件作为项目级执行约束。

## 读取顺序

处理本项目任务时，默认按以下顺序读取：

1. `AI_PROJECT_CONTEXT.md`
2. `README.md`
3. `docs/README.md`
4. `docs/iOS Assist Studio项目文档v1.0.md`
5. V4.0 融合任务先读 `docs/V4.0-PRD-Mobile-Automation-Workstation.md`、`docs/V4.0-Architecture-Integrated-Mobile-Workstation.md`、`docs/V4.0-Open-Source-Integration-Plan.md`、`docs/V4.0-Development-Roadmap.md`、`docs/V4.0-Legacy-Node-Exit-Plan.md`、`docs/decisions/ADR-002-v4-open-source-fusion-and-node-exit.md`
6. V2.0 产品任务先读 `docs/V2.0-PRD-Enterprise-Flagship.md`、`docs/V2.0-IA-Information-Architecture.md`、`docs/V2.0-UX-Spec-Enterprise-Console.md`
7. V2.0 Flutter / Monorepo / 迁移任务先读 `docs/V2.0-Flutter-Desktop-Architecture.md`、`docs/V2.0-Monorepo-Engineering-Plan.md`、`docs/V2.0-Migration-Plan-Node-Web-to-Flutter.md`、`docs/V2.0-Development-Plan.md`
8. 当前任务对应的专题文档
9. 相关 `apps/`、`packages/`、`legacy/node/src/`、`config/` 和测试文件

不要跳过项目上下文和专题文档直接改代码。

## 改动落点判断

先判断任务归属，再动手：

| 任务归属 | 默认落点 |
|---|---|
| V4.0 产品定位、双平台闭环、功能清单和非目标 | `docs/V4.0-PRD-Mobile-Automation-Workstation.md` |
| V4.0 Flutter / Dart / Python / Appium 融合架构 | `docs/V4.0-Architecture-Integrated-Mobile-Workstation.md` |
| V4.0 开源项目吸纳、源码复制治理、第三方归属 | `docs/V4.0-Open-Source-Integration-Plan.md`、`THIRD_PARTY_NOTICES.md` |
| V4.0 分批路线、iOS 深验证和 Android 首版冒烟 | `docs/V4.0-Development-Roadmap.md` |
| V4.0 Legacy Node 禁用、覆盖和删除门禁 | `docs/V4.0-Legacy-Node-Exit-Plan.md` |
| V4.0 不可逆架构决策 | `docs/decisions/ADR-002-v4-open-source-fusion-and-node-exit.md` |
| V4.0 Target Library、targetRef 引用、目标 store、缺失目标诊断 | `packages/studio_runtime/` |
| V2.0 产品定位、目标用户、范围和非目标 | `docs/V2.0-PRD-Enterprise-Flagship.md` |
| V2.0 一级导航、全局框架、模块职责 | `docs/V2.0-IA-Information-Architecture.md` |
| V2.0 交互规范、状态表达、组件使用 | `docs/V2.0-UX-Spec-Enterprise-Console.md` |
| V2.0 Flutter Desktop 技术路线 | `docs/V2.0-Flutter-Desktop-Architecture.md` |
| V2.0 Monorepo 包结构和依赖方向 | `docs/V2.0-Monorepo-Engineering-Plan.md` |
| V2.0 Node/Web 到 Flutter 迁移 | `docs/V2.0-Migration-Plan-Node-Web-to-Flutter.md` |
| V2.0 分阶段开发计划 | `docs/V2.0-Development-Plan.md` |
| Flutter Mac App 主入口 | `apps/studio_mac/` |
| Dart Appium / WebDriver Client | `packages/appium_client/` |
| Dart Runtime、Session、Runner、Evidence、Monitor | `packages/studio_runtime/` |
| Workflow DSL、旧序列导入、表达式白名单、DSL JSON 解析 | `packages/workflow_dsl/` |
| V2.0 当前 workflow 持久化、workflow 恢复、运行态写入互斥 | `packages/studio_runtime/` |
| Flutter Design System、Tech Noir 组件 | `packages/studio_design_system/` |
| Legacy Web 看板 UI、按钮、日志、状态、HTTP API | `legacy/node/src/ios-assist-console.mjs` |
| Legacy 常驻连接、Appium、WDA、证书信任、断开重连 | `legacy/node/src/ios-assist-session.mjs` |
| Legacy 串行执行、安全停止、挂起/继续、运行事件 | `legacy/node/src/ios-assist-runner.mjs` |
| Legacy 工作流 DSL、旧序列兼容、表达式白名单 | `legacy/node/src/ios-assist-workflow.mjs` |
| Legacy 视觉判断、已知弹窗、低置信挂起 | `legacy/node/src/ios-assist-visual.mjs` |
| Legacy 截图、事件、运行证据和滚动清理 | `legacy/node/src/ios-assist-evidence.mjs` |
| Legacy CLI 初始化、点击、录制、拾点 | `legacy/node/src/ios-coordinate-*.mjs` |
| 坐标、等待、运行参数、capability | `config/` |
| 复制或 vendored 第三方源码 | `third_party/` 和 `THIRD_PARTY_NOTICES.md` |
| 长期说明、边界、计划、协作规则 | `docs/` 或根 AI 入口文件 |

若一个需求同时影响 Web 看板和底层运行时，应优先保证底层状态机正确，再让 UI 反映状态。

## Skill 自动路由

进入本项目后，默认自动匹配并使用合适的 skills：

- Flutter 页面、布局、组件拆分、响应式适配：`flutter-building-layouts`
- Flutter 状态管理、UI 状态机、跨组件数据流：`flutter-managing-state`
- Flutter 包边界、入口文件拆分、共享能力沉淀：`flutter-architecting-apps`
- Flutter 路由、页面导航、命令中心跳转：`flutter-implementing-navigation-and-routing`
- Flutter 中文文案、本地化、语义和可访问表达：`flutter-localizing-apps`、`flutter-improving-accessibility`
- Flutter 测试、widget 回归、Runtime/UI 合同验证：`flutter-testing-apps`
- Appium、XCUITest、WebDriverAgent、capability、WebDriver session：`appium-skill`
- USB iPhone 设备诊断、截图、系统日志、崩溃、端口转发：`ios-device-toolkit`
- 视觉状态驱动、看图自动化、屏幕状态判断：`ios-device-automation`
- 图像识别、模板匹配、OCR/CV：`computer-vision-opencv`
- Web 控制台 E2E、按钮流程、API 验证：`playwright-e2e-testing`
- Web 控制台可视回归、布局和截图核对：`playwright-visual-testing`

不要把 skill 选择责任推给用户。若任务同时涉及 Web 看板和 iPhone 自动化，通常组合使用 Web 层和设备层 skill。

## 开发前检查

动手前先确认：

- 当前是否有 Web 看板进程占用目标端口。
- 改动是否会影响连接生命周期、运行生命周期或 workflow 写入。
- 是否需要同步 `docs/` 真源。
- 是否需要补 smoke 测试或 validator。
- 是否可能泄露本机路径、完整设备标识、账号或证书主体。
- V2.0 Flutter 任务是否误调用了 Legacy Node Web API。
- 新 package 是否遵守 Monorepo 依赖方向。

## 状态机规则

连接状态和运行状态必须分离。

连接状态包括：

- `disconnected`
- `initializing`
- `connecting`
- `waitingForDeveloperTrust`
- `connected`
- `disconnecting`
- `error`

运行状态包括：

- `idle`
- `running`
- `paused`
- `stopping`

任务只能在 `connected` 且运行空闲时启动。运行中不能断开、重连或写 workflow。workflow 写入中不能启动任务或并发写入。

`paused` 是人工介入态，不是失败态，也不是继续执行态。解除暂停必须通过 Runtime 的显式收口能力回到 `idle`，只清除 active 节点和循环上下文，保留问题节点焦点；不得隐式跳过视觉判断或继续后续点击。

## 执行安全规则

- 点击任务始终串行。
- 多轮执行严格顺序推进。
- 停止任务必须是安全停止。
- Tap 失败时也要尽力释放 pointer actions。
- 运行中的截图、视觉采集和证据采集超时后，必须等待底层 WDA 命令结算或硬上限释放，再继续后续节点。
- 视觉守卫和视觉分支低置信时默认挂起。
- 自动重试必须有上限。
- 证书信任等待超过上限后进入可操作错误态。
- 不绕过 Developer Mode、证书信任、WDA 签名等 iOS 系统限制。

## 工作流规则

- 自定义 DSL 是项目内真源，不绑定第三方低代码平台。
- 表达式只允许读取 `context.xxx`。
- 不使用 `eval` 或任意 JS 执行。
- 保存 workflow 前必须校验并规范化。
- 无效 workflow 不应原样回传给前端。
- V2.0 当前 workflow 的本地持久化真源是 Project DSL workflow 文件。
- App 启动时应优先恢复本地 Project DSL；缺失或无效时才回退到 legacy sequence 或内置模板。
- Recorder Promote、Source 保存和未来画布保存必须写入同一 workflow 真源。
- 保存失败或 validator 失败不得替换当前 Runtime workflow。
- 旧 `sequence` 必须可自动包装为节点树。
- `Catch` 支持显式 `onError` 错误分支；没有 `onError` 的节点异常仍应失败退出。
- 归档的 legacy click CLI 只能执行线性 Tap / Wait workflow，非线性图交给 V2 Dart Runtime / Workflow runner。

## Legacy Web 控制台规则

- 当前 Web 控制台是 Legacy / Debug / Migration reference，物理位置为 `legacy/node/src/ios-assist-console.mjs`；V2.0 主入口是 Flutter Desktop Mac App。
- V2.0 主导航固定为 L1 Dashboard、L2 Device、L3 Recorder、L4 Workflow、L5 Execute、L6 Monitor。
- V2.0 是 Enterprise Local Workstation，不是 SaaS、多租户、权限系统、审计系统或云端协作平台。
- Cursor 类比只代表 IDE 级工作区、Inspector、命令中心和项目管理体验，不代表 AI Agent 自动执行全部流程。
- UI 不做营销页。
- 主界面遵循 Summary First, Detail Later，技术细节进入 Drawer、Inspector、Advanced 或 Bottom Console。
- Bottom Console 是全局常驻组件，承载 Log、Error、Inspector、Network、Debug。
- 状态接口必须可降级，不因配置异常白屏。
- SSE 关闭时必须释放连接。
- 实时日志和公共 API 错误必须脱敏。
- 日志区域保留复制所有和清除所有。
- 配置写入、连接、断开、运行必须有明确按钮禁用和后端兜底。

## V2.0 Flutter Desktop 规则

- V2.0 主入口是 `apps/studio_mac`。
- V2.0 使用 Flutter Desktop Mac App + Dart Runtime + Dart Appium / WebDriver Client。
- V2.0 不新增自建 Node 中间 API 层。
- Flutter App 禁止调用 Legacy Node Web Console、Node Runner 或自建 Node API 服务。
- Appium server 可以由 Dart Runtime 通过进程管理启动、停止和健康检查；这是标准驱动服务，不视为自建 Node 中间层。
- Debug / Profile Mac App 允许关闭 App Sandbox，以便读取本地项目配置、写入本地证据和启动本机驱动；Release 若保持沙盒，必须通过用户选择项目目录和系统授权恢复同等能力。
- 项目配置发现失败必须区分未找到和不可读；不可读通常指沙盒或权限问题，不得误导为驱动工具缺失。
- 本机隧道指 Appium XCUITest tunnel-creation；pymobiledevice3 隧道只作为辅助诊断通道，不得作为 WDA 会话就绪依据。
- Device 主操作是“连接设备”：Runtime 串行完成本机检查、必要时通过密码弹窗启动本机隧道、准备驱动和创建会话。
- Device 辅助操作“重绑”只能由 Dart Runtime 发现当前唯一 USB 手机、过滤 localNetwork 设备、写回本地项目配置并同步当前 session / tunnel 配置；不得调用 Legacy Node init，也不得自动绑定网络配对设备。
- “连接设备”必须优先尝试自动对齐当前唯一 USB 手机；当绑定设备不可用且 Runtime 能唯一识别当前 USB 手机时，应自动重绑并重跑连接链路一次。无法唯一确认 USB 手机时才进入“绑定手机不可用”提示或要求用户点“重绑”。
- 创建 Appium `/session` 前必须已有有效当前手机绑定；缺少绑定、脱敏占位符或示例设备号都必须在 Runtime 内阻断，不得删除 UDID 后让 Appium 自行猜设备。
- 当当前 USB 手机已确认但 Appium 仍报“驱动未识别手机”时，一键连接可重置当前端口旧驱动并重试一次；受控驱动走正常停止，外部旧驱动只按 host/port 精准清理 Appium 主服务，不匹配 tunnel-creation。
- Mac 密码只允许一次性写入 `sudo` stdin，不保存、不进日志、不进 evidence、不进入复制内容。
- Local Stack Check 只检查不启动；复制隧道命令只作为 Advanced / Command Center 的排障备用，不是主流程。
- iOS 18 及以上真机配置必须携带平台版本，确保 XCUITest driver 进入 RemoteXPC 路径。
- Legacy Node implementation 已物理归档到 `legacy/node/src/`；根目录不再保留活跃 `src/`。
- Legacy npm 入口统一使用 `legacy:*` 前缀；默认 `check`、`verify:all` 和 `smoke:*` 只代表 V2 Flutter/Dart 门禁。
- `apps/studio_mac` 可以依赖 `packages/*`，不得依赖 Legacy Node。
- `packages/workflow_dsl` 必须保持纯 Dart，不依赖 Flutter。
- `packages/appium_client` 不依赖 Flutter UI。
- `packages/studio_runtime` 不依赖具体页面。
- 第一阶段不做完整 Workflow 画布，但完整 Workflow 画布是 V2.0 终极目标，必须按 `docs/V2.0-Development-Plan.md` 分阶段推进。
- `apps/studio_mac/lib/main.dart` 只保留 Flutter 启动引导；`apps/studio_mac/lib/studio_mac.dart` 是公开 Dart 库入口，启动脚本、测试和后续集成应从这里导入，不直接依赖 `src/` 私有路径；当前工作区库边界在 `apps/studio_mac/lib/src/studio_mac_workspace.dart`，后续新增大功能前必须先判断是否应落到 `apps/studio_mac/lib/src/` 的 feature、shell、shared widget、view model 或 helper 文件。
- 拆分 `main.dart` 时应先保留行为与测试不变，再按页面/区域迁移：Shell、Dashboard、Device、Recorder、Workflow、Execute、Monitor、Bottom Console、Status Drawer、Command Center。
- 页面文件继续增长前必须先拆职责：页面入口只组合区域，复杂区域按 controls、preview、timeline、detail、evidence、canvas、inspector、helpers 等语义拆分。
- `packages/studio_runtime/lib/studio_runtime.dart` 只作为公共入口；运行时实现应落到 `lib/src/` 的模型、依赖探测、进程、会话、证据、设备动作、存储、控制器或执行扩展文件。
- 拆分优先保持行为不变，先通过 format/analyze/test，再做更深层抽象；不要为了行数把同一个状态机拆成难追踪的碎片。
- 不把 Runtime、Workflow DSL、Appium Client 或 Evidence 逻辑回写进 Flutter 页面文件；页面只组合状态和触发 Runtime 命令。

## V4.0 融合规则

- V4.0 主方向是本地视觉移动自动化工作站，融合 Airtest、Pyxelator、Appium Inspector 和 appium-mcp 的成熟价值。
- V4.0 是 Mobile First：iOS 和 Android 都必须闭环。工程可以先用 iOS 真机深验证，但 4.0 首版必须让 Android 真机完成发现设备、建立 session、截图、Tap / Swipe / Input、基础 workflow 和本地证据冒烟。
- V4.0 不恢复 Node 中间层。禁止新增 Node API、Node Runner、Node MCP 常驻服务或任何 Flutter / Dart 主路径对 Node 的依赖；Legacy Node 只作为历史参考，覆盖完成后进入删除计划。
- Python Sidecar 是 V4.0 正式组成部分，用于 Airtest、Pyxelator、CV/OCR 和视觉能力；Python 不拥有主执行权，不直接点击设备，不绕过 Runtime。
- Go 可作为未来本机守护、driver broker 或高性能 sidecar 候选；引入前必须另开 ADR，说明 Dart Runtime + Python Sidecar 不足的原因。
- Appium 仍是 iOS / Android 主驱动协议：iOS 走 XCUITest / WDA，Android 走 UiAutomator2 / ADB 辅助。
- Airtest 进入 Vision / Recorder / Evidence 能力层，不让 `.air` 成为 workflow 真源，不让 Airtest 替代 Appium 主驱动。
- Pyxelator 进入 Vision / TargetResolver 能力层，返回坐标、区域、置信度和证据，不直接执行点击。
- Appium Inspector 只吸收协议、能力和体验模型，不嵌 Electron，不复制 UI。
- appium-mcp 只吸收 MCP-compatible 工具模型和权限边界，不引入 Node 运行时。
- AppiumAir 不进入 V4.0 核心融合对象，只作为设备、服务和报告组织经验参考。
- Target Library 的项目真源先在 Dart Runtime 内稳定；Flutter UI 只能通过 Runtime 命令写目标，Project DSL 只保存 `targetRef` 引用，不直接持有目标库完整资产。
- Coordinate target 可作为安全可执行目标；region target 可通过 TargetResolver 解析为区域中心点；selector target 和 text target 优先通过受控 Appium Source 摘要解析为元素中心点；显式开启视觉增强后，text target 可在 Source 未命中时继续尝试 Python OCR provider；image target 必须先经 Vision / TargetResolver 匹配并返回坐标后才允许点击；OCR 缺包、低置信或不可用时必须暂停或保留原未命中，不得盲点。
- V4.0 报告必须从 Runtime `RunLocalReport` 或 `readRunReport` 派生；UI、导出或 AI 解释不得直接扫描 evidence 文件拼接本机路径。报告 JSON 必须过滤不安全截图路径，并脱敏本机路径、完整设备号、长 session 和本机驱动地址。
- 开源吸纳顺序固定为：依赖优先、适配优先、移植优先、小模块复制、产品参考、自研。
- 复制第三方源码前必须确认许可证，复制范围必须小而稳定，代码必须进入 `third_party/`，并登记 `THIRD_PARTY_NOTICES.md`。
- V4.0 新增能力必须通过 Runtime 状态机和资源锁，不得让 Vision、AI、Inspector、Recorder 或第三方 sidecar 直接下发设备动作。

## 文档规则

- 根 `README.md` 只放简介、快速启动和文档入口。
- 长期实现说明放入 `docs/` 或根 AI 入口文件。
- 文档面向 AI 和人类维护者，优先说明边界、状态机、职责和改动落点。
- 文档不放具体私有值、完整路径、完整 UDID、账号或证书主体。
- 改动连接流程、工作流、执行安全、隐私、验证或 UI/UX 方向时，必须同步相关文档。

## 验证规则

常规完成前至少考虑 V2 Flutter/Dart 验证：

- `fvm dart run tool/v2_boundary_check.dart`
- `fvm dart run melos run analyze`
- `fvm dart run melos run test`
- `fvm dart run tool/macos_build_smoke.dart`
- `fvm dart run tool/v2_verify.dart`

兼容 npm wrapper：

- `npm run check`
- `npm run smoke:v2-boundary`
- `npm run smoke:macos-build`
- `npm run verify:all`

按改动范围补充：

- legacy session 改动：`npm run legacy:smoke:session`
- legacy runner 改动：`npm run legacy:smoke:runner`
- legacy workflow 改动：`npm run legacy:smoke:workflow`、`npm run legacy:smoke:validate`、`npm run legacy:smoke:click`
- legacy Web 控制台改动：`npm run legacy:smoke:console`、本机状态 API 检查
- legacy evidence 改动：`npm run legacy:smoke:evidence`
- legacy visual 改动：`npm run legacy:smoke:visual`
- 文档或公共输出改动：隐私扫描和旧文案扫描
- 项目真源或脚本改动：`npm run legacy:smoke:acceptance` 和 V2 边界检查
- V2.0 Flutter 构建改动：`fvm dart run tool/macos_build_smoke.dart`

本地 HTTP 测试和 Web 看板启动需要监听 `127.0.0.1`，在受限环境中可能需要提升执行权限。

## 禁区

- 不修改旧目录或历史项目路径。
- 不把 Web 看板退回为 CLI 子进程壳。
- 不引入多设备并发或群控。
- 不让视觉能力成为核心运行的硬依赖。
- 不长期保存或暴露私密截图、完整设备标识、本机路径、账号或证书主体。
- 不在运行中改 workflow。
- 不绕过 iOS 系统安全限制。
