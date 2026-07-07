# Product

## Register

product

## Users

iOS Assist Studio 服务于本地 Mac 上的移动自动化工作流。Primary user 是不熟悉 Appium、WDA、ADB、selector、OCR 或 Runtime 的 QA、运营和业务测试人员；他们希望插上一台手机后，用几分钟完成连接、录制、生成流程、运行和定位失败。Secondary user 是自动化工程师；他们需要稳定、可测试、可扩展的 Runtime、DSL、driver adapter、Target Resolver 和证据模型。

用户进入产品时通常处在任务中：要连接一台当前设备、复现一个手机流程、生成可运行的自动化、确认失败原因，或把一次运行证据交给他人排查。他们不应该阅读文档、理解底层协议或在日志中寻找下一步。

## Product Purpose

产品使命是把复杂的移动调试和自动化工作，变成像截图一样简单。用户只需要思考“我要做什么”，产品负责隐藏驱动、会话、目标解析、证据、平台差异和开源能力融合细节。

V4.0 的方向是本地视觉移动自动化工作站：连接一台 iOS 或 Android 当前设备，从设备现场创建目标，用 Target + Action 编排流程，串行运行，低置信时暂停介入，并在 Monitor 中看懂任务状态、用例结果和问题归因。

V4.0 会吸收 Airtest、Pyxelator、Appium Inspector 和 appium-mcp 的成熟价值，但不把产品变成四套工具拼装。用户看到的是一个统一工作站：检查、录制、目标、流程、视觉、运行、记录和助手都服务同一条本地自动化闭环。

成功标准是第一次打开软件的人能在几分钟内完成核心任务；长期用户能以 macOS 原生方式高效操作；所有技术复杂度默认收起，只在需要诊断时逐层展开。

## Brand Personality

专业、简单、高效、可靠、舒服。

产品应该安静、克制、精致、稳定、高品质、值得信赖，不打扰用户。它应该像一款成熟的 macOS 原生工具，而不是网页控制台、开发者炫技工具或参数配置平台。

## Anti-references

不要设计成 Android Studio、Charles、Postman、Jenkins、Grafana、Prometheus、Kibana、企业后台管理系统、控制中心、调试面板集合、Dashboard 堆数据、Hacker 风格工具、参数配置平台或需要培训才能使用的软件。

不要为了展示能力增加功能；不要把 WebSocket、Flutter、selector、OCR、Runtime、Session、Device Bridge、Relay、UDID、ADB serial、endpoint、source XML 或原始日志放到主界面。不要为了工程实现简单、历史兼容或开发更快牺牲用户体验。

## Design Principles

1. UX first: 用户体验优先于产品一致性、可维护性、开发效率和历史兼容性。
2. Task first: 信息架构围绕用户任务组织，而不是围绕模块、技术或数据表组织。
3. Summary first: 默认只展示结果、状态和下一步；过程、日志、配置和底层字段进入 Drawer、Inspector、Advanced 或 Bottom Console。
4. One-screen and one-click bias: 能一屏完成就不拆屏，能一次点击就不要求第二次点击，机器能推断就不让用户填写。
5. Progressive complexity: 高级能力必须可发现、可展开、可诊断，但不能成为默认负担。
6. Native workstation: 遵循 macOS Human Interface Guidelines，优先使用 Sidebar、Toolbar、Inspector、Command Palette、Context Menu、快捷键、Drag & Drop 和系统反馈。
7. Safety without fear: 单设备、串行执行、安全停止、低置信暂停和本地隐私是底线，但界面表达应是清晰行动，不是技术警报。

## Accessibility & Inclusion

默认目标为 WCAG AA。界面必须支持键盘操作、清晰焦点态、可读对比度、可缩放文本、减少动效、状态不只依赖颜色表达。中文短文案优先动作导向；错误和空态要说明下一步，不使用内部枚举或含糊提示。
