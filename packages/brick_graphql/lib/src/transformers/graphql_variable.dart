import 'package:gql/ast.dart';

class GraphqlVariable {
  /// The `UpdatePersonInput` in `mutation UpdatePerson($input: UpdatePersonInput)`
  final String className;

  /// The `input` in `mutation UpdatePerson($input: UpdatePersonInput)`
  final String name;

  /// A `!` in `mutation UpdatePerson($input: UpdatePersonInput!)` indicates that the
  /// input value cannot be nullable.
  /// Defaults `false`.
  final bool nullable;

  final bool isList;
  final bool nullableList;

  const GraphqlVariable({
    required this.className,
    required this.name,
    this.nullable = false,
    this.isList = false,
    this.nullableList = false,
  });

  factory GraphqlVariable.fromVariableDefinitionNode(VariableDefinitionNode node) {
    var currentNode;
    var isList = false;
    var nullableList = false;

    if (node.type is ListTypeNode) {
      final listNode = node.type as ListTypeNode;
      currentNode = listNode.type as NamedTypeNode;

      isList = true;
      nullableList = !listNode.isNonNull;
    } else {
      currentNode = node.type as NamedTypeNode;
    }

    return GraphqlVariable(
      className: currentNode.name.value,
      name: node.variable.name.value,
      isList: isList,
      nullableList: nullableList,
    );
  }

  static List<GraphqlVariable> fromOperationNode(OperationDefinitionNode node) {
    return node.variableDefinitions
        .map((v) => GraphqlVariable.fromVariableDefinitionNode(v))
        .toList()
        .cast<GraphqlVariable>();
  }
}
