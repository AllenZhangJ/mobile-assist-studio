part of '../appium_client.dart';

// 受控移动端硬件键枚举，只暴露 V2.0 UI 明确允许的动作。
// 不让上层传任意 mobile script，避免形成脚本平台。
enum AppiumMobileButton {
  home('home');

  const AppiumMobileButton(this.wireName);

  final String wireName;
}

// 受控 Android 硬件键枚举，只暴露 Runtime 明确允许的动作。
// 避免上层直接传入任意 keycode 形成不受控设备命令。
enum AppiumAndroidKey {
  home(3);

  const AppiumAndroidKey(this.keyCode);

  final int keyCode;
}
