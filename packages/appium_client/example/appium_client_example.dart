import 'package:appium_client/appium_client.dart';

Future<void> main() async {
  final client = AppiumClient();
  final status = await client.status();
  client.close(force: true);
  print('Appium ready: ${status.ready}');
}
