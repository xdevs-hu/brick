import 'package:analyzer/dart/element/element.dart';
import 'package:brick_build/generators.dart';
import 'package:brick_sqlite/brick_sqlite.dart';
import 'package:brick_sqlite_generators/sqlite_model_serdes_generator.dart';
import 'package:test/test.dart';
import 'package:source_gen/source_gen.dart';
import 'package:brick_build_test/brick_build_test.dart';

import 'sqlite_model_serdes_generator/test_sqlite_column_type.dart' as sqliteColumnType;
import 'sqlite_model_serdes_generator/test_sqlite_unique.dart' as sqliteUnique;
import 'sqlite_model_serdes_generator/test_sqlite_enum_as_string.dart' as sqliteEnumAsString;
import 'sqlite_model_serdes_generator/test_field_with_type_argument.dart' as fieldWithTypeArgument;
import 'sqlite_model_serdes_generator/test_boolean_fields.dart' as booleanFields;
import 'sqlite_model_serdes_generator/test_after_save_with_association.dart'
    as afterSaveWithAssociation;
import 'sqlite_model_serdes_generator/test_all_field_types.dart' as allFieldTypes;
import 'sqlite_model_serdes_generator/test_to_json_from_json.dart' as toJsonFromJson;

final _generator = TestGenerator();
final folder = 'sqlite_model_serdes_generator';
final generateReader = generateLibraryForFolder(folder);

void main() {
  group('SqliteModelSerdesGenerator', () {
    group('incorrect', () {
      test('IdField', () async {
        final reader = await generateReader('id_field');
        expect(
          () async => await _generator.generate(reader, MockBuildStep()),
          throwsA(TypeMatcher<InvalidGenerationSourceError>()),
        );
      });

      test('PrimaryKeyField', () async {
        final reader = await generateReader('primary_key_field');
        expect(
          () async => await _generator.generate(reader, MockBuildStep()),
          throwsA(TypeMatcher<InvalidGenerationSourceError>()),
        );
      });

      test('ColumnTypeWithoutFrom', () async {
        final reader = await generateReader('column_type_without_generator');
        expect(
          () async => await _generator.generate(reader, MockBuildStep()),
          throwsA(TypeMatcher<InvalidGenerationSourceError>()),
        );
      });
    });

    group('@Sqlite', () {
      test('columnType', () async {
        await generateAdapterExpectation('sqlite_column_type', sqliteColumnType.output);
      });

      test('unique', () async {
        await generateAdapterExpectation('sqlite_unique', sqliteUnique.output);
      });

      test('enumAsString', () async {
        await generateAdapterExpectation('sqlite_enum_as_string', sqliteEnumAsString.output);
      });
    });

    test('FieldWithTypeArgument', () async {
      await generateAdapterExpectation('field_with_type_argument', fieldWithTypeArgument.output);
    });

    test('BooleanFields', () async {
      await generateAdapterExpectation('boolean_fields', booleanFields.output);
    });

    test('AfterSaveWithAssociation', () async {
      await generateAdapterExpectation(
          'after_save_with_association', afterSaveWithAssociation.output);
    });

    test('AllFieldTypes', () async {
      await generateAdapterExpectation('all_field_types', allFieldTypes.output);
    });

    test('ToJsonFromJson', () async {
      await generateAdapterExpectation('to_json_from_json', toJsonFromJson.output);
    });
  });
}

/// Output serializing code for all models with the @[SqliteSerializable] annotation.
/// [SqliteSerializable] **does not** produce code.
/// A `const` class is required from an non-relative import,
/// and [SqliteSerializable] was arbitrarily chosen for this test.
/// This will do nothing outside of this exact test suite.
class TestGenerator extends AnnotationSuperGenerator<SqliteSerializable> {
  @override
  final superAdapterName = 'Sqlite';
  final repositoryName = 'SqliteFirst';

  TestGenerator();

  /// Given an [element] and an [annotation], scaffold generators
  @override
  List<SerdesGenerator> buildGenerators(Element element, ConstantReader annotation) {
    final serializableGenerator =
        SqliteModelSerdesGenerator(element, annotation, repositoryName: repositoryName);
    return serializableGenerator.generators;
  }
}

Future<void> generateExpectation(String filename, String output, {TestGenerator? generator}) async {
  final reader = await generateReader(filename);
  final generated = await (generator ?? _generator).generate(reader, MockBuildStep());
  expect(generated.trim(), output.trim());
}

Future<void> generateAdapterExpectation(String filename, String output) async {
  final annotation = await annotationForFile<SqliteSerializable>(folder, filename);
  final generated = _generator.generateAdapter(
    annotation.element,
    annotation.annotation,
    null,
  );
  expect(generated.trim(), output.trim());
}
