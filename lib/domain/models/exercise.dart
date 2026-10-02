import '../../data/orm/entity_mapper.dart';
import '../../data/orm/excel_column.dart';

class Exercise {
  final String guid;
  final String name;
  final String bodyPart;

  Exercise({
    required this.guid,
    required this.name,
    required this.bodyPart,
  });

  Exercise copyWith({
    String? guid,
    String? name,
    String? bodyPart,
  }) {
    return Exercise(
      guid: guid ?? this.guid,
      name: name ?? this.name,
      bodyPart: bodyPart ?? this.bodyPart,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Guid': guid,
      'Exercise name': name,
      'Body part target': bodyPart,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    final rawGuid = map['Guid'] ?? map['Id'] ?? map['guid'] ?? map['id'];
    final rawName = map['Exercise name'] ?? map['exercise_name'] ?? map['name'];
    final rawBodyPart = map['Body part target'] ?? map['body_part_target'] ?? map['bodyPart'];

    return Exercise(
      guid: rawGuid?.toString() ?? '',
      name: rawName?.toString() ?? '',
      bodyPart: rawBodyPart?.toString() ?? '',
    );
  }

  /// ExcelORM Schema Mapper for Exercise entity
  static final ExcelEntityMapper<Exercise> excelMapper = ExcelEntityMapper<Exercise>(
    createEntity: () => Exercise(guid: '', name: '', bodyPart: ''),
    columns: [
      ExcelColumn<Exercise, String>(
        headerName: 'Id',
        getValue: (e) => e.guid,
        setValue: (e, v) => e.copyWith(guid: v),
        defaultValue: '',
      ),
      ExcelColumn<Exercise, String>(
        headerName: 'exercise_name',
        getValue: (e) => e.name,
        setValue: (e, v) => e.copyWith(name: v),
        defaultValue: '',
      ),
      ExcelColumn<Exercise, String>(
        headerName: 'body_part_target',
        getValue: (e) => e.bodyPart,
        setValue: (e, v) => e.copyWith(bodyPart: v),
        defaultValue: '',
      ),
    ],
  );

  @override
  String toString() => 'Exercise(guid: $guid, name: $name, bodyPart: $bodyPart)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Exercise &&
          runtimeType == other.runtimeType &&
          guid == other.guid &&
          name == other.name &&
          bodyPart == other.bodyPart;

  @override
  int get hashCode => guid.hashCode ^ name.hashCode ^ bodyPart.hashCode;
}
