# Legacy Node Archive

本目录保存 iOS Assist Studio V1 / 迁移期的 Node、Web Console 和 CLI 实现。

## 定位

- 仅用于 Legacy 对照、调试和迁移参考。
- 不再作为 V2.0 产品主入口。
- 不允许 Flutter App 或 Dart packages 调用本目录下的脚本或 Web API。

## 入口

旧入口统一通过根目录 `package.json` 的 `legacy:*` 脚本触发，例如：

```bash
npm run legacy:console:connected
npm run legacy:init:connected
npm run legacy:click:connected
```

V2.0 默认验证使用 Dart / Flutter：

```bash
fvm dart run tool/v2_verify.dart
```

## 维护规则

- 新功能优先落到 `apps/studio_mac` 或 `packages/*`。
- 如必须修复 Legacy bug，只修改 `legacy/node/src/` 并运行对应 `legacy:smoke:*`。
- 不恢复根目录 `src/`。
- 不新增无 `legacy:` 前缀的 Node 产品入口。
