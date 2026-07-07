import 'package:workflow_dsl/workflow_dsl.dart';

// Workflow DSL 测试共享夹具，只放跨文件复用的无状态对象。
// 保持这里极小，避免测试语义被隐藏到 support 层。
const workflowValidator = WorkflowValidator();
