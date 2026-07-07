# iOS Assist Studio

`iOS Assist Studio` 是一个基于 `Mac + Appium + WebDriverAgent` 的 iPhone 真机辅助自动化工具。它用于合法的真机 QA、个人辅助操作实验，以及你自己有权限控制的 App。

V2.0 主入口是 Flutter Desktop Mac App：`apps/studio_mac`。旧 Node/Web/CLI 已归档到 `legacy/node/src`，只作为 Legacy、Debug 和迁移参考。

## 快速启动

进入项目根目录后运行：

V2.0 Flutter Desktop 开发入口：

```bash
melos bootstrap
melos run analyze
melos run test
cd apps/studio_mac
fvm flutter run -d macos
```

Legacy 本地 Web 看板仅用于对照调试：

```bash
npm run legacy:console:connected
```

默认地址：

```text
http://127.0.0.1:4877/
```

Legacy CLI 入口仅用于对照调试：

```bash
npm run legacy:init:connected
npm run legacy:click:connected 1 -- --log-level progress
```

V2.0 常用验证：

```bash
fvm dart run tool/v2_boundary_check.dart
fvm dart run melos run analyze
fvm dart run melos run test
fvm dart run tool/macos_build_smoke.dart
```

完整本地验证：

```bash
fvm dart run tool/v2_verify.dart
```

## 文档入口

文档目录：

- [AI_PROJECT_CONTEXT.md](./AI_PROJECT_CONTEXT.md)
- [AGENTS.md](./AGENTS.md)
- [docs/README.md](./docs/README.md)
- [docs/V4.0-PRD-Mobile-Automation-Workstation.md](./docs/V4.0-PRD-Mobile-Automation-Workstation.md)
- [docs/iOS Assist Studio项目文档v1.0.md](./docs/iOS%20Assist%20Studio项目文档v1.0.md)

## Source of Truth

- 长期维护的项目说明、V2 Mac App、Legacy 对照、配置真值、错误排查统一放在 `docs/`
- V4.0 产品定位、融合架构、开源吸纳和批次路线统一放在 `docs/`
- V2.0 Flutter Desktop、Monorepo、迁移计划和开发计划统一放在 `docs/`
- 根目录 `README.md` 只保留简介、快速启动和文档入口
