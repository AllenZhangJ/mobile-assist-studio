import 'package:workflow_dsl/workflow_dsl.dart';

void main() {
  final workflow = WorkflowDefinition.afTemplate();
  final result = const WorkflowValidator().validate(workflow);
  print(
    '${workflow.name}: ${result.isValid ? 'valid' : result.errors.join(', ')}',
  );
}
