import 'package:studio_runtime/studio_runtime.dart';

void main() {
  final snapshot = StudioRuntimeSnapshot.initial();
  print('${snapshot.connectionStatus.name}/${snapshot.runStatus.name}');
}
