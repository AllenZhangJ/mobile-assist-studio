library;

// Workflow DSL 公共入口，承载 Project DSL 的模型、模板、解析和校验。
// Flutter App 与 Runtime 都只从这里导入，不直接依赖 src 分片。
part 'src/workflow_json.dart';
part 'src/workflow_models.dart';
part 'src/workflow_templates.dart';
part 'src/workflow_validation.dart';
part 'src/workflow_validation_node_parameters.dart';
