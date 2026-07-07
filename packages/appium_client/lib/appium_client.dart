library;

// Appium Client 公共入口，向 Runtime 暴露最小 WebDriver / Appium 能力。
// 包内实现按协议模型、传输和动作拆分，外部仍只从本文件导入。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

part 'src/appium_actions.dart';
part 'src/appium_client_core.dart';
part 'src/appium_config.dart';
part 'src/appium_error.dart';
part 'src/appium_mobile_command.dart';
part 'src/appium_session.dart';
part 'src/appium_status.dart';
part 'src/appium_transport.dart';
part 'src/appium_viewport.dart';
