# iOS Assist Studio Docs Index

## 0. TL;DR

- 本目录文档主要面向 Codex / 其他 AI 工具，也面向后续接手项目的人，用于快速完成任务分类、真源定位和改动落点判断。
- 默认阅读顺序：先读根目录 `AI_PROJECT_CONTEXT.md` 和 `AGENTS.md`，再读本索引、项目总文档，然后进入 `apps/`、`packages/`、`legacy/node/src/`、`config/` 和对应脚本。
- 根目录 `README.md` 只保留简介、快速启动和文档入口；长期维护的实现说明统一收敛在 `docs/`。

## 1. Task Router

| 如果任务是... | 先读文档 | 默认优先改哪里 | 不要先做什么 |
|---|---|---|---|
| 判断 V4.0 产品定位、双平台闭环、功能清单和非目标 | `V4.0-PRD-Mobile-Automation-Workstation.md` | 先定本地移动自动化工作站边界 | 把 V4.0 做成 SaaS、设备池、群控或团队平台 |
| 判断 V4.0 Flutter / Dart / Python / Appium / 双平台融合架构 | `V4.0-Architecture-Integrated-Mobile-Workstation.md`、`decisions/ADR-002-v4-open-source-fusion-and-node-exit.md` | 先定 Runtime、adapter、sidecar 和 Node 退出边界 | 恢复 Node 中间层或让第三方能力绕过 Runtime |
| 判断 V4.0 如何吸收 Airtest、Pyxelator、Appium Inspector、appium-mcp | `V4.0-Open-Source-Integration-Plan.md` | 先按依赖、适配、移植、复制、参考分档 | 一股脑复制四个项目源码 |
| 判断 V4.0 分批落地、iOS 深验证和 Android 首版冒烟 | `V4.0-Development-Roadmap.md` | 先定批次验收和停手条件 | 只堆 UI 或只做 iOS 而让 Android 继续占位 |
| 判断 V4.0 Legacy Node 何时禁用和删除 | `V4.0-Legacy-Node-Exit-Plan.md` | 先确认能力覆盖和删除门禁 | 在替代能力未覆盖前直接删除唯一可用路径 |
| 判断 V3.0 竞品启发、痛点吸收和非复制边界 | `V3.0-Competitive-Strategy-TestHub.md` | 先定竞品痛点和本项目取舍 | 把 TestHub 当作照抄路线图 |
| 判断 V3.0 产品定位、目标用户、范围和非目标 | `V3.0-PRD-Cross-Platform-Mobile-Workstation.md` | 先定单人单设备跨平台边界 | 把 V3.0 扩成 SaaS / 设备池 / 测试管理平台 |
| 判断 V3.0 跨平台 Runtime、driver adapter、目标库和证据模型 | `V3.0-Architecture-Cross-Platform-Runtime.md`、`decisions/ADR-001-v3-cross-platform-driver-boundary.md` | 先定平台抽象和 adapter 边界 | 在 UI 或现有 iOS Runtime 里散落 Android 分支 |
| 判断 V3.0 信息架构、Target Library、跨平台工作台体验 | `V3.0-IA-UX-Mobile-Workstation.md` | 先定工作区和目标库入口 | 过早新增设备池或团队管理导航 |
| 判断 V3.0 分阶段落地、验收和停手条件 | `V3.0-Development-Plan.md` | 先定阶段和 fake 验证 | 一次性把 Android、OCR、scrcpy、报告全塞进一期 |
| 判断 V3.0 企业级体验、任务型 IA、页面线框、设计 token 和 macOS 原生方向 | `V3.0-Enterprise-Design-Master-Brief.md` | 先按 UX 优先级和任务语言定体验 | 沿用 Tech Noir / Dashboard / 控制台心智直接画界面 |
| 查看 V3.0 最终流程图专项产物 | `V3.0-Flowcharts-Specialized.md` | 直接复用 Mermaid 图表 | 把提示词当最终流程图 |
| 查看 V3.0 最终时序图专项产物 | `V3.0-Sequence-Diagrams-Specialized.md` | 直接复用 Mermaid sequenceDiagram | 让外部模型重新自由发散 |
| 查看 V3.0 最终页面低保真原型专项产物 | `V3.0-Page-Prototypes-Specialized.md` | 直接复用页面职责、状态和 ASCII wireframe | 把页面做成控制台或后台 |
| 查看 V3.0 HTML 静态原型 | `prototypes/v3-enterprise-static-prototype.html` | 本地浏览器直接打开单文件 | 引入外部依赖或联网资源 |
| 查看 V3.0 专项图片和校验报告 | `prototypes/generated-images/README.md` | 直接查看 PNG / SVG / verification | 用未校验截图替代完整图片 |
| 让 ChatGPT 生成 V3.0 流程图、时序图和页面低保真原型 | `V3.0-ChatGPT-Flow-Prototype-Brief.md` | 先复制总控提示词，再按图表类型追加专项提示词 | 让外部模型自由发散成 SaaS / 设备池 / 群控产品 |
| 判断 V2.0 产品定位、目标用户、范围和非目标 | `V2.0-PRD-Enterprise-Flagship.md` | 先定产品边界 | 把 Enterprise 误解为 SaaS / 多租户 |
| 判断 V2.0 一级导航、全局框架、模块职责 | `V2.0-IA-Information-Architecture.md` | 先定信息架构 | 随意新增一级导航 |
| 判断 V2.0 交互规范、状态表达、组件使用 | `V2.0-UX-Spec-Enterprise-Console.md` | 先定体验规则 | 把技术细节铺在主界面 |
| 判断 V2.0 Flutter Desktop 技术路线 | `V2.0-Flutter-Desktop-Architecture.md` | 先定 App / Runtime 边界 | 继续给 Web 看板加主路径功能 |
| 拆分 Flutter UI、Runtime 或 shared helper | `V2.0-Flutter-Desktop-Architecture.md` | 先按 feature / shared / runtime 分片归属 | 把新逻辑回填到综合 helper |
| 判断 V2.0 Monorepo 包结构和依赖方向 | `V2.0-Monorepo-Engineering-Plan.md` | 先定包边界 | 把 UI、Runtime、DSL 混成一个大包 |
| 判断 Node/Web 到 Flutter 的迁移策略 | `V2.0-Migration-Plan-Node-Web-to-Flutter.md` | 先定 Legacy 边界 | 让 Flutter 调用自建 Node 服务 |
| 判断 V2.0 分阶段开发计划 | `V2.0-Development-Plan.md` | 先定阶段验收 | 第一阶段硬做完整画布 |
| 判断产品/工程边界、隐私、安全、验证约束 | `产品与工程边界v1.0.md` | 先定边界 | 绕开边界直接实现 |
| 拆开发计划、排阶段、判断先后顺序 | `三阶段开发计划v1.0.md` | 先定阶段边界 | 把所有愿景塞进一期 |
| 判断产品方向、旗舰化范围、阶段优先级 | `产品定位与旗舰化方向v1.0.md` | 先定能力边界 | 直接把愿景写进代码 |
| Legacy Web 看板视觉、布局、状态表达、交互体验 | `Web控制台UIUX规范v1.0.md` | `legacy/node/src/ios-assist-console.mjs` | 做营销页或装饰性改版 |
| 视觉状态驱动、工作流节点、异常拦截、时间轴 | `视觉状态驱动编排架构路线v1.0.md` | 先判层级，再定模块 | 一次性重排目录 |
| 判断该走 Web 看板还是 CLI | `iOS Assist Studio项目文档v1.0.md` | 先判入口，再动实现 | 直接改某个脚本 |
| Legacy 连接状态、WDA、Appium、证书信任 | `iOS Assist Studio项目文档v1.0.md` | `legacy/node/src/ios-assist-session.mjs` | 先改点击序列 |
| Legacy Web 看板按钮、状态展示、日志交互 | `iOS Assist Studio项目文档v1.0.md` | `legacy/node/src/ios-assist-console.mjs` | 把实现说明继续堆回根 README |
| Legacy A-F 串行点击、停止逻辑、循环执行 | `iOS Assist Studio项目文档v1.0.md` | `legacy/node/src/ios-assist-runner.mjs` | 在多个入口重复实现点击逻辑 |
| Legacy CLI 初始化、CLI 点击前置校验 | `iOS Assist Studio项目文档v1.0.md` | `legacy/node/src/ios-coordinate-init.mjs` / `legacy/node/src/ios-coordinate-click.mjs` | 把 CLI 规则和 Web 规则混成一种初始化 |
| 修改坐标、等待时间、运行参数 | `iOS Assist Studio项目文档v1.0.md` | `config/connected-device.sequence.json` | 先改文档再忘了改配置 |
| 新增文档、调整真源、补充维护规则 | 本文档 | `docs/` | 只改 README |

## 2. Source of Truth

- 本目录下的文档是项目长期实现说明的第一真源。
- 根目录 `AI_PROJECT_CONTEXT.md` 和 `AGENTS.md` 是进入项目时的 AI 协作入口，负责快速定位项目边界、技能路由和执行规则。
- 项目总文档：
  [iOS Assist Studio项目文档v1.0.md](./iOS%20Assist%20Studio项目文档v1.0.md)
- V4.0 PRD：
  [V4.0-PRD-Mobile-Automation-Workstation.md](./V4.0-PRD-Mobile-Automation-Workstation.md)
- V4.0 融合架构：
  [V4.0-Architecture-Integrated-Mobile-Workstation.md](./V4.0-Architecture-Integrated-Mobile-Workstation.md)
- V4.0 开源融合计划：
  [V4.0-Open-Source-Integration-Plan.md](./V4.0-Open-Source-Integration-Plan.md)
- V4.0 开发路线：
  [V4.0-Development-Roadmap.md](./V4.0-Development-Roadmap.md)
- V4.0 Legacy Node 退出计划：
  [V4.0-Legacy-Node-Exit-Plan.md](./V4.0-Legacy-Node-Exit-Plan.md)
- V4.0 架构决策：
  [decisions/ADR-002-v4-open-source-fusion-and-node-exit.md](./decisions/ADR-002-v4-open-source-fusion-and-node-exit.md)
- 第三方源码归属：
  [../THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)
- V3.0 竞品策略：
  [V3.0-Competitive-Strategy-TestHub.md](./V3.0-Competitive-Strategy-TestHub.md)
- V3.0 PRD：
  [V3.0-PRD-Cross-Platform-Mobile-Workstation.md](./V3.0-PRD-Cross-Platform-Mobile-Workstation.md)
- V3.0 跨平台 Runtime 架构：
  [V3.0-Architecture-Cross-Platform-Runtime.md](./V3.0-Architecture-Cross-Platform-Runtime.md)
- V3.0 IA / UX：
  [V3.0-IA-UX-Mobile-Workstation.md](./V3.0-IA-UX-Mobile-Workstation.md)
- V3.0 开发计划：
  [V3.0-Development-Plan.md](./V3.0-Development-Plan.md)
- V3.0 企业级设计主稿：
  [V3.0-Enterprise-Design-Master-Brief.md](./V3.0-Enterprise-Design-Master-Brief.md)
- V3.0 流程图专项：
  [V3.0-Flowcharts-Specialized.md](./V3.0-Flowcharts-Specialized.md)
- V3.0 时序图专项：
  [V3.0-Sequence-Diagrams-Specialized.md](./V3.0-Sequence-Diagrams-Specialized.md)
- V3.0 页面原型专项：
  [V3.0-Page-Prototypes-Specialized.md](./V3.0-Page-Prototypes-Specialized.md)
- V3.0 HTML 静态原型：
  [prototypes/v3-enterprise-static-prototype.html](./prototypes/v3-enterprise-static-prototype.html)
- V3.0 专项图片和校验报告：
  [prototypes/generated-images/README.md](./prototypes/generated-images/README.md)
- V3.0 ChatGPT 画图和原型 Brief：
  [V3.0-ChatGPT-Flow-Prototype-Brief.md](./V3.0-ChatGPT-Flow-Prototype-Brief.md)
- V3.0 架构决策：
  [decisions/ADR-001-v3-cross-platform-driver-boundary.md](./decisions/ADR-001-v3-cross-platform-driver-boundary.md)
- V2.0 PRD：
  [V2.0-PRD-Enterprise-Flagship.md](./V2.0-PRD-Enterprise-Flagship.md)
- V2.0 信息架构：
  [V2.0-IA-Information-Architecture.md](./V2.0-IA-Information-Architecture.md)
- V2.0 UX 规范：
  [V2.0-UX-Spec-Enterprise-Console.md](./V2.0-UX-Spec-Enterprise-Console.md)
- V2.0 Flutter Desktop 架构：
  [V2.0-Flutter-Desktop-Architecture.md](./V2.0-Flutter-Desktop-Architecture.md)
- V2.0 Monorepo 工程计划：
  [V2.0-Monorepo-Engineering-Plan.md](./V2.0-Monorepo-Engineering-Plan.md)
- V2.0 Node/Web 到 Flutter 迁移计划：
  [V2.0-Migration-Plan-Node-Web-to-Flutter.md](./V2.0-Migration-Plan-Node-Web-to-Flutter.md)
- V2.0 开发计划：
  [V2.0-Development-Plan.md](./V2.0-Development-Plan.md)
- 产品与工程边界：
  [产品与工程边界v1.0.md](./产品与工程边界v1.0.md)
- 开发计划：
  [三阶段开发计划v1.0.md](./三阶段开发计划v1.0.md)
- 产品方向：
  [产品定位与旗舰化方向v1.0.md](./产品定位与旗舰化方向v1.0.md)
- UI/UX 定调：
  [Web控制台UIUX规范v1.0.md](./Web控制台UIUX规范v1.0.md)
- 架构演进：
  [视觉状态驱动编排架构路线v1.0.md](./视觉状态驱动编排架构路线v1.0.md)
- 根目录 [README.md](../README.md) 只负责入口信息，不替代本目录文档。

## 3. Priority Rules

- 文档优先描述边界、职责、状态机、关键路径和改动规则，不承载具体代码片段。
- 文档默认不写隐私信息，不写绝对路径，不写账号或证书主体名字。
- 文档优先服务“下次修改和新需求落地”，而不是重复终端输出。
- 如果文档与实现不一致，应优先修正文档和实现的真值关系，而不是靠口头约定维持。

## 4. Maintenance Triggers

- 连接流程、看板状态、CLI 规则、配置边界发生变化时，必须同步更新本目录文档。
- 新增一个长期维护的能力模块时，先判断是补到项目总文档，还是拆成新的专题文档。
- 当根 README 开始承载实现细节时，应把内容迁回 `docs/`。
