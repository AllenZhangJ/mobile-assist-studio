# AI Project Context: iOS Assist Studio

## Positioning

`iOS Assist Studio` 是本机个人工作站型 iPhone 辅助自动化工具。

核心定位：

- 本机 Mac
- 单台 USB iPhone 为第一版主目标
- Appium / WebDriverAgent / XCUITest 为主驱动链路
- V2.0 以 Flutter Desktop Mac App 为主入口
- Web 控制台为 Legacy / Debug / Migration reference
- CLI 仅作为兼容调试入口
- 未来演进方向是视觉状态驱动的 iOS 辅助自动化编排器
- V3.0 演进方向是单人单设备的跨平台移动自动化工作站，吸收竞品在设备资源化、目标库、远控/自动化共存、视觉/OCR 和结果归因上的成熟痛点解法
- V4.0 演进方向是本地视觉移动自动化工作站，融合 Airtest、Pyxelator、Appium Inspector 和 appium-mcp 的成熟能力

本项目不做云端、多用户、远程设备池或群控平台。

## V4.0 Product Direction

V4.0 的正式方向是 `Integrated Mobile Automation Workstation`：本地、单人、当前设备、iOS / Android 双平台闭环的视觉移动自动化工作站。

V4.0 不是从零重造平台，而是站在成熟开源项目肩膀上做融合：Airtest 提供视觉自动化和报告经验，Pyxelator 提供轻量截图模板定位，Appium Inspector 提供专业 Inspector 和 session 体验，appium-mcp 提供 AI 工具协议和受控自动化边界。

V4.0 不恢复 Node 中间层。Flutter Mac App 和 Dart Runtime 仍是主路径；Python Sidecar 是视觉能力的正式组成部分；Go 可作为未来本机守护或高性能 sidecar 候选，但引入前必须另开 ADR。

V4.0 虽然可以先用 iOS 真机做深度验证，但 Android 不是二等公民。4.0 首版必须支持 Android 真机最小冒烟闭环：发现设备、建立 session、截图、Tap / Swipe / Input、基础 workflow 和本地证据。

当前 V4.0 Target Library 已在 Dart Runtime 落地基础闭环：目标定义、目标库快照、目标 validator、本地 JSON store、workflow `targetRef` 缺失诊断和删除保护已经可用。Tap 节点可通过坐标目标、区域目标、selector 目标和 text 目标 `targetRef` 执行，也可在图片目标经 TargetResolver 匹配并返回坐标后串行点击；旧坐标 Tap 仍兼容。selector 目标只允许读取受控 Appium Source 摘要，并解析 label、value、text 或 type 命中的元素中心点，不开放 XPath、CSS、脚本或任意表达式。text 目标优先做 Source 级 label/value 精确匹配，显式开启 Python 视觉增强后可在 Source 未命中时尝试 OCR provider；OCR 缺包、低置信或不可用时必须暂停或保留原未命中，不得盲点。Recorder 生成流程时会把点击动作沉淀为坐标目标，并让 Tap 节点引用目标；Device 页已提供目标库摘要和从当前截图中心创建坐标目标的入口，该入口只写 Runtime Target Library，不触发设备动作。Device Inspector 现已提供“建流程”辅助入口，可从当前可读元素生成 selector 目标并插入 Tap `targetRef` 节点，底层只调用 Runtime `upsertTarget` 和 `updateWorkflow`，不点击设备、不启动运行、不调用 Node，也不会从过宽的 type selector 生成流程。

当前 V4.0 Vision Core 已具备 fixture 级目标解析闭环：`CompositeTargetResolver` 会调度坐标、区域、selector、text source、Python OCR text、Pyxelator fixture、Airtest fixture 和 Python sidecar provider；Region provider 可把区域目标解析为中心点和区域证据；Selector provider 可在 Appium Source 可用时通过受控短语法解析元素中心点，provider 只返回结果，不执行点击；Text provider 可在 Appium Source 可用时通过 label/value 精确匹配解析元素中心点，Source 未命中后可在显式开启“视觉增强”时继续尝试 Python OCR text provider；Pyxelator fixture provider 可在小尺寸 PNG fixture 中做图片模板匹配并输出中心点、区域、置信度和本地证据引用；Airtest fixture provider 只表达视觉断言，不运行 `.air` 文件、不启动 Python、不控制设备。Python sidecar 已支持 `pyxelator`、`airtest` 和 `builtin` 三类图片后端：Pyxelator 后端尝试常见模板定位 API，Airtest 后端尝试 `airtest.aircv.find_template`，不可用时返回结构化 `unsupported` 并继续下一 provider，最终可落到内置 PNG 匹配兜底；OCR text provider 优先尝试本机 `pytesseract`，缺包、系统 OCR 不可用或 API 不匹配时只返回结构化不可用并保留原 Source 未命中。provider 只返回解析结果，不执行设备动作。Visual Branch 已支持 `targetRef` 图片、selector 和 text 目标，低置信、未找到或不支持会暂停，不会盲目继续。Wait For Target 已作为 Project DSL 节点进入 Runtime 和 Workflow UI：它会串行截图并解析目标，匹配后继续，超时、低置信、不支持或基础设施错误都会暂停，不执行点击。Tap Target 已支持图片、selector 和 text 目标解析后点击，匹配失败或低置信会暂停，不直接下发点击。图片模板资产已由 Runtime 本地 store 管理：目标库 JSON 只保存项目内相对 `imageRef`，模板 PNG 保存在本地 `targets/images`，解析时临时读取；目标库图片“试找”只使用最近截图做诊断，不刷新截图、不启动驱动、不点击设备。Python 视觉由本机设置里的“视觉增强”显式开启，默认关闭。Airtest 报告心智已先落到 Runtime 本地报告模型，并已接入 Monitor / Execute 共用详情抽屉的本地报告面板、脱敏 JSON 复制、Runtime 文件保存和基础平台差异摘要。

当前 V4.0 Evidence / Report Core 已具备本地报告模型、UI、文件导出、平台差异摘要和保留策略切片：`RunLocalReport` 可从 `RunDetail` 派生运行摘要、问题摘要、节点时间线、视觉检查、截图胶片、日志统计和平台摘要；平台摘要只从 evidence 事件提取 iOS / Android / unknown、设备短名、脱敏设备号、系统版本、连接方式、动作开关和日志数量，不保存原始 logcat 或 WebDriver payload。`LocalRunEvidenceStore` 已实现 `RunReportReader` 和 `RunReportExporter`，`StudioRuntimeController.readRunReport` 与 `StudioRuntimeController.exportRunReport` 可供 Monitor、导出和 AI 解释复用。Monitor / Execute 共用的 Run Detail 抽屉会读取同一份本地报告，展示“本地报告”复盘面板，并通过“复制报告”导出脱敏 JSON 到剪贴板，通过“存报告”把脱敏 JSON 写入当前运行目录内的 `exports/`。本地报告只读取现有 evidence 真源，不新增第二套报告模型，不影响连接和执行链路；导出 JSON 会过滤不安全截图路径，并脱敏本机路径、设备号、长 session 和本机驱动地址。Evidence 历史读取会先应用同一套保留策略，确保 App 重启后打开记录页或刷新历史也会滚动清理过期本地证据；报告文件随单次运行目录一起进入本地证据生命周期。

当前 V4.0 full smoke 编排已支持自动准备：`npm run v4:smoke:full` 默认先检查 Appium `xcuitest` / `uiautomator2` 平台 driver，再用 Dart Runtime 的 Appium 进程管理能力启动或复用本机驱动，检查 iOS USB 是否只有一台当前手机和 iOS 必要隧道，并启动 ADB server 检查 Android 是否只有一台已授权手机；`npm run v4:ios-smoke:full` 和 `npm run v4:android-smoke:full` 也复用同一编排器，只跳过另一个平台，单平台排障时同样具备自动准备能力。准备结论会写入 FULL_SMOKE JSON / Markdown 的“自动准备”区块；driver 冒烟 evidence 会写入平台能力摘要、截图、动作、日志、失败兜底和当前短提交号；Android 纳入 full smoke 且前置阻断时，还会同步写入同 schema 的 `ANDROID_SMOKE_PREFLIGHT` 脱敏诊断，避免 readiness / acceptance 展示旧 Android 阻断。iOS 18+ 隧道需要系统授权时仍不绕过限制，可先通过 Mac App 一键连接，或使用 `npm run v4:ios-smoke:full:password-prompt` / `npm run v4:smoke:full:password-prompt` 从终端隐藏输入 Mac 密码启动本次 smoke 托管隧道；`password-stdin` 入口仅作为自动化备用。密码不得进入日志、报告、evidence 或复制内容；iOS 准备只读取 USB 数量和工具状态，Android 准备不创建 Appium session、不点击设备、不读取隐私内容；readiness / archive 会把自动准备阻断与前置检查阻断合并展示，并把旧提交或缺提交号的 smoke 留档视为历史证据，不计入当前提交终验通过；readiness、completion-audit 与 archive final 都必须同时要求当前提交的 iOS smoke、Android smoke 和 full smoke 完整通过，并解析最近平台 run 的元数据、事件类型和同 run 截图文件；readiness JSON / Markdown 的 nextSteps 也只允许项目内 V4 smoke / 终验白名单命令；full smoke 必须同时包含 `iOS smoke` 与 `Android smoke` 两个通过步骤，单平台 full smoke 不能冒充双平台完整通过。

当前 Mac App Monitor 已接入 V4 验收卡：它从 Runtime 快照展示当前平台、iOS / Android 现场状态、本地运行数量、Batch 0-8 进度、代码干净度、远端同步状态、问题数量、Android 留档数量和下一步短提示，并提供 full smoke、双平台密码版、iOS 密码版、Android smoke、acceptance audit、acceptance final 以及“现场路线”命令复制入口。Runtime 启动和 Monitor 刷新时会通过 `V4AcceptanceSummaryReader` 读取最新 `FINAL_ACCEPTANCE` 脱敏摘要，把终验完成状态、短提交、工作区干净度、上游同步状态、批次进度、iOS / Android run 数、截图数、full smoke 数、iOS / Android 本机状态、结构化终验门禁和现场补验清单写入 snapshot；读入时会对用户可见文本再次应用路径、设备号和本机地址脱敏，且补验命令只保留项目内 V4 smoke / 终验白名单，防止坏报告污染 UI 或路线复制。UI 不直接扫描文件、不读取截图、不展示报告路径、底层命令输出、Git 文件列表或远端 URL。现场路线优先使用 final acceptance 的 `fieldChecklist` 顺序；旧报告缺少清单时才回退到 nextSteps 推断。该入口不直接启动真机动作、不扫描 smoke 文件、不替代最终验收门禁。Device 本机指引已补充“安卓准备”卡，提示开启 USB 调试、插线、点允许和复制 Android smoke 命令；该卡同样只复制命令，不启动 ADB、驱动或真机动作。Device 的本机环境检查已纳入 `android-adb`：只做 ADB 可见性和唯一已授权手机判断，展示无设备、未授权、离线、多设备或 ADB 不可用的短提醒和下一步；这些结果用于 V4 Android 准备度提示，不阻断当前 iOS 一键连接，也不计作真实 Android smoke。Android 单平台 smoke 在驱动或手机条件不足时会写入 `ANDROID_SMOKE_PREFLIGHT` 脱敏诊断并被 readiness 索引，但不计作真实 Android run；Android 真机现场冒烟留档仍是当前 V4.0 未完成项。

当前 V4.0 final acceptance 报告已具备代码版本指纹、现场摘要、Batch 0-8 验收索引、截图留档索引、终验门禁缺口、现场补验清单和命令级下一步：`npm run v4:acceptance-audit` 会在 Markdown 和 JSON 中嵌入短提交、分支、工作区干净度、上游同步状态、最新 readiness / archive 的本机状态摘要、批次判定、Android 前置诊断、截图脱敏相对路径、截图 / iOS / Android / full smoke 留档数量，并结合结构化证据写出缺 Android、缺 iOS、缺截图、full smoke 未过和终验重跑时对应的安全命令。终验门禁缺口必须同时吸收代码状态、archive warnings、readiness 当前本机设备状态和 readiness 最近平台 smoke 状态，给出当前问题、通过标准和建议命令，不能只把缺口藏在 archive 子报告中，也不能漏掉“工作区未提交”“提交未推送”“当前设备未就绪”“已有平台 run 但最近未完整通过”或“已有 smoke 但不属于当前提交”的情况；现场补验清单必须继续读取 readiness 当前 iOS / Android 状态，把“当前可用 / 未就绪”和下一步动作写入每个平台的通过标准，避免用户只看到泛化命令。终验报告生成端和 Runtime 读取端都只允许项目内 V4 smoke / 终验白名单命令，nextSteps 可见文本里的反引号命令也会被过滤，不得把任意 shell 文本写入 JSON、Markdown、stderr、UI 文本或复制入口。`npm run v4:acceptance-final` 只有在本地工作区干净、当前提交已与上游同步、当前提交的 iOS smoke、Android smoke、full smoke 和留档全部通过时才能返回 0；失败时也必须在终端输出同一组门禁缺口、现场补验清单和安全命令。若最近 full smoke 阻断在 iOS 隧道，报告里的双平台补验命令必须使用 `npm run v4:smoke:full:password-prompt`，避免用户先补完 iOS 后又在普通 full smoke 中再次卡密码。该报告仍只做本地审计和留档，不执行真实设备动作，不读取截图内容，不保存 Git 文件列表或远端 URL。

当前 V4.0 AI / MCP Core 已从 Command Center 扩展到 Device Inspector：检查当前界面后，Inspector 面板可调用 Runtime 受控 `suggestTarget` 和 `suggestLocator` 工具展示目标 / 定位草稿。该入口只展示脱敏草稿和审计日志，不写 Target Library、不保存 Project DSL、不触发 Appium 动作。

当前 Monitor Run Detail 已接入 Runtime 受控 `explainRunFailure` 工具：用户打开本地运行详情后可点“智能解释”，基于同一份本地报告生成短解释和下一步。该入口只读展示，不读取截图画面、不写报告文件、不触发重跑、不执行修复。

V4.0 真源入口：

- `docs/V4.0-PRD-Mobile-Automation-Workstation.md`
- `docs/V4.0-Architecture-Integrated-Mobile-Workstation.md`
- `docs/V4.0-Open-Source-Integration-Plan.md`
- `docs/V4.0-Development-Roadmap.md`
- `docs/V4.0-Legacy-Node-Exit-Plan.md`
- `docs/decisions/ADR-002-v4-open-source-fusion-and-node-exit.md`
- `THIRD_PARTY_NOTICES.md`

## V3.0 Product Direction

V3.0 的正式方向是 `Cross-Platform Mobile Workstation`：单人、单台当前设备、本地桌面、iOS / Android 跨平台的移动自动化工作站。

V3.0 不是把 V2.0 的 iOS 资产包起来不动，也不是照抄竞品平台。V3.0 以 TestHub APP 自动化测试模块为竞品痛点参考，吸收设备资源化、目标库、远控与自动化共用设备体系、图像/OCR/坐标混合定位、执行状态与测试结果分离等能力；但仍坚持本地、单人、单设备、串行执行、安全停止和 Project DSL 真源。

V3.0 真源入口：

- `docs/V3.0-Competitive-Strategy-TestHub.md`
- `docs/V3.0-PRD-Cross-Platform-Mobile-Workstation.md`
- `docs/V3.0-Architecture-Cross-Platform-Runtime.md`
- `docs/V3.0-IA-UX-Mobile-Workstation.md`
- `docs/V3.0-Development-Plan.md`
- `docs/V3.0-Enterprise-Design-Master-Brief.md`
- `docs/V3.0-Flowcharts-Specialized.md`
- `docs/V3.0-Sequence-Diagrams-Specialized.md`
- `docs/V3.0-Page-Prototypes-Specialized.md`
- `docs/prototypes/v3-enterprise-static-prototype.html`
- `docs/V3.0-ChatGPT-Flow-Prototype-Brief.md`
- `docs/decisions/ADR-001-v3-cross-platform-driver-boundary.md`

## V2.0 Product Boundary

V2.0 的正式定位是 `Enterprise Local Workstation`：企业级体验的本地自动化工作站。

Enterprise 在本项目中代表成熟的信息架构、清晰的工作流、可扩展、可维护和专业工具体验，不代表 SaaS、多租户、权限系统、审计系统或云端协作。

V2.0 的产品类比是 `Cursor for Mobile Automation`，但 Cursor 只代表 IDE 级体验、项目管理体验、工作区体验、Inspector 体验和命令中心体验，不代表 AI Agent 自动执行全部流程。

Primary User 是不会 Appium / WDA 的运营或 QA。Secondary User 是自动化工程师。所有交互优先级遵循：可理解性优先于灵活性，灵活性优先于工程能力。

V2.0 保持 Single Device First：运行时仅允许一台 USB iPhone。Device List、Fleet 和 Cluster 只作为信息架构预留，不进入当前运行范围。

Workflow 的唯一真源是 Project DSL。用户可见入口统一为“画布 / 源码 / 检查”，三者必须映射到同一 DSL；代码内部仍可使用 visual/source/validate 命名。禁止任意 JavaScript、Python 或用户自定义脚本执行。

当前 V2.0 Flutter Runtime 已引入本地 Workflow Store：启动时优先恢复本地 Project DSL workflow，缺失或无效时才回退到 legacy sequence 或内置 A-F 模板。Recorder Promote、后续 Source 保存和完整画布保存都必须写入同一个 Project DSL 真源；无效 workflow 或保存失败不得替换当前 Runtime 真值。

当前 V2.0 Workflow Template Library 已接入 Workflow 页模板抽屉，当前提供 Blank Workflow、A-F Basic、Visual Guard、Condition Branch、Loop Batch 和 Catch Retry 六类 Project DSL 模板；Blank Workflow 只有开始和结束，是从零创建工作流的安全起点。模板导入必须调用 Dart Runtime `updateWorkflow`，写入同一个 Project DSL / Workflow Store，不直接调用设备、不启动 Appium、不触发执行。Sub Workflow 模板暂不进入普通模板库；Sub Workflow 节点 Inspector 已提供本地示例子流程注册入口，用于先建立可选择的安全子流程；该子流程会写入本地 Sub Workflow Store，项目重启后可恢复。

当前 V2.0 Workflow Template Library 的 App 侧实现已按模板模型、模板入口、基础模板、视觉模板、控制流模板、子流程模板、抽屉和卡片拆分。`workflow_template_model.dart` 只定义模板卡片模型；`workflow_template_library.dart` 只承载可导入模板注册表；`workflow_template_basic_library.dart` 只承载空白等基础模板；`workflow_template_visual_library.dart` 只承载截图和视觉判断模板；`workflow_template_control_library.dart` 只承载条件、循环和异常兜底模板；`workflow_template_subflow_library.dart` 只承载 Inspector 注册用安全子流程模板；`workflow_template_drawer.dart` 只承载右侧模板抽屉；`workflow_template_card.dart` 只承载模板卡片和统计胶囊；`workflow_page_template_actions.dart` 仍是唯一的模板打开与导入动作入口。后续新增 App 侧模板时先判断基础、视觉、控制流或子流程归属，导入逻辑继续走 Runtime `updateWorkflow`，不得让模板卡片直接写 DSL 或触发设备动作。

当前 V2.0 Workflow 源码视图已支持 Project DSL JSON 编辑、即时解析、validator 校验和源码诊断。无效草稿只停留在编辑器，不替换 Runtime workflow；诊断会把 validator 错误归类到节点或字段，点击后只定位编辑器选区，不写入 Project DSL、不触发设备命令。诊断同时包含节点和字段时，源码视图会优先在该节点对象范围内定位字段，避免跳到其它节点的同名字段；源码编辑区、提示和诊断列表必须共享可伸缩高度，窄窗口或低高度下诊断列表收缩滚动，不允许撑爆页面。检查视图使用同一诊断模型展示离线 validator 结果；点击可映射到当前 workflow 节点的诊断会切回画布并选中节点，无法映射节点的诊断会切回源码并定位字段或源码级位置。源码视图作为高级编辑入口允许保留节点 ID 和字段名用于精确定位；检查视图和 Node Inspector 必须使用 workflow 上下文把同一诊断转换成节点名称、中文字段和短中文原因，不直接暴露裸节点 ID、缺失子流程 ID 或底层字段。当前诊断已合并 DSL 结构校验与本地项目级 Sub Workflow 引用校验；直接缺失子流程、嵌套缺失子流程、直接自引用或间接循环引用会在源码、检查、画布节点卡片和 Node Inspector 中提前展示，不必等到保存或执行时才暴露。Project DSL validator 已拒绝直接自引用：任何节点的 `next` 不得指向自身，Catch 的 `onError` 也不得指向自身；入口必须是 Start 节点，Start 只能有一条主线，End 不允许继续连接；这些问题会显示短中文原因，并定位到 `entryNodesId`、`next` 或 `onError`。合法循环必须通过 bounded Loop 与 body 回边表达，不能用单节点自环。画布节点卡片和 Node Inspector 会只读展示节点级问题，提示来源仍是同一诊断模型，不形成第二套校验状态。

当前 V2.0 Workflow Source helper 已按职责继续拆分：`workflow_source_helpers.dart` 只保留 Source helper 路由说明；`workflow_source_models.dart` 只承载 Source 草稿和诊断模型；`workflow_source_parser.dart` 只承载 Project DSL JSON 序列化、解析和项目级 validator 调用；`workflow_source_diagnostic_extractors.dart` 只承载 validator 错误到节点、字段和备用定位文本的提取；`workflow_source_diagnostic_messages.dart` 只承载源码级 validator 短中文文案；`workflow_source_diagnostic_user_messages.dart` 只承载 Validate、Canvas 和 Inspector 使用的 workflow-aware 用户文案与字段标签；`workflow_source_selection_helpers.dart` 只承载 Source 编辑器选区定位。后续新增 Source 诊断时先判断是模型、解析、提取、源码文案、用户文案还是选区定位，不得重新堆回单个 helper 文件；新增用户可见诊断时必须优先复用 workflow-aware 显示方法，不得在 Validate、Inspector 或 Canvas 各自手写一套错误文案。

当前 V2.0 Workflow Canvas MVP 已支持节点卡片、网格、连线、平移、缩放、适配并居中视图、节点拖拽、框选多选、修饰键点击多选、画布空白点击清空选区、多选批量移动、方向键微调选区、多选四向对齐、多选均分、Mini map 点击/拖拽导航、Node Navigator 搜索/定位、受控连接编辑、端口点选连接、端点拖拽连线、画布边选中/删除/重接起点/目标、选边插入核心节点、左侧 Node Palette 节点库、顶部 Add Node 可见节点新增菜单、Auto Layout 保存命令、画布级快捷键、画布历史撤销/重做、多选批量复制、多选批量删除和跨 workflow 系统剪贴板粘贴。节点卡片已基于 RuntimeExecutionFocus 展示“当前 / 完成 / 失败”短状态，失败态优先于当前态；节点卡片会根据当前连接状态、iOS / Android 能力报告、目标库类型和视觉增强设置展示细粒度能力徽标，提前提示“待连 / 可用 / 缺截图 / 缺元素 / 缺文字 / 需目标 / 缺目标”，该提示只做 UI 派生，不写 Project DSL、不触发 Runtime 命令；画布会从最近一次 RunDetail 聚合节点级留档，显示“问题 / 截图 / 视觉 / 留档”短标，选中节点后 Inspector “上次留档”卡可带着运行 ID 和节点 ID 深链打开记录详情，Monitor 自动定位该节点并展开截图证据或节点轨迹；Workflow 页面不直接扫描 evidence 文件、不读取截图内容、不保存本机路径；Node Navigator 可快速定位当前节点和失败节点，相关高亮、留档标记、记录深链和定位由 `workflow_canvas_navigation_test.dart` 覆盖。节点卡片右侧分支摘要已改为短中文语义：普通节点显示“后续”，Condition 显示“满足 / 否则”，Loop 显示“主体 / 后续”，Visual Branch 显示“通过”，Catch 显示“主线 / 错误”；该摘要只消费当前 Project DSL 节点和边，不写回 DSL、不改变执行语义，也不直接暴露裸 `next` ID 列表。连线提示、端口提示和选中连线浮层使用节点短中文标签展示，不直接展示裸节点 ID；Condition、Loop、Visual Branch 和 Catch 等分支边在选中浮层中显示“满足 / 否则 / 主体 / 后续 / 通过 / 主线 / 错误”等短语义角色；Catch 的 `parameters.onError` 已作为独立错误画布边支持绘制、命中、删除、重接起点/目标和边上插入核心节点，删除会清空 `onError`，边上插入会把 `onError` 改接到新节点并让新节点接回原错误目标，错误边重接起点时新起点必须是尚未配置错误分支的 Catch 节点。内部连接、删除、重接和插入仍使用 Project DSL 节点 ID，并继续通过 Runtime `updateWorkflow` 与 validator 保存；新增连接、改目标和改起点的候选层必须先模拟写回并复用同一 Project DSL validator 预检，Start 已有主线、End 出边、Tap / Wait 等单主线节点多出口这类非法结构不应出现在候选菜单或可用输出端口中。适配视图只修改本地 `TransformationController` 的缩放和平移，不写入 Project DSL，不触发运行；画布空白点击、Mini map 和 Node Navigator 导航只更新编辑器视口和选中态，不写入 Project DSL，不触发运行；Node Navigator 默认折叠，展开后可按节点 id、标签和类型搜索，并可快速定位 Current、Failed、选中节点和首个有 validator 问题的节点；导航搜索结果、问题节点数量、首个问题节点、选中定位目标和每行短中文展示项归属 `workflow_canvas_navigation_model.dart`，导航入口归属 `workflow_canvas_navigation.dart`，展开面板装配归属 `workflow_canvas_navigation_panel.dart`，标题/搜索/快捷定位/结果列表归属 `workflow_canvas_navigation_panel_sections.dart`，浮层、折叠按钮、快捷按钮和结果行归属 `workflow_canvas_navigation_widgets.dart`，搜索结果不得直接展示裸节点 ID 或底层英文类型。端点拖拽连线、画布边删除、画布边重接起点/目标、选边插入节点、Node Palette、顶部 Add Node、Auto Layout、方向键微调、多选四向对齐、多选均分、画布快捷键和撤销/重做触发的编辑都必须通过 Runtime `updateWorkflow` 和 Project DSL validator 保存；画布边重接起点/目标同时覆盖普通 `next` 和 Catch `onError`，并进入画布历史撤销/重做；多选批量移动、方向键微调、多选四向对齐和多选均分只保存选中节点的 `visual.position`，Auto Layout 只清除节点 `visual.position`，三者都不影响执行语义；Node Palette 和顶部 Add Node 菜单在有选中非 End 节点时插入到选中节点之后，否则插入到入口节点之后；Node Palette 和顶部 Add Node 当前覆盖 Tap、Wait、Swipe、Input、Loop、Snapshot、Condition、Visual Branch、Catch 和 Sub Workflow。Loop 插入会生成 bounded Loop 骨架：第一条边是 body，第二条边是 after，默认 body 节点会回连 Loop；画布快捷键当前覆盖 Delete / Backspace 删除、Cmd+D 复制、Cmd+C 复制节点到画布本地剪贴板和系统剪贴板、Cmd+X 剪切节点到画布本地剪贴板和系统剪贴板、Cmd+V 优先从本地剪贴板粘贴，缺失时从系统剪贴板读取本项目私有节点 JSON、Cmd+Z 撤销、Cmd+Shift+Z 重做、Cmd+Shift+L Auto Layout、Cmd+A 全选、Esc 清空选择、方向键微调选区和 Shift+方向键大步微调，只在 Visual Canvas 聚焦时生效，不在 Source JSON 或 Inspector 输入框中抢占输入；系统剪贴板只保存节点快照、节点参数和可选 `visual.position`，不包含设备、session、WDA endpoint、本机路径或运行证据；Delete / Backspace 在选中边时优先删除边，否则删除选中节点；Cmd+A、Esc、空白点击和 Cmd+C 只改变编辑器选择态或剪贴板，不写入 Project DSL、不触发运行；方向键微调、多选四向对齐和多选均分只写 `visual.position`，不改变节点参数、Tap 坐标或边关系；Cmd+X 会先保存节点快照，再通过受控删除路径移除非 Start / End / Entry 节点；Cmd+V 只粘贴非 Start / End / Entry 节点，来源节点已删除或不在当前 workflow 时会按当前选中节点或入口节点作为锚点粘贴，并必须通过 Project DSL validator 保存；Cmd+Z 和 Cmd+Shift+Z 使用页面本地 Workflow 历史栈，但恢复目标仍必须经过 Runtime `updateWorkflow`、Workflow Store 和 validator；Source 草稿未保存、保存中或运行中时历史操作锁定；选边插入当前提供 Tap / Wait 快捷按钮，并通过更多菜单支持 Swipe、Input、Loop、Snapshot、Condition、Visual Branch、Catch 和 Sub Workflow；多选批量复制/删除只允许作用于非 Start / End / Entry 节点，并必须通过 Project DSL validator 保存；受控复杂图复制已覆盖单入口分支、外部 Catch 错误出口、不连通组件串接、Loop 包 Catch 的嵌套子图、多入口汇合子图普通锚点安全串行化，以及条件锚点保留双入口汇合结构；任意复杂图编辑仍属于 Phase 3 完整画布。

当前 V2.0 Workflow Canvas 剪贴板实现已按职责拆分：`workflow_canvas_clipboard_model.dart` 只承载页面内和系统剪贴板共用的节点快照模型，`workflow_page_system_clipboard_actions.dart` 只承载系统剪贴板读写和跨流程粘贴兜底，`workflow_page_selection_actions.dart` 只承载画布快捷键和选择态分派，`workflow_page_clipboard_actions.dart` 只承载把剪贴板内容写回 Project DSL。剪贴板图算法已支持单入口分支子图、多个互不相连组件、受控 Loop + Catch 嵌套子图和多入口汇合子图复制/粘贴：内部 `next` 和 `onError` 会重映射到新节点 ID，外部出口会接回粘贴锚点原后继，并继续通过 Runtime `updateWorkflow` 和 Project DSL validator 保存；当复制的 Catch `onError` 指向选区外节点时，粘贴后必须接回锚点原后继，不能静默清空错误分支；多个互不相连的选中组件会按源顺序安全串接；多入口汇合子图在普通锚点下只对外暴露第一个入口，并把其它入口按源顺序串行化，避免普通节点在 Runtime 中产生多个出口；在条件锚点下可保留最多两个入口的汇合结构。剪贴板组件拆分和入口计算必须复用统一出边查询，不得重新手写 `next` / `onError` 双通道遍历。完整任意复杂图编辑仍属于后续完整画布能力。后续扩展复杂图复制时应优先扩展模型和 graph helper，不得把序列化、平台剪贴板或 DSL 写回逻辑重新堆到画布渲染组件里。

当前 V2.0 Workflow Canvas 已提供 Canvas Lock Banner。运行中、Source 草稿未保存、Source 保存中、Node Inspector 保存中或图编辑保存中时，画布会以 Summary First 方式展示锁定原因；该提示只解释当前编辑锁，不写 Project DSL、不调用 Runtime、不触发设备动作。

当前 V2.0 Workflow Canvas 已提供只读 Overview 概览条。概览条用短中文展示节点数、连线数、问题数和当前选区，只读取当前 Project DSL、validator 诊断和编辑器选区，不写 Project DSL、不调用 Runtime、不触发设备动作，也不展示裸节点 ID。

当前 V2.0 Workflow 页头已提供“去运行”入口。该入口只切换到 Execute 页，不连接设备、不启动 Appium、不执行任务；流程无效、Source 草稿未保存、保存中或运行中时必须禁用，实际开始运行仍只能在 Execute 页通过 Preflight 和确认弹窗。

当前 V2.0 Workflow Inspector 已接入基础只读 Context Variables 面板，展示 Condition 表达式允许读取的安全 `context.xxx` 字段和当前预览值，并提供单字段复制和复制全部安全摘要入口。该面板只展示循环、截图状态、连接状态、运行状态和子流程输入入口等脱敏信息；连接、运行和节点类型预览必须使用短中文标签，不直接暴露 `connected`、`running`、`tap` 等底层枚举；不展示完整设备标识、完整 session、WDA endpoint、source XML 或原始 WebDriver payload。Context Variables 的字段模型、脱敏预览值和安全摘要生成归属 `workflow_context_variable_model.dart`，`workflow_inspector_context.dart` 只保留节点编辑器入口声明，`workflow_inspector_diagnostics.dart` 只负责节点级诊断面板，`workflow_inspector_context_panel.dart` 只负责上下文变量面板和变量行展示；`workflow_inspector_multi_node.dart` 只负责多选摘要外壳，`workflow_inspector_multi_node_stats.dart` 只负责多选统计和可变更判断，`workflow_inspector_multi_node_actions.dart` 只负责批量复制、删除、对齐和均分入口，`workflow_inspector_multi_node_button.dart` 只负责复用的批量布局按钮，`workflow_inspector_multi_node_chips.dart` 只负责选中节点 chip；多选摘要只展示节点短中文标签，不直接展示裸节点 ID；后续新增多选统计、批量动作或选中节点展示时必须进入对应分片，多选批量入口必须继续通过页面动作分片和 Runtime `updateWorkflow` 保存，不得在 Inspector UI 内直接写 DSL。Sub Workflow 节点编辑区已能展示 Runtime 已注册子流程摘要，主表单只读展示当前子流程名称、节点数和可用状态，不提供裸 `workflowId` 输入；选择目标子流程必须通过可用子流程列表写入草稿。可通过 `inputMap` 声明式传入参数，格式只允许参数名读取 `context.xxx`，子流程内通过 `context.inputs.xxx` 读取，不开放脚本或 eval；Inspector 已提供“加轮次 / 加截图 / 清空”短按钮生成常用参数映射，按钮只改草稿，保存仍走 Runtime `updateWorkflow` 和 DSL validator；可注册一个只包含 Wait 的本地示例子流程，可把当前 Project DSL 主流程存为本地子流程，也可删除未被当前流程或其它子流程引用的本地子流程。该能力通过 Runtime 写入本地 Sub Workflow Store，不连接设备、不启动 Appium、不执行子流程；Workflow 页的子流程注册、当前流程转子流程和删除确认动作已拆入独立子流程动作分片，页面主文件只保留渲染和整体状态编排；子流程条目在窄 Inspector 中必须可收缩省略，避免中文文案撑开布局。完整子流程模板库和复杂递归编排 UI 仍是后续能力。

当前 V2.0 Workflow Inspector 编辑器已拆为生命周期装配、参数表单、连接/画布动作、控制器同步、连接候选和草稿解析分片。`workflow_inspector_editor.dart` 只维护输入控制器生命周期、锁定态、保存态和区域装配；`workflow_inspector_editor_forms.dart` 只做节点类型分发，不承载具体字段；动作节点参数归属 `workflow_inspector_action_forms.dart`，用户可见字段必须使用短中文：Tap 坐标为“横 / 纵”，Swipe 为“起横 / 起纵 / 终横 / 终纵 / 时长”，Wait 为“等待”，Validate、Canvas 和 Inspector 的动作节点诊断也必须复用同一套字段文案，不得直接展示 `X / Y / fromX / workflowId` 这类工程字段名；Loop / Snapshot / Condition / Visual Branch 基础控制和视觉字段归属 `workflow_inspector_control_forms.dart`；Catch 重试、错误分支候选、错误分支菜单和显示文案归属 `workflow_inspector_catch_forms.dart`；Sub Workflow 主表单、只读目标摘要和子流程选择区域装配归属 `workflow_inspector_subflow_forms.dart`；Sub Workflow 传入参数文本、快捷参数、inputMap 格式化、解析和 upsert helper 归属 `workflow_inspector_subflow_input_map.dart`；子流程选择、注册和删除 UI 归属 `workflow_inspector_subflow_picker.dart`；单节点 Inspector 的当前节点、连接目标、连接标签和 Catch 错误分支都必须使用节点短中文名称或中文类型展示，不直接展示裸节点 ID，内部 ID 只用于稳定 key、Project DSL 写回和 Source View；Catch 节点使用“错误分支”选择器设置或清空 `parameters.onError`，用户不需要手写节点 ID，保存仍通过 Runtime `updateWorkflow` 和 Project DSL validator；`workflow_inspector_editor_actions.dart` 只承载连接新增/删除、节点插入、复制和删除入口，连接 pill 的显示文案与删除按钮稳定 key 必须分离；`workflow_inspector_editor_controller_sync.dart` 只承载节点切换时的控制器同步；`workflow_inspector_editor_connection_candidates.dart` 只承载可新增连接目标候选；`workflow_inspector_editor_draft.dart` 只承载按节点类型生成草稿和轻量草稿校验；`workflow_inspector_widgets.dart` 只保留通用小组件、草稿模型和输入样式。后续新增节点参数、连接规则或 Inspector 动作必须进入对应分片，不得重新堆回单个编辑器大文件。

当前 V2.0 Flutter Runtime 已支持 Tap、Wait、Swipe、Input、Loop、Snapshot、Condition、Catch、Visual Branch 和 Sub Workflow 的基础执行语义。Swipe 使用 W3C pointer action 并在动作后释放 actions；Input 使用当前焦点输入通道并仅在日志/证据中记录文本长度，不长期暴露明文输入；Loop 是 bounded control-flow 节点，只允许有限 `count`，第一条边为 body，第二条边为 after，body 通过显式回边回到 Loop 后继续计数；Visual Branch 会先基于 Appium page source 做已知 iOS 系统弹窗基础识别，命中开发者信任、通知权限、定位权限、本地网络权限或粘贴权限等规则时进入 `paused`，不自动点击处理弹窗；未命中弹窗时再做保守的最新截图状态判断，通过时进入唯一成功分支，低置信时进入 `paused`，不继续自动点击；Runtime 已为 Visual Branch 写入轻量 Visual Evidence Chain，包括规则、截图是否存在、置信度、阈值、后续动作和原因，Run Detail Drawer 只读展示该证据链；Runtime 不保存完整 page source，不展示 source XML；Runtime 写入 Console、Execution Timeline、Run Detail 和 Visual Evidence Chain 的用户可见事件源必须使用中文短文案，不能只依赖 Flutter UI 做英文替换；当前 Tap、Wait、Swipe、Input 和 Snapshot 节点运行事件已由 Runtime 直接输出“第 N/M 轮：点击/等待/滑动/输入/截图 ...”这类短中文动作文案；Sub Workflow 只执行 Runtime 本地注册的 Project DSL 子流程，并支持安全 `inputMap` 参数传递：父流程只允许把 `context.xxx` 解析后的值传入子流程，子流程只通过 `context.inputs.xxx` 读取，证据只记录参数名和数量，不记录敏感值；Runtime snapshot 已暴露脱敏子流程摘要给 Flutter Inspector 使用，摘要包含 workflowId、名称、节点数、合法性和直接引用的子流程 ID，不包含设备、session、路径或底层 payload；Runtime 也提供受控本地注册、当前流程转子流程和受控删除方法；本地子流程通过 Sub Workflow Store 持久化，启动时只恢复 validator 通过的子流程，保存当前 workflow、注册子流程和启动运行前都会统一校验 Sub Workflow 引用是否真实存在，并拦截嵌套缺失引用、直接自引用与间接循环引用；缺失引用、嵌套缺失引用或循环引用会在任何设备动作前被拒绝，不进入执行主体、不写运行证据、不触发 Tap / Wait / Snapshot；同一引用校验器已暴露给 Flutter 诊断层复用，保证 UI 提前提示、Runtime 保存兜底和运行前兜底使用同一规则；删除时会拦截仍被当前流程或其它子流程引用的目标。完整 CV/OCR/AI 视觉识别、复杂嵌套控制流和完整子流程模板库仍属于后续增强。

当前 V2.0 Top Status Bar 已接入状态详情 Drawer：Device、Driver、Workflow 和 Execution 状态胶囊均可点击查看只读详情。Workflow 胶囊和详情必须使用项目级 workflow 校验，合并 DSL 结构校验与本地 Sub Workflow 引用校验；缺失子流程或自引用时显示“流程提醒”和短中文原因，不直接信任基础 `workflowIsValid`。详情内容只从 `StudioRuntimeSnapshot` 派生，展示摘要、下一步动作、短会话摘要、截图时间、流程统计和执行进度；不触发 Runtime 命令、不写 workflow、不展示完整设备标识、完整 session、WDA endpoint、source XML 或原始 WebDriver payload。

当前 V2.0 Global Command Center 已接入 Flutter Shell：可通过顶部命令按钮、`⌘K` 或 `Ctrl+K` 打开，支持搜索、方向键选择、回车执行和 Esc 关闭。当前支持前往 L1-L6 页面、打开 Device / Driver / Workflow / Execution 只读状态详情、打开 Settings Drawer、运行本机环境检查、复制本机隧道启动命令、复制脱敏诊断摘要和打开 Batch 8 智能抽屉。命令中心只调用本地 Shell 导航、现有 Drawer、Dart Runtime 的安全本机检查、受控 AI 工具入口和 Flutter 剪贴板能力；复制隧道命令、诊断摘要和智能结果只写入剪贴板，不执行命令、不请求权限、不调用 Legacy Node、不直接调用 Appium、不连接设备、不启动运行、不写 workflow。智能抽屉只能调用 Runtime `invokeAiTool`，展示读屏、草稿、目标、定位、失败解释、模板建议和运行交接结果；危险运行交接必须确认，确认后也只返回 Runtime 主按钮交接结果，不直接执行。命令中心代码已按职责拆分：`command_center.dart` 只承载命令模型、弹窗、搜索和键盘选择，`command_center_results.dart` 只承载结果行、结果图标、结果文本和搜索空态，`command_center_actions.dart` 只承载命令列表生成和安全剪贴板动作，`command_center_diagnostics.dart` 只承载脱敏诊断摘要文本，`ai_command_drawer.dart` 只承载智能抽屉、受控工具调用、结果展示和审计日志；后续新增命令不得重新堆回 Shell 主文件，危险命令必须进入确认 Modal。

当前 V2.0 Monitor 已能从本地运行证据区分 completed、failed、paused 和 stopped，并展示总数、成功率、均耗时、失败、暂停、已停等紧凑 KPI，以及 7 / 30 / 90 日本地趋势、失败趋势、常见问题、Status Distribution、Issue Categories、耗时节点、耗时趋势和 Recent Runs；KPI、趋势窗口、失败趋势、常见问题、耗时节点和耗时趋势由 Dart Runtime 从同一份本地 evidence 聚合生成，UI 切换只影响当前视图，不改变 Runtime run history 或本地文件；失败趋势只聚合 failed、paused 和 stopped 的本地日趋势，用短中文展示失败、暂停和已停，不展示坐标、路径、底层 payload 或原始日志；常见问题只展示本地失败聚类，包括问题分类、问题节点、次数、影响流程、关联运行摘要和最近发生时间，不读取截图画面、不展示坐标、路径、底层 payload 或原始日志；常见问题可进入“看记录”本地深挖，优先使用 Runtime 聚合的关联 run id 筛选 Recent Runs，旧摘要缺失关联列表时按问题分类做保守降级筛选；该筛选只改变当前 Monitor 列表，不读取运行详情、不读取截图、不写回 evidence；问题分类也可进入“看记录”本地筛选，优先使用 Runtime 聚合的关联 run id，旧快照或手工预览数据缺失关联列表时按分类对应状态保守映射，只改变 Recent Runs 当前列表，不读取详情、不读取截图、不写回 evidence；耗时节点面板只展示最近本地运行详情聚合出的平均耗时、峰值、样本数、问题数和关联运行摘要，耗时趋势只展示最近 7 日节点平均耗时变化、样本、问题提示和关联运行摘要，不展示坐标、路径或底层 payload；耗时节点整行可进入“看记录”，耗时趋势行提供“看记录”入口，两者只按 Runtime 关联 run id 筛选当前 Recent Runs，不读取截图、不写回 evidence；耗时趋势进入关联记录后会展示跨时间深挖摘要 MVP，只从 Runtime 趋势点派生峰值日、峰值耗时、问题日、最近样本日和每日样本块，不读取单次运行详情、不读取截图、不展示 run id；Recent Runs 支持 All、Issues、Failed、Paused、Completed 本地视图筛选，并支持按 workflow 名称、状态和 run id 进行本地搜索，还可复制当前筛选/搜索后的可见记录脱敏摘要；该复制只读取当前 UI 列表，不读取运行详情或截图，不包含 run id、路径、设备、session、端点或原始 WebDriver payload；关联运行筛选会展示本地深挖摘要 MVP，压缩呈现影响流程数、问题数、完成数、最近发生时间和关联流程名；关联运行筛选也会展示跨运行对比摘要 MVP，压缩呈现完成、失败、暂停、已停分布、最近连续问题、最近变化和脱敏状态时间线；这两类摘要都只读取当前已筛出的运行摘要，不读取详情、不读取截图、不写回 Runtime run history 或本地 evidence；筛选枚举、标签、颜色、搜索和关联记录过滤统一归属 `shared/monitor_status_helpers.dart`，运行记录 UI 已拆为 `monitor_history.dart`、`monitor_history_filters.dart`、`monitor_history_metrics.dart`、`monitor_history_rows.dart`、`monitor_history_copy.dart`、`monitor_drilldown.dart`、`monitor_run_compare.dart`、`monitor_run_compare_model.dart`、`monitor_duration_drilldown.dart` 和 `monitor_duration_drilldown_model.dart`，分别承载入口说明、筛选/搜索/关联提示、KPI 网格、记录行/详情入口、可见摘要复制文本、关联运行深挖摘要、跨运行对比展示、跨运行对比摘要派生、耗时趋势深挖展示和耗时趋势摘要派生；筛选和搜索只影响当前 UI 展示，不改变 Runtime run history 或本地 evidence 真源；Issue Categories 从最近本地 run detail 的 Issue Analysis 派生，用于聚合 Paused、Low Confidence、Timeout、Driver Error 等问题类型，并携带最多 6 条脱敏关联运行摘要，不接入云端遥测；Run Detail 以 Issue Analysis 解释问题节点、问题原因、节点耗时和本地截图证据引用，以 Visual Evidence Chain 展示视觉判断规则、截图状态、置信度、动作和原因，以 Execution Path Summary 汇总总步骤、完成步骤、问题步骤、截图证据数量和最慢节点，并以 Evidence Filmstrip 汇总截图证据索引；Run Detail 已提供截图回放 MVP，用户 Reveal 后才显示“第 N/M 张”索引和上一张/下一张控制，切换时仍通过 Runtime 读取本地相对 evidence 缩略图；Run Detail 可复制脱敏诊断摘要，内容只包含流程、状态、轮次、问题类型、问题节点、原因、路径计数、截图数量和视觉检查次数，不包含截图画面、evidence 路径、设备标识、WDA endpoint、session 或底层 WebDriver payload；Run Detail 的 Related Events 读取同一 `RunDetail.events` 本地事件流，并支持 All、Nodes、Issues、Screenshots 本地筛选，只改变当前详情视图，不改变运行事件、运行历史或 evidence 真源；Run Detail 的节点路径支持 All、Issues、Screenshots 本地筛选，只改变当前详情视图，不改变节点 trace、运行历史或 evidence 真源；截图画面默认不展示，必须由用户主动 Reveal 或开启本地 `Reveal Screenshots By Default` 偏好后才读取本地 evidence 缩略图；`paused` 是等待人工介入的 warning 状态，不等同于失败。

Run Detail 的 Sub Workflow 事件传参摘要由 Runtime detail model 解析后交给共享 Monitor helper 展示。界面只显示字段名和数量，不显示参数值，也不在 Widget 内解析原始 JSON。Run Detail 的问题分析、节点路径、证据胶片和相关事件必须复用共享短中文节点类型 helper，不直接显示 `condition`、`snapshot`、`visualBranch`、`subWorkflow` 等 Runtime 枚举。Monitor 用户可见节点名必须优先使用用户标签，缺失时回退短中文节点类型或安全兜底词，不得把 `nodeId` 当作 Timeline、Related Events、Evidence Filmstrip、截图回放、问题分析、路径摘要、耗时节点、耗时趋势或复制摘要的兜底可见文案；`nodeId` 只用于内部 key、筛选关联、Source/DSL 定位和 evidence 查找。

Monitor Related Events 已继续按入口、筛选和事件行拆分：`monitor_related_events.dart` 只承载面板状态和区域装配，`monitor_related_event_filters.dart` 只承载 All / Nodes / Issues / Screenshots 本地筛选，`monitor_related_event_row.dart` 只承载单条事件脱敏展示。新增事件展示能力必须先判断属于区域装配、筛选控件、事件行还是 shared helper，不得重新堆回单个大文件。

Run Detail 当前已增加处理建议 MVP。`monitor_detail_recommendation.dart` 只负责展示建议，`monitor_detail_recommendation_model.dart` 只负责从 `RunFailureAnalysis`、`RunDetailMetrics` 和视觉证据摘要派生建议。建议文案只提示先看画面、补截图、查等待、重连手机或人工确认；它不读取截图画面、不触发设备动作、不进行 AI 自动修复，也不展示节点 ID、路径、设备、session、端点或底层 payload。

当前 Monitor 共享 helper 已按低耦合边界拆分：`monitor_status_helpers.dart` 只保留路由说明，问题分类和原因文案归属 `monitor_analysis_helpers.dart`，Recent Runs 筛选、搜索和关联记录归属 `monitor_history_filter_helpers.dart`，Run Detail 事件 / 节点轨迹摘要归属 `monitor_event_trace_helpers.dart`，趋势窗口数据、短标签、日期和柱间距归属 `monitor_trend_helpers.dart`。Monitor Detail 节点时间轴已按装配、筛选、单行证据读取和空态拆为 `monitor_timeline.dart`、`monitor_timeline_filter.dart`、`monitor_timeline_row.dart` 和 `monitor_empty_states.dart`；时间轴装配不直接读取截图，筛选条不直接读取 Runtime，单行证据读取只在用户 reveal 或本地偏好允许时触发。Runtime evidence 聚合也已拆分：运行级日趋势归属 `evidence_store_run_aggregations.dart`，节点耗时归属 `evidence_store_duration_aggregations.dart`，问题分类和失败聚类归属 `evidence_store_issue_aggregations.dart`；旧入口文件只做职责说明。后续新增 Monitor 或 evidence 聚合逻辑必须落到对应分片，不得回填综合 helper。

当前 V2.0 Dashboard 已接入 Runtime snapshot，展示本地工作站健康摘要、Connected Devices、Workflows、Today Runs、Success Rate、Recent Workflows 和 Activity Trend；KPI 可跳转到对应模块。Dashboard 的健康摘要、Workflow KPI、Workflow Summary Drawer 和进入 Execute 的入口必须复用项目级 workflow 校验；缺失子流程或自引用时，进入 Execute 的快捷入口禁用，并在详情抽屉展示短中文原因。Recent Workflows 已提供 Project DSL 摘要、只读 Workflow Summary Drawer、打开 Workflow 和进入 Execute 的本地工作站入口，并支持收藏当前流程、复制当前流程为副本、删除当前流程并回到 A-F 基础模板；收藏只写本机 Settings，复制和删除都必须通过 Dart Runtime、Project DSL Store 和 validator，运行中不可复制或删除。这些入口不触发设备连接、不启动 Appium、不执行任务。Dashboard 详情只展示友好的入口节点名称和中文运行状态，不展示底层 session、WDA endpoint、坐标、原始入口节点 ID、英文运行状态或完整设备标识。

当前 V2.0 Device Center 已接入 Runtime snapshot，展示设备摘要、Local Readiness Guide、主连接操作、辅助按钮和设备预览；Local Readiness Guide 覆盖 Appium Service、USB Device、Developer Trust、WDA Session、Safe Capture 和 Workflow DSL，并为每项展示状态、说明和下一步动作，其中 Workflow DSL 必须复用项目级 workflow 校验，不直接信任基础 `workflowIsValid`。Device 预览已支持在 connected 且 idle 时基于当前截图执行点击、双击、长按、拖动 swipe、滚轮滚动、方向键滑动、手机双指缩放和当前焦点文本输入；UI 只发送归一化屏幕意图或输入意图，Dart Runtime 通过 Appium `window/rect` 获取 viewport 尺寸后换算为 WDA viewport tap / double tap / long press / swipe / pinch，并在动作后释放 pointer actions；手机双指缩放与本地显示缩放分离，前者是受控设备手势，后者只改变截图查看比例；输入能力只记录输入长度和结果，不在日志或证据中写入明文；运行中、未连接或无截图时预览手势锁定，运行中或未连接时文本输入锁定。Device 页主操作是“连接设备”：Runtime 串行完成本机检查、必要时弹出 Mac 密码并启动 Appium XCUITest 本机隧道、准备 Appium 驱动和创建手机会话；密码只写入 `sudo` stdin，不保存、不进入事件、日志或 evidence；如果点击前快照误判本机隧道已就绪，但 Runtime 刷新后发现仍需要密码，连接按钮必须在同一次点击流程内补弹 Mac 密码框并继续连接，不要求用户再点一次。查环境、指引、停止驱动、重绑、断开和截图都是辅助动作；连接、断开、驱动启动停止或运行处理中会禁用可能打断状态机的辅助动作，避免用户在一键连接中反复停止或重绑。Runtime 会在 `StudioRuntimeSnapshot.appiumOwnership` 中区分应用受控驱动和外部已存在驱动；外部驱动可复用，但“停止驱动”必须禁用或返回“外部驱动未停止”，不得把未接管的 Appium 进程误报为已停止。Device 页还提供 Check Local Stack，调用 Dart Runtime 的 `LocalDependencyChecker` 刷新 Appium CLI、Xcode CLI、iOS Device Tools、本机隧道和 WDA Prerequisites 诊断结果，写入 `StudioRuntimeSnapshot.dependencyReport`；成功命令可提取短版本/详情摘要，但必须裁剪并脱敏本机路径，只进入 Advanced Drawer。Device 页已提供 Local Setup Guide Advanced Drawer，只读展示 Appium、Xcode、USB Tools、本机隧道、WDA 和 iOS Trust 的本机准备指引；当本机隧道处于提醒或错误态时，Advanced Drawer 只提供复制启动命令动作作为高级备用，不自动执行命令、不请求权限、不调用 Runtime。该 Drawer 不自动安装、不签名、不绕过系统信任、不调用 Legacy Node，不展示完整路径、完整设备标识、WDA endpoint 或原始 WebDriver payload。

当前本机隧道在 V2.0 UI 中特指 Appium XCUITest 真机会话所需的 tunnel-creation 进程，不再把 pymobiledevice3 remote tunneld 当作 WDA 会话就绪依据。Dart Runtime 启动 Appium 进程时默认让 XCUITest driver 优先使用 devicectl 发现真机；iOS 18 及以上真机配置必须携带平台版本，确保 XCUITest driver 进入 RemoteXPC 路径。连接设备流程会先尝试用 `xcrun devicectl` 对齐当前唯一 USB 手机，过滤 localNetwork 设备；当发现当前 USB 手机与本地配置不一致时，Runtime 会自动写回项目配置、同步 session / tunnel 配置并继续连接；当只发现无线可用手机而没有 USB 手机时，Runtime 会停止一键连接并提示使用数据线连接，不继续拿旧配置硬连。任何创建手机会话的入口，包括一键连接后的内部重连和直接重连，都必须在发送 `/session` 前再次确认当前唯一 USB 手机并同步 session 配置；无法确认时直接进入“未找到 USB 手机”错误态，不把旧 UDID 交给 Appium；若配置里出现脱敏或示例设备占位符，Runtime 必须在会话前硬拦截，缺少有效当前手机绑定时也必须阻断，不允许去掉 UDID 后继续请求 Appium，也不能让占位符进入 Appium 请求。启动 Appium XCUITest 隧道后必须等待目标手机出现在 tunnel registry；只有 tunnel-creation 进程但 registry 为空时不能继续创建 `/session`，应先进入“等待手机允许”中间态；若等待超时且该隧道不是当前 Runtime 持有的受控进程，Runtime 可在同一次密码授权内清理旧 tunnel-creation 进程并启动新的受控隧道。若 registry 或会话显示 Appium 看不到目标手机，Runtime 可在仅识别到一台 USB 手机时自动重绑并重跑连接链路一次；若绑定手机已确认但 Appium 仍不可见该设备，Runtime 可重置当前端口的旧驱动并重试一次：受控 Appium 走正常停止，外部旧 Appium 只按当前 host/port 精准清理主服务，不匹配 tunnel-creation；最终失败时提示“驱动未识别手机”和“保持解锁，点连接设备。仍失败就重插线。”；若受控 Appium 创建会话时出现 `socket hang up`、`could not proxy command` 或 `port 8100` 等 WDA 代理瞬时断开，Runtime 可自动停止受控驱动、重新准备并重试一次；`xcodebuild failed with code 65`、证书信任和 USB 问题不得自动重启；无法唯一确认 USB 手机时，界面统一提示“未找到 USB 手机”和“用数据线连接一台手机并解锁，再点连接设备”，不展示绑定、UDID 或 session 细节。重绑入口仍由 Dart Runtime 负责，写回本地项目配置后同步当前 Runtime session / tunnel 配置，不调用 Legacy Node init，也不需要重启应用。连接诊断已覆盖 RemoteXPC 隧道缺失、tunnel registry 为空、无线非 USB 连接、无效设备占位符、外部旧驱动残留和设备未被驱动识别，所有详情都必须脱敏；设备未被驱动识别的详情不得显示脱敏占位符，统一收敛为“本机驱动没有看到当前手机”。

Dart Runtime 已区分 Appium 健康检查和手机会话创建：`/status` 继续使用短外层超时，避免连接设备卡住；`/session` 使用项目配置里的长请求超时，以等待 WDA 构建、安装和启动。需要 RemoteXPC 的设备在本机检查已发现隧道缺失时，会在“连接设备”流程中先请求 Mac 密码并受控启动隧道，不再让用户手动打开终端。

当前 Runtime 连接诊断已从普通异常文本中拆出独立分类，并结构化写入 `StudioRuntimeSnapshot.lastConnectionDiagnostic`：手机未信任证书会进入 `waitingForDeveloperTrust`，手机锁定、驱动未就绪、本机隧道未就绪、USB 设备不可用、WDA 构建失败、WDA 会话未启动和未知错误会进入可操作错误态。`xcodebuild failed with code 65`、签名和描述文件相关错误统一归类为“手机会话构建失败”，只提示用户打开 Xcode 处理签名后重试，不自动重启驱动、不绕过系统限制。Device、Execute、Top Status、Command Center 和 Bottom Console 必须消费同一 Runtime snapshot 中的短中文摘要、下一步动作和脱敏事件，不直接展示原始 Appium / Xcode / WebDriver 长日志，也不得各自从原始异常文本重新分类；诊断详情必须裁剪并脱敏完整设备标识、本机路径、本地端点、session 和底层 payload。Legacy CLI 的 `click:connected` 也复用同一 Node 诊断分类器输出下一步动作，但仍只作为调试入口，不成为 V2 主入口。

当前 Legacy 初始化和点击 CLI 的用户可见日志已改为短设备标识；普通 `progress` 模式下 WebDriver 客户端日志保持静默，只展示项目内收敛后的短诊断，避免把本机路径、完整设备标识或底层堆栈写入终端。需要底层 Appium / WebDriver 调试时再显式使用 `verbose`。

当前 V2.0 Device 页面已按页面骨架、设备摘要、就绪检查、操作区、目标库、本机指引和预览继续拆分。`device_page.dart` 只组合左右栏和页面级 `canCapture` 状态；`device_summary.dart` 只承载设备摘要、连接诊断卡和短事实行；`device_readiness.dart` 只承载 Local Readiness Guide 展示；`device_actions.dart` 只承载驱动/环境/连接/截图按钮和本机指引抽屉入口；`device_target_library.dart` 只承载目标库摘要、当前截图中心建目标入口和最近目标列表，写入必须调用 Runtime target commands；`device_setup_guide.dart` 只承载 Advanced Drawer 指引内容；`shared/connection_diagnostic_card.dart` 承载 Device 和 Execute 复用的连接失败短诊断卡，只展示原因和下一步，并提供“复制诊断”的脱敏摘要入口；`shared/readiness_widgets.dart` 承载跨 Device、Execute 和 Recorder 复用的就绪卡片、内联步骤和三态就绪行。Device Preview 动作已继续按设备命令、点击、滑动、键盘滑动和动作 helper 拆分：`device_preview_actions.dart` 只保留路由说明，`device_preview_device_commands.dart` 只承载主页键、当前焦点输入和手机双指缩放，`device_preview_tap_actions.dart` 只承载单击、双击和长按，`device_preview_swipe_actions.dart` 只承载滚轮、拖动和 Runtime swipe 发送，`device_preview_keyboard_actions.dart` 只承载方向键到受控手机滑动的映射，`device_preview_action_helpers.dart` 只承载坐标换算、显示缩放写入和键盘焦点。后续 Device 新能力必须先判断是摘要、就绪、操作、目标库、指引、预览、预览动作还是 shared 组件，不得重新堆回 `device_page.dart` 或 `device_preview_actions.dart`。

共享连接诊断卡展示 USB 连接问题时，用户侧短标签统一为“USB”，下一步使用“用数据线连接一台手机并解锁”这类动作句；展示驱动未识别当前手机时，短标签统一为“驱动”，下一步使用“保持解锁，点连接设备。仍失败就重插线。”；不得展示 `localNetwork`、`transportType`、完整设备标识、`[device]` 脱敏占位符或 Appium 原始错误。诊断卡的“复制诊断”只输出短中文问题、状态、下一步、脱敏详情和本机边界摘要，不包含本机路径、本地端点、完整设备标识、完整 session 或原始 WebDriver payload。脱敏占位统一使用中文短词，如“[标识]”“[本机路径]”“[本机地址]”，避免用户误以为占位符就是设备配置值。Device、Execute 和状态详情应复用该标签和图标映射，不各自维护连接问题文案。

Device Readiness 的“手机会话”项在错误态必须优先消费 Runtime 的 `lastConnectionDiagnostic`，使用同一摘要、下一步、短标签、图标和色调。不得在就绪检查里继续展示泛化的“查看控制台里的构建或签名指引”，导致与设备摘要诊断卡或 Execute 页面不一致。

当前 V2.0 Device Preview 已拆为状态协调、动作发送、坐标换算、预览舞台、头部组合、主页键控件、输入控件、手机缩放控件、显示缩放控件和覆盖层分片。`device_preview.dart` 只保留生命周期、截图尺寸解析和布局装配；`device_preview_actions.dart` 只承载点击、双击、长按、滚动、拖动、方向键滑动、输入、受控双指缩放、显示缩放和 Runtime 调用，并通过 State 私有入口统一写入交互状态；方向键到滑动轨迹的映射集中在动作分片的私有枚举和只读参数中，避免重复坐标散落；`device_preview_geometry.dart` 只承载截图显示区域与归一化坐标换算；`device_preview_stage.dart` 只承载手机外框、截图、手势绑定、键盘焦点和覆盖层组合；`device_preview_controls.dart` 只承载头部状态和控件装配；`device_preview_button_controls.dart` 只承载受控主页键按钮；`device_preview_input_control.dart` 只承载当前焦点文本输入；`device_preview_pinch_controls.dart` 只承载手机双指缩放按钮；`device_preview_zoom_controls.dart` 只承载本地显示缩放工具；`device_preview_overlays.dart` 只负责准星、滑动轨迹和空态。后续 Device 预览增强必须进入对应分片，展示控件不得直接调用设备动作。

当前 Runtime 设备预览命令已继续按公开动作类别拆分：`runtime_device_preview_commands.dart` 只保留路由说明，`runtime_device_preview_capture_commands.dart` 只承载截图，`runtime_device_preview_tap_commands.dart` 只承载点击、双击和长按，`runtime_device_preview_gesture_commands.dart` 只承载滑动和双指缩放，`runtime_device_preview_input_commands.dart` 只承载当前焦点输入和受控主页键；`runtime_device_preview_helpers.dart` 只承载 connected + idle + session 校验、视口坐标校验、时长校验、pinch 坐标构造和 actions 释放。预览 Tap 失败时仍必须释放 pointer actions，并由 `device_session_test.dart` 覆盖；后续新增预览命令必须先判断属于截图、点击、手势、输入还是 helper，不得在每个命令里复制前置规则。

当前 V2.0 Recorder 已升级为 Recorder Workbench，包含 Recorder Controls、Live Capture、Session Summary 和 Action Timeline；Live Capture 只通过 Dart Runtime 采集截图，且只在设备 connected 与运行 idle 时启用；未连接时 Session Summary 会复用共享一键连接主按钮，提交同一条 Dart Runtime 连接链路，不让用户回到 Device 页寻找入口。录制中点击预览画面只生成本地 Tap 动作，拖动预览画面只生成带起点、终点和方向摘要的本地 Swipe 动作，二者都不直接执行设备动作；预览点选坐标优先按当前 PNG 截图尺寸换算，尺寸未解析完成时不开放预览录制，尺寸解析失败时才使用安全兜底尺寸；Recorder 本地动作入口已覆盖 Tap、Wait、Swipe 和 Input，Input 动作主时间线只展示“输入文本/当前焦点”等摘要，不展示明文，文本只在 Action Detail Drawer 中编辑，并在生成流程时进入 Project DSL Input 节点。时间轴默认隐藏坐标，只用“有图/无图”表达动作是否绑定当前预览截图，Tap 坐标和 Swipe 起终点只在 Action Detail Drawer 展示；时间线支持本地上移、下移、复制、删除和复制脱敏动作摘要；整理结果只改变本地动作列表，不执行设备动作，不删除截图证据，生成流程时才进入 Project DSL；动作摘要只包含动作类型、标签、等待和有图/无图，不包含坐标、输入明文、截图内容、本机路径或设备标识。动作详情可编辑名称、目标、等待、时长、坐标和输入文本等核心参数；Tap 坐标使用“横向 / 纵向”，Swipe 路径使用“起横 / 起纵 / 终横 / 终纵”和“从 A 到 B”摘要表达，不直接展示 `ID`、`X`、`Y` 调试字段名；保存后只更新本地录制动作，生成流程时才通过 Runtime 写入 Project DSL；生成流程成功后 Recorder 提供“看流程”和“去运行”导航入口，二者只切换到 Workflow 或 Execute 页面，不自动启动运行、不连接设备、不绕过 Runtime 校验；动作详情已绑定当前预览截图证据，默认只展示证据摘要，用户主动点击“显示截图”后才在内存中渲染截图；录制截图不写入 Project DSL、不落盘、不展示本机路径或设备标识。Recorder 已按页面协调、动作路由、录制控制、时间线整理、动作捕获、流程生成、详情抽屉、控制区、设备预览、会话摘要、动作摘要复制、详情头部、详情字段区、字段编辑、证据预览、动作模型和 Project DSL 转换拆分；`recorder_page.dart` 只协调录制状态、动作列表和响应式布局，State 内只保留录制状态、流程生成状态和动作列表写入入口；`recorder_page_actions.dart` 只保留动作分片入口说明，不承载具体命令；`recorder_recording_actions.dart` 只承载开始和停止录制；`recorder_timeline_actions.dart` 只承载清空、上移、下移、复制、删除和复制脱敏摘要；`recorder_capture_actions.dart` 只承载快捷动作、预览比例坐标到本地动作转换、截图证据绑定、录制坐标基准和本地动作 ID；`recorder_workflow_actions.dart` 只承载 Promote 和生成后的页面导航；`recorder_detail_actions.dart` 只承载动作详情抽屉和本地草稿保存；控制区只承载按钮入口；设备预览继续拆为 `recorder_device_stage.dart`、`recorder_preview_header.dart`、`recorder_preview_target.dart` 和 `recorder_preview_empty.dart`，分别承载舞台装配、预览状态与截图入口、比例坐标捕获与本地拖动轨迹、无截图空态；会话摘要只承载录制前检查和共享连接入口；Action Timeline 继续拆为 `recorder_timeline.dart`、`recorder_timeline_header.dart`、`recorder_timeline_empty.dart`、`recorder_timeline_row.dart`、`recorder_timeline_button.dart` 和 `recorder_timeline_copy.dart`，分别承载列表外壳、头部状态与复制入口、空态、动作行、行内整理按钮和脱敏复制文本；详情抽屉只持有编辑草稿和保存归一化，详情头部只承载标题、保存和关闭入口，详情字段区只承载坐标、时间、输入和证据摘要展示，字段编辑分片只承载输入控件和安全归一，证据预览分片只承载 reveal 和内存截图展示；Recorder 动作模型继续拆为 `recorder_action_type.dart`、`recorder_action_evidence.dart`、`recorder_action_model.dart` 和 `recorder_action_summary.dart`，分别承载动作类型与状态色、内存证据绑定、最小动作数据、短中文摘要和隐私展示边界；`recorder_workflow_builder.dart` 只负责把录制动作转换为 Project DSL。

Recorder 动作内部 ID 只用于本地列表 key、排序、复制和 Project DSL 转换，不作为用户可见字段展示；动作详情顶部使用动作类型和目标摘要帮助用户确认，不暴露 `recorded_xxx` 这类内部标识。

当前 V2.0 Execute 已升级为运行控制台，展示 Run Configuration、Preflight、Command Center、Execution Summary、Runtime State、Last Run Evidence 和精简 Execution Timeline；Run Configuration 当前支持“单次 / 循环 / 持续”三种用户可理解模式，单次固定 1 轮，循环使用步进器设置有限 N 轮，持续模式映射为最多 999 轮的受控安全运行，三者都调用 Dart Runtime 的 `runCurrentWorkflow(loops: 有限整数)`，不引入无边界无限循环或第二套执行体系；Runtime 也会拒绝超过 999 轮的直接调用。Execute Preflight 和运行按钮已复用 Workflow 页同一项目级校验模型，合并 DSL 结构校验与本地 Sub Workflow 引用校验；缺失子流程、嵌套缺失、自引用或循环引用会在运行按钮层禁用，并展示短中文原因，不等用户进入确认弹窗或 Runtime 执行后才发现；当存在多条流程问题时，Preflight 主面板只显示首条摘要和问题数量，完整清单通过“查看 N 项”弹窗展示，仍然只消费同一校验结果。Execute 复用 Device 的一键连接主操作，未连接或连接受阻时可在运行页直接提交同一条 Dart Runtime 连接链路；连接处理中运行按钮和连接按钮都锁定，避免用户在执行前重复触发连接。Execute 只有一个主启动按钮，点击后必须先打开 Confirm Execution Modal，展示 workflow、模式、loops、节点数、串行执行和安全停止边界，持续模式还会展示安全上限，用户取消时不触发 Runtime，确认后才调用 `runCurrentWorkflow`；确认弹窗里的流程状态也使用项目级校验，不直接信任基础 `workflowIsValid`。Execution Summary 使用 Dart Runtime 暴露的 `RuntimeExecutionFocus` 展示当前循环、当前节点、完成步数、总步数、预计剩余时间和失败或暂停节点，UI 不自行推断执行进度；Last Run Evidence 从本地 `RunHistorySummary.recentRuns` 取最近运行，并通过 Dart Runtime 读取同一个 Run Detail Drawer；Execution Timeline 只展示最近 Runtime 事件摘要，用于执行页内快速判断，不替代底部 Console 的完整诊断；执行、停止和暂停收口仍只调用 Dart Runtime，不调用 Legacy Node API；`paused` 人工介入态通过 Runtime `resolvePause()` 显式收口回 `idle`，只清除 active 节点和循环上下文，保留失败/暂停节点焦点，不继续执行后续点击、不隐式跳过视觉判断；主界面不展示完整设备标识、完整 session、WDA endpoint 或原始 WebDriver payload。

当前 V2.0 Execute UI 代码已按页面入口、运行配置、基础控件、运行前检查、命令区、运行确认、主按钮、摘要装配、焦点进度、运行事实、最近证据和事件线拆分。`execute_page.dart` 只组合左右栏和详情打开动作，`execute_configuration.dart` 只承载单次/循环/持续模式和流程摘要，`execute_controls.dart` 只承载有限轮次步进器，`execute_readiness.dart` 只承载 Preflight，`execute_command.dart` 只承载启动、连接、停止和暂停收口命令面板，`execute_confirmation.dart` 只承载运行确认弹窗、确认事实行和确认后 Runtime 提交，`execute_primary_button.dart` 只承载高优先级主按钮样式与异步入口，`execute_summary.dart` 只承载摘要装配，`execute_summary_focus.dart` 只承载进度与执行焦点，`execute_summary_runtime.dart` 只保留运行态分片路由说明，`execute_summary_facts.dart` 只承载 Runtime State，`execute_summary_latest_run.dart` 只承载 Last Run Evidence 入口，`execute_summary_timeline.dart` 只承载精简 Execution Timeline。Device 和 Execute 共用 `shared/connect_primary_action.dart` 的一键连接主按钮，连接提交流继续归属 `shared/device_connect_action.dart`；后续连接文案、禁用规则或密码弹窗只改共享分片，不得在页面内复制。后续执行能力应进入对应分片，不得把确认弹窗、运行事实、证据入口、事件线或暂停处理重新堆回单个页面大文件。

当前 V2.0 Bottom Console 已作为全局常驻诊断区接入 Runtime snapshot，支持日志 / 错误 / 检查 / 网络 / 调试分区、复制当前分区、清空当前可见事件，以及全部 / 信息 / 提醒 / 错误级别筛选。Network 分区只展示本机驱动通道的只读摘要，包括通道、协议、驱动、手机、短会话和脱敏消息；用户可见文案使用“本机驱动”，不直接显示 `Appium / WDA`；它不发起网络请求、不调用 Legacy Node、不展示 endpoint、本机路径、完整 session 或原始 WebDriver payload。Console 可复制内容与可见级别均使用中文标签，不直接显示 `INFO`、`WARNING` 或 `ERROR`；级别筛选只影响 Console 当前视图和复制内容，不改变 Runtime event stream、本地 evidence、run history 或截图证据。

当前 V2.0 Settings Drawer 已作为 Side Nav 辅助入口接入，展示 Workstation、Runtime、Privacy 和 Boundaries 摘要；Settings 真源是本地 `StudioSettings` JSON，当前已支持 Evidence Retention 和 Reveal Screenshots By Default 的受控更新，并由 Dart Runtime 应用到本地 evidence 滚动清理与 Run Detail 截图默认展开行为；Evidence Retention 现在同时包含最大运行条数和最大保留天数，Runtime evidence store 会先按最新证据时间清理过期运行目录，再按最大条数兜底清理，UI 不直接删除本地文件。Hide Device Identifier 和 Hide Raw WebDriver Payload 是只读开启的硬隐私约束，Runtime settings 模型会强制归一为开启，不能通过 JSON 或调用方关闭；Settings 不直接修改 Appium 连接、Workflow 结构或运行状态，也不展示完整设备标识、完整 session、WDA endpoint 或原始 WebDriver payload。

当前 V2.0 Settings Drawer 代码已继续拆分：`settings_drawer.dart` 只承载 Runtime 快照订阅、分区装配和受控设置写入，`settings_drawer_controls.dart` 只承载分区卡片、开关行和步进行的稳定布局。后续新增设置项先判断属于抽屉编排、Runtime 设置写入还是基础控件，不得把通用控件和隐私边界文案重新堆回单个设置大文件。

V2.0 Mac App 用户可见文案默认使用中文，优先短句和短词；主界面避免直接堆叠 Appium、WDA、WebDriver、session 等专业词，统一以“驱动”“手机会话”“连接”“流程”等用户可理解表达承载。可见状态、节点类型、控制台级别、上下文预览、Runtime 事件、运行详情和视觉证据原因不得直接显示底层英文枚举或英文运行句；必要技术细节进入控制台、抽屉或源码视图，源码视图里的 Project DSL 字段名保持英文以保证真源兼容。

V2.0 技术路线正式采用 Flutter Desktop Mac App。主入口是 `apps/studio_mac`，Dart Runtime 直接管理 Appium 进程并通过 Dart Appium / WebDriver Client 调用 Appium。V2.0 不新增自建 Node 中间 API 层，不允许 Flutter App 调用当前 Node Web Console 或 Node Runner 服务。

V2.0 Mac App 的 Debug / Profile entitlement 允许关闭 App Sandbox，以满足本地工作站读取项目配置、写入本地证据和启动本机驱动进程的开发需求；Release 若保持沙盒，必须通过用户选择项目目录和系统授权恢复同等能力。项目配置发现失败必须区分“未找到”和“不可读”：未找到时提示设置项目根目录，不可读时提示应用无法读取项目配置，避免把沙盒或权限问题误导为驱动工具缺失。

当前 `apps/studio_mac/lib/main.dart` 已进一步收敛为 Flutter 启动引导；`apps/studio_mac/lib/studio_mac.dart` 是 Flutter App 的公开 Dart 库入口，启动脚本、测试和后续集成统一从这里导入 `StudioMacApp`，不得直接依赖 `src/` 私有路径。当前阶段的工作区库边界位于 `apps/studio_mac/lib/src/studio_mac_workspace.dart`，负责承载仍需共享私有上下文的 UI 分片和 `part` 路由，避免入口文件继续承担工作区依赖。Flutter App 根组件位于 `src/app/studio_mac_app.dart`，Shell 生命周期和命令中心动作位于 `src/shell/studio_shell.dart`；顶部状态栏、Global Command Center、状态详情抽屉、侧栏导航、Settings Drawer 和 Workspace 调度分别位于 `src/shell/top_status_bar.dart`、`src/shell/command_center.dart`、`src/shell/status_detail_drawer.dart`、`src/shell/navigation.dart`、`src/shell/settings_drawer.dart` 和 `src/shell/workspace.dart`。Bottom Console 已按外壳、控件、内容视图和文案 helper 拆为 `src/shell/bottom_console.dart`、`src/shell/bottom_console_controls.dart`、`src/shell/bottom_console_views.dart` 和 `src/shell/bottom_console_text.dart`；外壳只协调展开、标签、筛选、复制和清空，控件只承载 tab/filter 按钮，内容视图只承载日志/错误/检查/网络/调试展示，文本 helper 只承载事件级别、脱敏短中文和复制文本。具体 UI 通过 Dart `part` 拆入 `apps/studio_mac/lib/src/`：`shell/` 承载顶部状态、导航、命令中心、设置、工作区和底部控制台，`features/` 承载 Dashboard、Device、Recorder、Workflow、Execute 和 Monitor，`shared/` 承载跨页面状态 presenter、状态色、文案、格式化 helper、普通文本复制反馈、Runtime 节点短中文名和 App 私有兼容壳；基础 `StudioSurface` 与 `StudioInsetSurface` 的真实视觉实现归属 `packages/studio_design_system`，页面不得重复定义同类面板样式；App 侧紧凑状态色卡片统一使用 `_ToneBorderSurface`。Shell 文件不得重新混放命令中心弹窗、状态详情抽屉和 Bottom Console 子视图；状态栏只负责摘要入口，命令中心只负责命令搜索和执行，命令中心导航只调用 Shell 自身导航方法，不在 actions 分片直接修改 Shell 状态；状态详情抽屉只负责只读详情展示，连接、驱动和运行状态展示映射统一归属 `shared/status_presenters.dart`，Bottom Console 外壳不直接堆叠事件文案翻译或所有标签内容。普通文本复制统一通过 `shared/clipboard_helpers.dart` 写入剪贴板和展示轻提示；各 feature 只负责生成自己的脱敏文本，画布私有节点剪贴板协议仍由 Workflow 系统剪贴板分片独立维护。Dashboard 已按页面入口、摘要/KPI、最近流程、流程详情抽屉和活动趋势拆分；`dashboard_page.dart` 只组合 Runtime snapshot 派生出的页面区域和导航动作，`dashboard_summary.dart` 只承载健康摘要、运行路径和 KPI 卡片，`dashboard_recent_workflow.dart` 只承载最近流程面板装配，`dashboard_recent_workflow_actions.dart` 只承载收藏、复制和删除等本机 Runtime 动作，`dashboard_recent_workflow_row.dart` 只承载流程摘要行和行内按钮，`dashboard_workflow_detail.dart` 只承载只读流程详情 Drawer，`dashboard_activity.dart` 只承载本地活动趋势。Workflow 已继续按页头工具栏、Visual 页签、页面状态 helper、历史动作、模板动作、Source 动作、节点动作、连线动作、剪贴板落盘动作、选区动作、子流程动作、模板模型、模板定义、模板抽屉、模板卡片、节点库、画布主体、画布视口动作、画布拖拽动作、画布连线动作、画布选择动作、画布控制、画布导航、连线工具、Mini Map、Painter、节点行、Source、历史控制器、Inspector、Inspector 编辑器和 helper 拆分；Workflow 页面主类只保留 Source/Visual/Validate 选中态、保存态、选区和布局编排，图编辑命令必须进入对应 actions 分片：状态 helper 只承载锁定和草稿监听，历史动作只承载 DSL 更新、撤销/重做，模板动作只承载模板导入，Source 动作只承载源码和节点草稿保存，节点动作入口只保留路由说明，`workflow_page_node_insert_actions.dart` 只承载 Inspector / 画布菜单 / 节点库插入，`workflow_page_node_mutation_actions.dart` 只承载单选和多选复制删除，`workflow_page_node_layout_actions.dart` 只承载节点拖拽位置保存和 Auto Layout，连线动作只承载边上插入、连线增删和重接起点/目标，剪贴板落盘只承载本地剪贴板写回 DSL，选区动作只承载快捷键、选中态和校验定位；`workflow_template_model.dart` 只承载模板模型，`workflow_template_library.dart` 只承载本机模板定义，`workflow_template_drawer.dart` 只承载模板抽屉，`workflow_template_card.dart` 只承载模板卡片和统计胶囊；`workflow_canvas_viewport_actions.dart` 只承载缩放、适配、聚焦和坐标换算，`workflow_canvas_drag_actions.dart` 只承载节点拖拽临时态和提交，`workflow_canvas_connection_actions.dart` 只承载端口点选、拖拽连线和端口命中，`workflow_canvas_selection_actions.dart` 只承载框选、边命中、边删除和自动整理入口；`workflow_visual_tab.dart` 只承载 Visual 页签的节点库、画布主体和画布快捷键绑定；页头工具栏只承载状态、标题、撤销/重做、节点新增、模板和复制源码入口，模板卡片不得直接写 DSL 或触发设备动作，画布控制只承载缩放/框选/自动整理，画布导航只承载节点搜索和定位，连线工具只承载连线提示、选边浮层和画布本地剪贴板模型；其中 Workflow helper 已按页面 Tab、图编辑变换、节点文案/图标、连线展示文案和 Source 诊断拆分为独立 part，`workflow_edge_label_helpers.dart` 只负责选中连线标签和分支角色文案，不写 DSL、不触发 Runtime、不展示裸节点 ID；项目级 Workflow 状态判断沉淀在 `shared/workflow_status_helpers.dart`，供 Top Status、Dashboard、Device、Execute、Settings 和 Bottom Console 统一复用。Device、Recorder、Execute、Monitor 已按页面入口、控制面板、预览、详情、时间轴和证据区拆分；Device Preview 已进一步拆为状态协调、动作发送、坐标换算、顶部缩放/输入控件和点击/滑动覆盖层，预览主文件只保留生命周期、截图尺寸解析和布局装配，动作发送进入 `device_preview_actions.dart`；Monitor Overview 已按概览状态、趋势、失败趋势、常见问题、状态分布、问题分类、耗时节点和耗时趋势拆分，`monitor_overview.dart` 只保留共享趋势窗口状态，`monitor_trend.dart` 只承载 7 / 30 / 90 日趋势，`monitor_failure_trend.dart` 只承载 failed / paused / stopped 失败趋势，`monitor_failure_cluster.dart` 只承载本地失败聚类展示，`monitor_distribution.dart` 只承载 completed / failed / paused / stopped 分布，`monitor_issue_category.dart` 只承载本地问题分类，`monitor_metric.dart` 只承载 Monitor 内可复用短指标组件，`monitor_node_duration.dart` 只承载慢节点聚合，`monitor_node_duration_trend.dart` 只承载本地节点耗时趋势；Monitor Detail 已按抽屉壳、摘要指标、问题/视觉分析、诊断摘要复制、证据模块、截图胶片和相关事件拆分，`monitor_detail.dart` 只承载 Run Detail Drawer 外壳和分片组合，`monitor_detail_summary.dart` 只承载运行摘要 chip 和 Execution Path Summary，`monitor_detail_analysis.dart` 只承载 Failure Analysis 和 Visual Evidence Chain，`monitor_detail_copy.dart` 只承载脱敏诊断摘要生成和复制入口，`monitor_evidence.dart` 只保留证据模块边界，`monitor_evidence_filmstrip.dart` 只协调截图索引、reveal 状态和回放切换，`monitor_evidence_filmstrip_card.dart` 只承载单张截图证据摘要卡片，`monitor_evidence_replay.dart` 只承载本地截图回放和前后切换，`monitor_evidence_preview_frame.dart` 只承载 Monitor 证据预览框样式，`monitor_related_events.dart` 只承载 Related Events、本地事件筛选和事件摘要行；状态 helper 已按状态 presenter、详情、准备度、Workflow 状态、运行、监控、Runtime 节点短中文名和格式化拆分，连接/驱动/运行短文案与色调归属 `shared/status_presenters.dart`，跨页面状态胶囊归属 `shared/status_helpers.dart`，Runtime 节点类型文案归属 `shared/runtime_node_label.dart`。后续新增大功能不得继续堆回 `main.dart` 或单个页面大文件；应先判断归属 feature、shell、shared widget、view model 或 package。后续更深拆分应从 `src/studio_mac_workspace.dart` 继续拆出独立 Feature Library，而不是回退到入口聚合。

Workflow 图结构 helper 已继续按查询、布局、节点工厂、剪贴板、剪贴板子图算法、节点编辑、边编辑和边合法性预检拆分。查询只做节点/连线读取，布局只做视觉位置替换，节点工厂只生成默认节点和唯一 ID，`workflow_graph_clipboard_helpers.dart` 只处理复制/粘贴入口和写回结果收口，`workflow_graph_clipboard_subgraph_helpers.dart` 只处理子图组件拆分、入口计算、内部引用重映射和按锚点容量暴露多入口，节点编辑只处理节点插入、删除和 Loop 默认 body 骨架；边编辑入口 `workflow_graph_edge_edit_helpers.dart` 只保留路由说明，`workflow_graph_edge_insert_helpers.dart` 只处理边上插入和 Loop body 骨架接入，`workflow_graph_edge_target_helpers.dart` 只处理新增、删除和改目标，`workflow_graph_edge_source_helpers.dart` 只处理改起点，`workflow_graph_edge_parameter_helpers.dart` 只处理 next 去重替换和 Catch `onError` 写入/清空，`workflow_graph_edge_validation_helpers.dart` 只处理新增连接、改目标和改起点的 Project DSL validator 预检；入口 helper 不得重新承载复制粘贴、唯一 ID、节点插入、节点删除、连线变更、连线候选预检或位置替换算法。删除节点时必须同步修正指向该节点的普通 `next` 和 Catch `onError`：普通前驱接回被删节点后继，Catch 错误分支优先改接被删节点的第一个后继，缺失后继时清空 `onError`；替代后继不得把前驱重新接回自己，且必须按前驱节点可承载的主线数量裁剪，避免删除 Loop 等多出口节点时让 Start、Tap、Wait 等单主线节点生成非法多分支；所有删除结果继续通过 Project DSL validator 保存。Validator 是最终兜底，任何节点 `next` 自引用和 Catch `onError` 自引用都必须保存失败，不能只依赖画布编辑器提前过滤。

当前 Workflow Canvas 节点层已拆入 `workflow_canvas_node_layers.dart`。该分片只负责节点卡片和输入/输出端口渲染，拖拽、选择、点选连线和拖拽连线事件仍交回画布动作分片；节点层不得写 Project DSL，不得触发 Runtime 保存，也不得直接暴露裸节点 ID。

当前 Workflow Canvas chrome 已拆入 `workflow_canvas_chrome.dart`。该分片只负责选择框、框选覆盖层、锁定提示、节点导航、小地图和控制条装配；`workflow_canvas.dart` 继续只承载生命周期、控制器和核心渲染组合。画布 chrome 不得处理节点渲染、连线命中、节点拖拽或 Project DSL 写入，新增叠层先判断是 chrome、节点层、导航、小地图还是动作分片。

当前 Workflow Canvas 连线工具已继续拆分：`workflow_canvas_edge_model.dart` 只承载选中边模型，`workflow_canvas_connection_banner.dart` 只承载连线中的轻提示，`workflow_canvas_edge_candidates.dart` 只承载改起点/改目标候选，`workflow_canvas_edge_toolbar.dart` 只承载插入、重接和删除入口；`workflow_canvas_connection_tools.dart` 仅保留模块边界说明。候选生成必须继续复用图边 validator 预检，不得重新维护一套节点类型规则。

当前 Workflow Source UI 已继续拆分：`workflow_source.dart` 只承载源码编辑区和保存入口，`workflow_source_diagnostics_view.dart` 只承载 Source 草稿诊断列表，`workflow_validate_view.dart` 只承载 Validate 页签校验结果，`workflow_diagnostic_row.dart` 只承载 Source 与 Validate 共用的可点击诊断行。新增诊断入口应复用诊断行组件，不得复制一套图标、位置胶囊和定位文案布局。

当前 Workflow 页面布局已继续拆分：`workflow_page.dart` 只保留页面级状态、生命周期和顶层 build 派发；`workflow_page_layout.dart` 只承载左侧主面板和页头工具栏装配；`workflow_page_tab_content.dart` 只承载画布 / 源码 / 检查的内容切换；`workflow_page_selection_handlers.dart` 只维护节点选区和连线选区互斥关系；`workflow_page_inspector_panel.dart` 只承载右侧 Inspector 选择态映射。布局分片不直接保存 Project DSL、不绕过 Runtime validator。后续新增 Workflow 页面区域时先判断是布局装配、Tab 内容、选择处理、Inspector 装配、页面动作还是具体组件，不得重新堆回页面主文件或单个布局大文件。

当前 Workflow 节点展示 helper 已继续拆分为基础展示、分支展示和执行态展示三类。`workflow_node_helpers.dart` 只维护可插入节点类型、节点库/插入菜单短文案、节点基础摘要、图标和节点类型默认色调；`workflow_node_branch_helpers.dart` 只维护普通 `next` 与 Catch `onError` 的分支摘要、目标短标签和错误分支读取；`workflow_node_execution_helpers.dart` 只维护节点执行态、短标签、前景色和背景色。后续新增节点 UI 文案、分支摘要或运行高亮时必须先判断归属，不得重新堆回单个综合 helper。

当前 Workflow 页面选区动作已继续拆分：`workflow_page_selection_actions.dart` 只负责画布快捷键分派、复制剪切粘贴、选择态清理和 Validate 诊断跳转；`workflow_page_selection_layout_actions.dart` 只负责方向键微调、多选对齐和均分。选区布局动作只写入 `visual.position`，不得改变节点参数、Tap 坐标或边关系。

当前 Workflow 边语义已收敛为统一查询模型：普通 `next` 和 Catch `onError` 都必须通过同一个边 helper 暴露给主画布绘制、边命中、小地图和自动布局。`workflow_canvas_minimap.dart` 只承载小地图外壳和导航交互，`workflow_canvas_minimap_painter.dart` 只承载小地图绘制，`workflow_canvas_layout.dart` 只承载节点尺寸、端口坐标、自动布局和画布尺寸推导。Mini map 必须展示 Catch 错误边，自动布局必须把 Catch `onError` 目标作为可达节点处理；后续新增分支类型应先扩展统一边模型，再让 UI 分片消费，不得在各分片重新手写边遍历。

当前 `packages/studio_runtime/lib/studio_runtime.dart` 已收敛为 Runtime 统一入口，具体实现拆入 `packages/studio_runtime/lib/src/`：模型、依赖探测、Appium 进程、项目配置、会话管理、证据存储、设备动作、workflow/settings/sub-workflow store、Runtime Controller、本地项目命令、执行主体、执行证据、执行规划、节点参数解析、workflow 引用校验和视觉守卫分别维护。Runtime 模型已继续拆为 settings、dependency、run history、run issue、run duration、run failure、run event、run trace、run analysis、run detail、run report、V4 acceptance、execution state 和 execution internal 分片；`runtime_run_history_models.dart` 只承载运行历史基础摘要、单日聚合和总汇总，`runtime_run_issue_models.dart` 只承载问题分类和关联运行摘要，`runtime_run_duration_models.dart` 只承载节点耗时统计、趋势和关联运行摘要，`runtime_run_failure_models.dart` 只承载失败聚类和关联运行摘要，`runtime_run_event_models.dart` 只承载运行证据事件、视觉证据链、子流程传参摘要和脱敏平台摘要字段，`runtime_run_trace_models.dart` 只承载节点执行路径和截图证据引用，`runtime_run_analysis_models.dart` 只承载失败分析、详情指标和问题类型归类，`runtime_run_detail_models.dart` 只承载完整运行详情聚合，`runtime_v4_acceptance_models.dart` 只承载最新 V4 final acceptance 脱敏摘要、结构化终验门禁和现场补验清单；`runtime_models.dart` 只保留入口说明，不再承载所有模型。Runtime Controller 主文件只保留依赖、快照和广播中心；本机环境、Appium 启停和设备会话命令归属 `runtime_appium_commands.dart`，设备预览命令按截图、点击、手势和输入归属 `runtime_device_preview_*_commands.dart`，工作流启动、安全停止和暂停收口归属 `runtime_run_commands.dart`，本地项目命令承载 workflow 更新、子流程注册/删除/当前流程转子流程、收藏、复制、删除、settings 更新、运行历史、截图证据读取和 V4 终验摘要刷新。workflow 引用校验分片只负责 Sub Workflow 引用完整性与自引用拦截；执行主体 `runtime_workflow_execution.dart` 只承载主循环、串行推进和 Catch 路由；节点调度 `runtime_workflow_node_execution.dart` 只承载节点类型分发、成功和失败焦点收口；动作节点 `runtime_workflow_action_nodes.dart` 只承载 Tap、Wait、Swipe、Input、Snapshot；控制节点路由 `runtime_workflow_control_nodes.dart` 只保留说明，判断节点 `runtime_workflow_decision_nodes.dart` 只承载 Condition 和 Visual Branch，流程编排节点 `runtime_workflow_flow_nodes.dart` 只承载 Catch、Sub Workflow 和 Loop；执行辅助 `runtime_workflow_execution_helpers.dart` 只承载节点查找和短中文运行文案；证据存储入口 `evidence_store.dart` 只承载接口、Noop、Local store 对外委托和保留策略应用，`evidence_store_writer.dart` 只承载 metadata/events/screenshots/finish 写入，`evidence_store_history.dart` 只承载运行摘要读取和 Monitor 聚合编排，`v4_acceptance_store.dart` 只读取最新 V4 终验 JSON 的脱敏摘要和白名单补验命令，`evidence_store_aggregations.dart` 只承载日期趋势、问题分类、失败聚类和节点耗时聚合，`evidence_store_detail.dart` 只承载单次运行详情、事件解析、平台摘要字段解析和截图资产读取，`evidence_store_helpers.dart` 只承载安全路径、文件名清洗和轻量字段解析；执行证据只承载 run start/end、事件和截图证据写入；执行规划只承载步骤数估算；节点参数解析只承载 Project DSL 到 Runtime 动作对象的转换；视觉守卫只承载已知系统弹窗识别和安全 context 读取。后续 Runtime 改动必须保持 `studio_runtime.dart` 公共导入稳定，优先把新能力放到同职责分片或独立 package，避免页面层直接承载运行时逻辑，也避免把纯本地数据命令、节点实现、证据、规划、参数解析、引用校验、终验摘要或视觉守卫重新塞回连接控制器和执行主体；新增模型必须进入对应 `runtime_*_models.dart` 分片，新增控制器命令必须进入对应 `runtime_*_commands.dart` 分片，新增动作节点语义必须进入动作节点分片，新增判断节点语义必须进入 decision 分片，新增流程编排语义必须进入 flow 分片，新增 evidence 写入/历史聚合/详情读取/终验摘要读取必须进入对应 store 分片，不能重新堆回 `runtime_controller.dart`、`runtime_workflow_execution.dart`、`runtime_workflow_node_execution.dart`、`runtime_workflow_control_nodes.dart` 或单个 `evidence_store.dart`。

当前 Runtime 本机依赖探测已继续拆分：`dependency_probe.dart` 只保留 Appium / 本机依赖检查公共契约和探测入口，`dependency_command_probe.dart` 只承载命令执行、输出裁剪和路径脱敏，`dependency_tunnel_probe.dart` 只承载 Appium XCUITest 本机隧道进程和 tunnel registry 活动状态判断，`dependency_wda_prerequisites.dart` 只把工具链和隧道状态汇总为会话准备状态，`dependency_android_probe.dart` 只承载 Android ADB 可见性和唯一授权手机准备度检查，`appium_availability_probe.dart` 只读取 Appium `/status`。Android ADB 缺失、无设备、未授权、离线或多设备在 Local Stack Check 中只作为 V4 Android 准备提醒，不把当前 iOS 连接链路升级为阻断错误。后续新增本机准备项必须先判断是命令检查、隧道检查、会话汇总、Android 准备还是 Appium status，不得重新堆回单个依赖探测文件；Local Stack Check 仍不得启动隧道、列出完整设备标识、请求 sudo 或展示完整路径，隧道启动只属于“连接设备”的受控流程。

当前 Runtime 本地项目命令已继续拆分为五个分片：`runtime_workflow_project_commands.dart` 承载当前 workflow 保存、复制和重置，`runtime_sub_workflow_project_commands.dart` 承载子流程注册、当前流程转子流程和删除，`runtime_settings_project_commands.dart` 承载本机设置、收藏和证据保留策略，`runtime_evidence_project_commands.dart` 承载运行历史、运行详情、本地报告和截图证据读取，`runtime_project_helpers.dart` 承载流程和子流程副本命名 helper。后续新增本地项目能力必须进入对应分片，不得恢复单个巨型项目命令文件。

当前 `packages/studio_runtime` 测试已按运行时子域拆分：`test/runtime_snapshot_test.dart` 覆盖 Runtime 初始快照和只读摘要；`runtime_sub_workflow_store_test.dart`、`runtime_sub_workflow_reference_test.dart` 和 `runtime_sub_workflow_guard_test.dart` 分别覆盖子流程存储/删除、引用校验和控制器防护；`test/runtime_appium_lifecycle_test.dart` 覆盖 Appium 进程、依赖探测和连接等待；`runtime_project_workflow_test.dart`、`runtime_project_settings_test.dart` 和 `runtime_project_config_test.dart` 分别覆盖 workflow 项目命令、本机设置/证据保留和项目配置恢复/legacy 导入；`test/runtime_v4_acceptance_test.dart` 覆盖 V4 final acceptance 摘要读取、坏文件跳过和 controller snapshot 刷新；`test/runtime_workflow_execution_test.dart` 覆盖基础串行执行、循环、执行焦点、安全停止和旧配置导入；`test/runtime_workflow_visual_test.dart` 覆盖视觉节点低置信挂起、已知系统弹窗和视觉证据链；`test/runtime_workflow_control_flow_test.dart` 覆盖 Condition、Sub Workflow 入参和 Catch 重试 / onError 路由；`test/runtime_workflow_evidence_test.dart` 覆盖运行元数据、事件流和截图证据写入；`test/device_session_test.dart` 专门覆盖 Appium session、设备连接状态、截图和 Device Preview 归一化手势 / 输入；`evidence_store_retention_test.dart`、`evidence_store_summary_test.dart`、`evidence_store_duration_test.dart` 和 `evidence_store_detail_test.dart` 分别覆盖本地 evidence 保留/历史刷新、摘要/失败聚类、节点耗时和详情/截图读取；`test/support/runtime_test_harness.dart` 承载 fake Appium session server、fake session manager、fake dependency / process / device actions 等跨 Runtime 测试夹具。后续新增 Runtime 测试必须先判断子域，不得恢复综合巨型 `studio_runtime_test.dart`、巨型 `runtime_workflow_execution_test.dart`、`runtime_sub_workflow_test.dart`、`runtime_project_store_test.dart` 或 `evidence_store_test.dart`。

V2.0 工程结构采用 Dart / Flutter Monorepo，使用 Melos 管理。Reusable runtime、Workflow DSL、Appium Client 和 Design System 进入 `packages/`。当前 `packages/appium_client/lib/appium_client.dart` 是最小 Dart Appium / WebDriver Client 公共入口，内部已拆为 endpoint 配置、统一异常、status/session/viewport 模型、JSON HTTP transport、W3C action payload、受控移动命令和最小 client 门面；当前覆盖截图、页面结构、viewport、W3C 点按/滑动、文本输入、App 启动/停止、受控平台键和 actions 释放。新增协议能力时不得把 Appium 进程管理、session 状态机、运行队列或 UI 文案写入该包。当前 `packages/workflow_dsl/lib/workflow_dsl.dart` 是 Project DSL 公共入口，具体实现已拆为 `workflow_models.dart`、`workflow_json.dart`、`workflow_templates.dart`、`workflow_validation.dart` 和 `workflow_validation_node_parameters.dart`；`workflow_validation.dart` 只承载表达式白名单、入口结构、引用和可达性校验，节点类型参数、分支数量和可执行边界归属节点参数校验分片。新增节点类型先进入模型，再补 validator 和 Runtime 语义，新增模板进入模板分片，JSON 解析 helper 不得散落到 UI 页面。Legacy Node implementation 已物理归档到 `legacy/node/src/`，根目录不再保留活跃 `src/`，旧 npm 入口统一使用 `legacy:*` 前缀；V2.0 / V4.0 主路径不得依赖或调用这些服务，root `package.json` 也不得恢复 `init:connected`、`click:connected` 等无前缀旧入口，非 Legacy 脚本不得绕回 `legacy/node/src`。`fvm dart run tool/v2_boundary_check.dart` 会扫描 `apps/studio_mac/lib` 和 `packages/*/lib`，防止 V2.0 Flutter / Dart 主路径重新调用 Legacy Node Web Console、Legacy CLI、Legacy Web API 或 Node 脚本中间层；`fvm dart run tool/v4_boundary_check.dart` 额外检查 V4 文档、第三方治理、内部包发布元数据和 root npm 脚本边界。

当前 `packages/workflow_dsl` 测试已按 DSL 子域拆分：`test/workflow_templates_test.dart` 覆盖 A-F 模板和 legacy sequence 导入；`test/workflow_json_test.dart` 覆盖 Project DSL JSON 序列化、反序列化、视觉元数据和未知节点类型拦截；`test/workflow_validator_structure_test.dart` 覆盖缺失引用、自引用、Catch onError 自引用和视觉位置完整性；`test/workflow_validator_expressions_test.dart` 覆盖安全表达式和 Sub Workflow inputMap 白名单；`test/workflow_validator_visual_test.dart` 覆盖 Visual Branch 置信度和成功分支边界；`test/workflow_validator_control_nodes_test.dart` 覆盖 Catch、Sub Workflow 和 Loop 控制节点边界；`test/workflow_validator_action_nodes_test.dart` 覆盖 Tap / Wait / Swipe / Input / Snapshot 动作节点可执行参数；`test/support/workflow_dsl_test_harness.dart` 只承载共享 validator 常量。新增 DSL 测试必须先判断模板、JSON、结构、表达式、视觉、控制节点或动作节点归属，不得恢复综合巨型 `workflow_dsl_test.dart`。

当前 V2.0 packages README 已归真为包级入口文档。`packages/appium_client` 说明最小 Dart Appium / WebDriver 客户端职责、内部分片和边界，`packages/workflow_dsl` 说明 Project DSL 模型、节点类型、内部分片和校验边界，`packages/studio_runtime` 说明本地运行时职责、边界和验证方式，`packages/studio_design_system` 说明 Tech Noir 设计系统色板、主题、状态胶囊、一级 Surface、二级 Inset Surface 和工作区面板。当前 Flutter / Dart monorepo 包默认 `publish_to: none`，内部包不得误发布为独立公共包；包级许可证不得保留模板 TODO，Design System 包已声明为项目内部包，除非仓库级许可证或书面授权另行授予权限。后续新增或修改 package 时，README 必须保留职责、边界、公共入口和验证命令，不得保留 Dart / Flutter 模板 TODO 或无关 sample。

当前 Flutter widget 测试已按区域和 Workflow 子域拆分：`apps/studio_mac/test/shell_test.dart` 覆盖 Shell、Settings Drawer、Top Status、Global Command Center、智能抽屉和 Bottom Console；`apps/studio_mac/test/dashboard_test.dart` 覆盖 Dashboard KPI、最近流程、流程详情抽屉、入口跳转和本机流程动作；`apps/studio_mac/test/device_test.dart` 覆盖 Device 页面摘要、就绪检查、本机指引、Inspector 目标建议和 Inspector 建流程；`apps/studio_mac/test/device_preview_test.dart` 覆盖 Device Preview 的点击、双击、长按、滑动、滚动、方向键滑动、缩放、受控主页键和输入安全边界；`apps/studio_mac/test/execute_test.dart` 覆盖 Execute 运行控制台、运行确认弹窗、暂停介入、运行焦点和 Preflight 拦截；`apps/studio_mac/test/monitor_test.dart` 覆盖 Monitor 本地运行记录、趋势、筛选、搜索和可见记录复制；`apps/studio_mac/test/monitor_detail_test.dart` 覆盖 Monitor Run Detail 问题分析、视觉证据链、脱敏摘要复制和相关事件筛选；`apps/studio_mac/test/monitor_evidence_test.dart` 覆盖 Monitor 截图 reveal、胶片和截图回放；`apps/studio_mac/test/recorder_test.dart` 覆盖 Recorder 录制、预览点击、预览拖动生成 Swipe 路径、动作整理、隐私展示和 Promote 到 Project DSL；`apps/studio_mac/test/workflow_source_test.dart` 覆盖 Workflow Source/Validate、Project DSL 源码草稿、诊断定位、子流程引用和自引用拦截；`workflow_clipboard_keyboard_test.dart`、`workflow_clipboard_system_test.dart` 和 `workflow_clipboard_graph_test.dart` 分别覆盖 Workflow Canvas 键盘快捷键 / 页面内剪贴板、系统剪贴板跨 workflow 粘贴、复杂图结构重映射和 Loop + Catch 嵌套子图；`workflow_inspector_status_test.dart`、`workflow_inspector_basic_edit_test.dart`、`workflow_inspector_advanced_parameters_test.dart`、`workflow_inspector_subflow_test.dart` 和 `workflow_inspector_node_actions_test.dart` 分别覆盖 Workflow Inspector 状态/上下文与复制全部摘要、基础编辑、复杂参数、子流程和节点动作；`workflow_canvas_navigation_test.dart` 覆盖 Workflow 画布节点导航、当前/完成/失败节点高亮、节点留档入口、分支摘要和语义连线说明；`workflow_canvas_capability_test.dart` 覆盖 Workflow 画布节点平台能力徽标、缺能力提示和离线兜底；`workflow_canvas_edge_test.dart`、`workflow_template_test.dart`、`workflow_canvas_viewport_test.dart`、`workflow_canvas_connection_test.dart`、`workflow_canvas_selection_test.dart` 和 `workflow_palette_test.dart` 分别覆盖 Workflow 画布边、模板、视口、连线、选区和节点库；`apps/studio_mac/test/support/studio_widget_harness.dart` 只承载桌面窗口、剪贴板、Workflow 节点选择/保存、设备会话、设备动作、运行详情、依赖检查 fake 和剪贴板复杂图夹具。后续新增或迁移测试时先判断归属区域测试文件、Monitor 详情测试、Monitor 证据测试、Workflow Inspector 子域测试、Workflow Canvas 子域测试、Workflow Clipboard 子域测试或 support 夹具，不得恢复单个巨型 `widget_test.dart`、`workflow_inspector_test.dart`、`workflow_clipboard_test.dart` 或 Monitor 巨型测试文件。

当前 Monitor Failure Trend 已继续按入口、聚合模型和图表渲染拆分：`monitor_failure_trend.dart` 只承载失败趋势面板与头部，`monitor_failure_trend_model.dart` 只承载 failed / paused / stopped 的窗口聚合摘要，`monitor_failure_trend_chart.dart` 只承载堆叠柱图表和单日柱渲染。后续扩展失败趋势提示、交互或筛选时先判断是入口状态、模型派生还是图表展示，不得重新堆回单个失败趋势文件。

当前 Monitor 页面入口已继续拆分：`monitor_page.dart` 只保留页面状态字段、生命周期和区域组合，`monitor_page_actions.dart` 只承载运行详情读取、常见问题/问题分类/耗时节点/耗时趋势关联筛选、手动筛选切换和可见记录摘要复制。后续新增 Monitor 页面动作必须先进入动作分片，页面入口不得重新堆叠跨运行深挖、复制或详情读取逻辑。

当前 Monitor 本地报告 UI 已独立落到 `monitor_detail_report.dart`：该分片只承载本地报告面板、视觉复盘摘要、平台差异摘要、脱敏 JSON 复制入口和 Runtime 报告保存入口；详情抽屉壳只负责传入 Runtime `readRunReport` 的结果并组合分片，不直接扫描 evidence 文件或拼接本机路径。

当前 Device Local Setup Guide 已继续拆分：`device_setup_guide.dart` 只承载本机指引抽屉外壳、Runtime snapshot 读取和分区装配；`device_setup_guide_sections.dart` 只承载准备项卡片、依赖摘要、复制命令和 V2.0 本机边界提示。后续新增本机准备项或短动作时先判断是抽屉编排还是内容卡片，不得重新堆回单个设备指引文件；复制类动作仍只写剪贴板，不启动命令、不请求权限。

当前 shared readiness helper 已继续拆分：`readiness_helpers.dart` 和 `readiness_entry_helpers.dart` 只保留路由说明，`dependency_status_helpers.dart` 只承载本机依赖检查时间、短状态、状态色和图标映射，`readiness_driver_entries.dart` 只承载驱动服务准备项，`readiness_device_entries.dart` 只承载 USB 手机和开发者信任准备项，`readiness_session_entries.dart` 只承载手机会话和安全截图准备项，`readiness_workflow_entries.dart` 只承载流程文件准备项，`readiness_icon_helpers.dart` 只承载准备度图标映射。后续新增跨页面准备度能力时先判断是依赖状态、驱动、设备、会话、流程还是图标，不得重新堆回单个 helper，Device、Execute、Recorder 和 Top Status 不得各自复制 switch。

## Current Truth Sources

进入项目后默认先读：

1. `AI_PROJECT_CONTEXT.md`
2. `AGENTS.md`
3. `README.md`
4. `docs/README.md`
5. `docs/iOS Assist Studio项目文档v1.0.md`
6. 当前任务对应的专题文档

专题真源：

| 主题 | 真源文档 |
|---|---|
| V4.0 产品定位、双平台闭环、功能清单和非目标 | `docs/V4.0-PRD-Mobile-Automation-Workstation.md` |
| V4.0 Flutter / Dart / Python / Appium 融合架构 | `docs/V4.0-Architecture-Integrated-Mobile-Workstation.md` |
| V4.0 开源项目吸纳、复制治理和第三方归属 | `docs/V4.0-Open-Source-Integration-Plan.md`、`THIRD_PARTY_NOTICES.md` |
| V4.0 分批路线、iOS 深验证和 Android 首版冒烟 | `docs/V4.0-Development-Roadmap.md` |
| V4.0 Legacy Node 禁用、覆盖和删除门禁 | `docs/V4.0-Legacy-Node-Exit-Plan.md` |
| V4.0 开源融合、Node 退出和双平台首版决策 | `docs/decisions/ADR-002-v4-open-source-fusion-and-node-exit.md` |
| V3.0 竞品启发、痛点吸收和非复制边界 | `docs/V3.0-Competitive-Strategy-TestHub.md` |
| V3.0 产品定位、目标用户、范围和非目标 | `docs/V3.0-PRD-Cross-Platform-Mobile-Workstation.md` |
| V3.0 跨平台 Runtime、driver adapter、目标库和证据模型 | `docs/V3.0-Architecture-Cross-Platform-Runtime.md` |
| V3.0 信息架构、Target Library 和跨平台工作台体验 | `docs/V3.0-IA-UX-Mobile-Workstation.md` |
| V3.0 分阶段开发计划、验收和停手条件 | `docs/V3.0-Development-Plan.md` |
| V3.0 企业级体验、任务型 IA、页面线框、设计 token 和 macOS 原生方向 | `docs/V3.0-Enterprise-Design-Master-Brief.md` |
| V3.0 最终流程图专项产物 | `docs/V3.0-Flowcharts-Specialized.md` |
| V3.0 最终时序图专项产物 | `docs/V3.0-Sequence-Diagrams-Specialized.md` |
| V3.0 最终页面低保真原型专项产物 | `docs/V3.0-Page-Prototypes-Specialized.md` |
| V3.0 HTML 静态原型 | `docs/prototypes/v3-enterprise-static-prototype.html` |
| V3.0 流程图、时序图和页面原型生成 Brief / 提示词 | `docs/V3.0-ChatGPT-Flow-Prototype-Brief.md` |
| V3.0 跨平台驱动边界决策 | `docs/decisions/ADR-001-v3-cross-platform-driver-boundary.md` |
| V2.0 产品定位、目标用户、范围和非目标 | `docs/V2.0-PRD-Enterprise-Flagship.md` |
| V2.0 一级导航、全局框架、模块职责 | `docs/V2.0-IA-Information-Architecture.md` |
| V2.0 交互规范、状态表达、组件使用 | `docs/V2.0-UX-Spec-Enterprise-Console.md` |
| V2.0 Flutter Desktop 技术路线 | `docs/V2.0-Flutter-Desktop-Architecture.md` |
| V2.0 Monorepo 包结构和依赖方向 | `docs/V2.0-Monorepo-Engineering-Plan.md` |
| V2.0 Node/Web 到 Flutter 迁移策略 | `docs/V2.0-Migration-Plan-Node-Web-to-Flutter.md` |
| V2.0 分阶段开发计划 | `docs/V2.0-Development-Plan.md` |
| 产品、设备、执行、视觉、隐私、验证边界 | `docs/产品与工程边界v1.0.md` |
| 当前结构、状态机、入口语义、配置规则 | `docs/iOS Assist Studio项目文档v1.0.md` |
| 阶段拆分和验收边界 | `docs/三阶段开发计划v1.0.md` |
| 产品定调和长期方向 | `docs/产品定位与旗舰化方向v1.0.md` |
| Web 控制台 UI/UX | `docs/Web控制台UIUX规范v1.0.md` |
| 视觉状态驱动和工作流演进 | `docs/视觉状态驱动编排架构路线v1.0.md` |

根 `README.md` 只保留快速启动和文档入口，不承载长期实现细节。

## Runtime Model

当前 Legacy 有两条入口：

- Web 控制台：Legacy / Debug / Migration reference，负责初始化设备、连接 Appium/WDA、保持 WebDriver 常驻会话、触发任务、展示日志和证据。
- CLI：兼容入口，保留初始化、点击、录制、拾点和校验能力。

V2.0 目标入口变更：

- Flutter Desktop Mac App：V2.0 唯一主入口。
- Web 控制台：Legacy / Debug / Migration reference，不再增长 V2.0 主路径功能。
- CLI：Legacy 兼容和调试入口。

核心运行模块：

| 模块 | 责任 |
|---|---|
| `legacy/node/src/ios-assist-console.mjs` | Legacy 本地 Web 控制台、HTTP API、SSE、前端 UI |
| `legacy/node/src/ios-assist-session.mjs` | Legacy 设备发现、Appium 启停、WDA/WebDriver 常驻连接、证书信任状态 |
| `legacy/node/src/ios-assist-runner.mjs` | Legacy 串行任务执行、安全停止、挂起/继续、事件输出 |
| `legacy/node/src/ios-assist-workflow.mjs` | Legacy 自定义 DSL、旧序列包装、图合法性校验、表达式白名单 |
| `legacy/node/src/ios-assist-visual.mjs` | Legacy 基础视觉判断、已知阻断态识别、低置信挂起建议 |
| `legacy/node/src/ios-assist-evidence.mjs` | Legacy 本地截图、事件和运行证据滚动留存 |
| `legacy/node/src/ios-coordinate-*.mjs` | Legacy CLI 和坐标辅助工具 |

当前 Web 控制台已具备工作流画布 MVP：后端输出节点和边，前端以画布、SVG 边线和可拖拽节点展示拓扑。拖拽只影响当前浏览器里的视图布局，不写回 DSL，不改变运行真值；workflow 的持久化仍通过受控 JSON 面板、后端白名单规范化和 validator 完成。控制台也具备失败热力图 MVP 和只读分析 API，只从本地运行事件聚合失败坐标或失败节点，不触发设备命令。

## Non-Negotiable Boundaries

- 点击任务始终串行。
- 多轮执行严格按轮次顺序推进。
- 停止任务采用安全停止，不强杀当前原子动作。
- Appium/WDA 仍是核心会话机制。
- 证书信任、Developer Mode、WDA 构建失败只做提示和引导，不绕过系统限制。
- 视觉判断无结果或低置信度时默认挂起，不能盲目进入后续点击。
- 运行中的截图、视觉采集和证据采集必须等待底层 WDA 命令结算或硬上限释放，不能和后续 Tap 并发抢占 WebDriver 通道。
- `Catch` 已支持显式 `onError` 错误分支；未声明 `onError` 的节点异常仍应失败退出。
- 工作流表达式只允许读取 `context.xxx`，不开放任意 JS。
- 工作流写入与任务运行互斥。
- 运行证据只保存在本机，默认滚动清理。
- 文档、UI、日志和公共 API 不长期暴露完整设备标识、本机绝对路径、账号或证书主体。

## Skill Routing

当对话开始分析需求时，先按任务类型自动选择 skill。

| 任务类型 | 首选 skill | 次选 skill | 说明 |
|---|---|---|---|
| Flutter Desktop、Dart Runtime、Monorepo、macOS Flutter App | `flutter-architecting-apps` | `flutter-building-layouts` | V2.0 主工程路线 |
| Flutter 页面、布局、组件拆分、响应式适配 | `flutter-building-layouts` | `flutter-theming-apps` | 负责页面结构、约束、组件抽取和桌面适配 |
| Flutter 状态管理、UI 状态机、跨组件数据流 | `flutter-managing-state` | `flutter-architecting-apps` | 负责 ViewModel、单向数据流和状态归属判断 |
| Flutter 入口文件拆分、包边界、共享能力沉淀 | `flutter-architecting-apps` | `flutter-managing-state` | 先判断落在 `apps/studio_mac` 还是 `packages/*` |
| Flutter 路由、页面导航、命令中心跳转 | `flutter-implementing-navigation-and-routing` | `flutter-testing-apps` | 负责 L1-L6 导航语义和页面切换边界 |
| Flutter 中文文案、本地化、用户可懂表达 | `flutter-localizing-apps` | `flutter-improving-accessibility` | 负责短中文文案、语义和可访问表达 |
| Flutter 测试、widget 回归、Runtime/UI 合同验证 | `flutter-testing-apps` | `flutter-architecting-apps` | Flutter 测试优先，Legacy Web 再用 Playwright |
| Appium、XCUITest、WDA、capability、WebDriver 会话 | `appium-skill` | `ios-device-toolkit` | 保持主驱动链路和真机自动化模式正确 |
| USB iPhone、截图、系统日志、设备诊断、端口转发 | `ios-device-toolkit` | `appium-skill` | 作为辅助诊断通道，不替代主驱动 |
| 视觉状态、看图自动化、屏幕状态判断 | `ios-device-automation` | `computer-vision-opencv` | 用于未来视觉状态驱动能力 |
| 图像识别、模板匹配、OCR/CV 节点 | `computer-vision-opencv` | `ios-device-automation` | CV/OCR 必须保持可选能力 |
| Web 控制台交互、API、响应式、浏览器流程 | `playwright-e2e-testing` | `playwright-visual-testing` | 用于看板流程和视觉回归验证 |
| Web 控制台视觉质量和截图核对 | `playwright-visual-testing` | `playwright-e2e-testing` | 用于页面状态和布局检查 |
| 文档组织、真源维护、AI 协作入口 | 当前文档规则 | `skill-creator` 仅在创建技能时使用 | 默认先维护项目文档，不创建无关技能 |

不要把 skill 选择责任推给用户。任务同时命中多个层次时，应组合使用。

## Implementation Priorities

优先级从高到低：

1. 不破坏本地单机常驻连接。
2. 不引入并行点击或运行态竞态。
3. 不绕过 iOS 系统安全限制。
4. 不让 Flutter App 调用自建 Node 服务。
5. 不让 Web 状态接口、SSE 或设备探测卡死 Legacy 页面。
6. 不让 workflow 配置半写、并发覆盖或运行中被改。
7. 不让视觉判断低置信时继续自动点击。
8. 不把 README 重新变成实现细节堆放处。

## Verification Expectations

常规收口优先运行：

- `fvm dart run tool/v2_boundary_check.dart`
- `fvm dart run melos run analyze`
- `fvm dart run melos run test`
- `fvm dart run tool/macos_build_smoke.dart`
- `fvm dart run tool/v2_verify.dart`

按改动范围补充运行：

| 改动范围 | 验证重点 |
|---|---|
| session / Appium / WDA | session smoke、状态接口、连接/断开边界 |
| runner / stop / pause | runner smoke、串行执行、停止和挂起语义 |
| workflow DSL | validate、workflow smoke、旧 CLI 兼容 smoke |
| Web 控制台 | console smoke、状态 API、workflow API、页面关键元素 |
| evidence / visual | evidence smoke、visual smoke、隐私扫描 |
| docs / public text | 隐私扫描、旧文案扫描、文档索引一致性 |
| Flutter Mac App 构建 | `tool/macos_build_smoke.dart`，确认 V2.0 Mac App debug build 可产出 |
| acceptance / scripts | V2 Dart verifier、legacy acceptance smoke、A-F 基础序列真值、Mac App 构建门禁 |

如果没有真实 iPhone，至少保证 dry-run、validator、smoke、静态检查、Flutter macOS debug build 和 Web 本地 API 验证通过。

## Privacy Rules

- 不在文档长期写入本机绝对路径。
- 不在文档长期写入完整 UDID、账号、证书主体或设备唯一标识。
- 公共 API 和实时日志必须脱敏。
- 截图证据只保存在本机，按保留策略滚动清理。
- 文档只写规则和方向，不复制终端日志中的私密细节。

## Future Direction

长期方向是视觉状态驱动的 iOS 辅助自动化编排器：

- L1 Dashboard
- L2 Device
- L3 Recorder
- L4 Workflow
- L5 Execute
- L6 Monitor
- Flutter Desktop Mac App
- Dart Runtime
- Dart Appium / WebDriver Client
- Melos Monorepo
- 左侧数字孪生设备视窗
- 中间工作流画布拓扑
- 右侧属性和动态参数变量池
- 底部全链路时间轴
- 自定义强类型 DSL
- Tap / Wait / Swipe / Input / Loop / Snapshot / Visual_Branch / If_Else / Catch / Sub_Workflow 等基础节点；任意复杂图编辑归入完整 Workflow 画布阶段
- 基于本地证据链的视觉判断和异常处理

所有未来能力必须保持本地、单机、可验证、可暂停和可回退。
