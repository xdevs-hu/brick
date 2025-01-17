import 'package:brick_offline_first_with_graphql/brick_offline_first_with_graphql.dart';
import 'package:brick_offline_first_with_graphql_build/src/offline_first_with_graphql_generator.dart';
import 'package:test/test.dart';
import 'package:brick_build_test/brick_build_test.dart';

import 'offline_first_generator/test_graphql_config_field_rename.dart' as graphqlConfigFieldRename;
import 'offline_first_generator/test_graphql_config_query_operation_transformer.dart'
    as graphqlConfigQueryOperationTransformer;
import 'offline_first_generator/test_custom_serdes.dart' as customSerdes;
import 'offline_first_generator/test_specify_field_name.dart' as specifyFieldName;
import 'offline_first_generator/test_offline_first_where_rename.dart' as offlineFirstWhereRename;

final _generator = OfflineFirstWithGraphqlGenerator();
final folder = 'offline_first_generator';
final generateReader = generateLibraryForFolder(folder);

void main() {
  group('OfflineFirstWithGraphqlGenerator', () {
    group('#generate', () {
      test('CustomSerdes', () async {
        await generateExpectation('custom_serdes', customSerdes.output);
      });
    });

    group('@ConnectOfflineFirstWithGraphql', () {
      test('graphqlSerializable#fieldRename', () async {
        await generateExpectation('graphql_config_field_rename', graphqlConfigFieldRename.output);
      });

      test('graphqlSerializable#queryOperationTransformer', () async {
        await generateAdapterExpectation(
          'graphql_config_query_operation_transformer',
          graphqlConfigQueryOperationTransformer.output,
        );
      });
    });

    group('FieldSerializable', () {
      test('name', () async {
        await generateExpectation('specify_field_name', specifyFieldName.output);
      });
    });

    group('OfflineFirst(where:)', () {
      test('renames the definition', () async {
        await generateAdapterExpectation(
            'offline_first_where_rename', offlineFirstWhereRename.output);
      });
    });
  });
}

Future<void> generateExpectation(String filename, String output,
    {OfflineFirstWithGraphqlGenerator? generator}) async {
  final reader = await generateReader(filename);
  final generated = await (generator ?? _generator).generate(reader, MockBuildStep());
  expect(generated.trim(), output.trim());
}

Future<void> generateAdapterExpectation(String filename, String output,
    {OfflineFirstWithGraphqlGenerator? generator}) async {
  final annotation = await annotationForFile<ConnectOfflineFirstWithGraphql>(folder, filename);
  final generated = (generator ?? _generator).generateAdapter(
    annotation.element,
    annotation.annotation,
    MockBuildStep(),
  );
  expect(generated.trim(), output.trim());
}
