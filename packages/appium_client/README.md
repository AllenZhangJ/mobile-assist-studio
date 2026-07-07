# appium_client

`appium_client` 是 iOS Assist Studio V2.0 使用的最小 Dart Appium / WebDriver 客户端。

它只覆盖本地 Mac 工作站需要的能力，不定位为通用 Appium SDK。

## 职责

- 读取本机 Appium `/status`。
- 创建和关闭 WebDriver session。
- 读取截图、页面结构和 viewport 尺寸。
- 发送 W3C pointer tap / swipe。
- 发送当前焦点文本输入。
- 释放 pointer actions。
- 把 socket、HTTP 和响应结构错误映射为 `AppiumClientException`。

## 边界

- 不启动 Appium 进程。
- 不管理 WebDriver session 生命周期状态。
- 不保存截图、日志或运行证据。
- 不做设备发现。
- 不解析 Project DSL。
- 不展示 UI 文案。

上述能力属于 `studio_runtime` 或 Flutter App。

## 包入口

使用：

```dart
import 'package:appium_client/appium_client.dart';
```

核心类型：

- `AppiumServerConfig`
- `AppiumClient`
- `AppiumStatus`
- `AppiumSessionRequest`
- `WebDriverSession`
- `ViewportPoint`
- `ViewportSize`

`lib/src/` 下按职责拆分：

- `appium_config.dart`：本机 Appium endpoint 和 URI 解析。
- `appium_error.dart`：统一异常类型。
- `appium_status.dart`：`/status` 响应模型。
- `appium_session.dart`：session 请求和响应模型。
- `appium_viewport.dart`：viewport 坐标与尺寸模型。
- `appium_transport.dart`：最小 JSON HTTP transport。
- `appium_actions.dart`：W3C pointer action payload。
- `appium_client_core.dart`：对 Runtime 暴露的最小 client 门面。

`appium_client.dart` 只作为公共入口和 part 汇总，不承载具体实现。

## 验证

```sh
fvm dart test
```

测试使用本地 fake HTTP server，不需要真实 iPhone、不需要真实 Appium 服务。
