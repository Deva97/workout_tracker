import '../../data/orm/entity_mapper.dart';
import '../../data/orm/excel_column.dart';

class DailyRecord {
  final String id;
  final String workoutId;
  final String workoutName;
  final DateTime date;
  final int set;
  final int reps;
  final double rir;
  final double weight;
  final String executionType;
  final String notes;

  DailyRecord({
    required this.id,
    required this.workoutId,
    required this.workoutName,
    required this.date,
    required this.set,
    required this.reps,
    required this.rir,
    this.weight = 0.0,
    this.executionType = 'bilateral',
    this.notes = '',
  });

  DailyRecord copyWith({
    String? id,
    String? workoutId,
    String? workoutName,
    DateTime? date,
    int? set,
    int? reps,
    double? rir,
    double? weight,
    String? executionType,
    String? notes,
  }) {
    return DailyRecord(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      workoutName: workoutName ?? this.workoutName,
      date: date ?? this.date,
      set: set ?? this.set,
      reps: reps ?? this.reps,
      rir: rir ?? this.rir,
      weight: weight ?? this.weight,
      executionType: executionType ?? this.executionType,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'workout_ID': workoutId,
      'workout_name': workoutName,
      'Date': date.toIso8601String(),
      'set': set,
      'reps': reps,
      'RIR': rir,
      'weight': weight,
      'execution_type': executionType,
      'notes': notes,
    };
  }

  factory DailyRecord.fromMap(Map<String, dynamic> map) {
    final rawDate = map['Date'] ?? map['date'];
    DateTime parsedDate = DateTime.now();
    if (rawDate != null) {
      if (rawDate is DateTime) {
        parsedDate = rawDate;
      } else {
        parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
      }
    }

    return DailyRecord(
      id: map['ID']?.toString() ?? map['id']?.toString() ?? '',
      workoutId: map['workout_ID']?.toString() ?? map['workoutId']?.toString() ?? '',
      workoutName: map['workout_name']?.toString() ?? map['workoutName']?.toString() ?? '',
      date: parsedDate,
      set: int.tryParse(map['set']?.toString() ?? '') ?? 0,
      reps: int.tryParse(map['reps']?.toString() ?? '') ?? 0,
      rir: double.tryParse(map['RIR']?.toString() ?? map['rir']?.toString() ?? '') ?? 0.0,
      weight: double.tryParse(map['weight']?.toString() ?? map['Weight']?.toString() ?? '') ?? 0.0,
      executionType: (map['execution_type'] ?? map['executionType'] ?? 'bilateral').toString(),
      notes: (map['notes'] ?? map['Notes'] ?? '').toString(),
    );
  }

  /// ExcelORM Schema Mapper for DailyRecord entity
  static final ExcelEntityMapper<DailyRecord> excelMapper = ExcelEntityMapper<DailyRecord>(
    createEntity: () => DailyRecord(
      id: '',
      workoutId: '',
      workoutName: '',
      date: DateTime.now(),
      set: 0,
      reps: 0,
      rir: 0.0,
      weight: 0.0,
      executionType: 'bilateral',
      notes: '',
    ),
    columns: [
      ExcelColumn<DailyRecord, String>(
        headerName: 'ID',
        getValue: (r) => r.id,
        setValue: (r, v) => r.copyWith(id: v),
        defaultValue: '',
      ),
      ExcelColumn<DailyRecord, String>(
        headerName: 'workout_ID',
        getValue: (r) => r.workoutId,
        setValue: (r, v) => r.copyWith(workoutId: v),
        defaultValue: '',
      ),
      ExcelColumn<DailyRecord, String>(
        headerName: 'workout_name',
        getValue: (r) => r.workoutName,
        setValue: (r, v) => r.copyWith(workoutName: v),
        defaultValue: '',
      ),
      ExcelColumn<DailyRecord, DateTime>(
        headerName: 'Date',
        getValue: (r) => r.date,
        setValue: (r, v) => r.copyWith(date: v),
        defaultValue: DateTime.now(),
      ),
      ExcelColumn<DailyRecord, int>(
        headerName: 'set',
        getValue: (r) => r.set,
        setValue: (r, v) => r.copyWith(set: v),
        defaultValue: 0,
      ),
      ExcelColumn<DailyRecord, int>(
        headerName: 'reps',
        getValue: (r) => r.reps,
        setValue: (r, v) => r.copyWith(reps: v),
        defaultValue: 0,
      ),
      ExcelColumn<DailyRecord, double>(
        headerName: 'RIR',
        getValue: (r) => r.rir,
        setValue: (r, v) => r.copyWith(rir: v),
        defaultValue: 0.0,
      ),
      ExcelColumn<DailyRecord, double>(
        headerName: 'weight',
        getValue: (r) => r.weight,
        setValue: (r, v) => r.copyWith(weight: v),
        defaultValue: 0.0,
      ),
      ExcelColumn<DailyRecord, String>(
        headerName: 'execution_type',
        getValue: (r) => r.executionType,
        setValue: (r, v) => r.copyWith(executionType: v),
        defaultValue: 'bilateral',
      ),
      ExcelColumn<DailyRecord, String>(
        headerName: 'notes',
        getValue: (r) => r.notes,
        setValue: (r, v) => r.copyWith(notes: v),
        defaultValue: '',
      ),
    ],
  );

  @override
  String toString() =>
      'DailyRecord(id: $id, workoutId: $workoutId, workoutName: $workoutName, date: $date, set: $set, reps: $reps, rir: $rir, weight: $weight, executionType: $executionType, notes: $notes)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workoutId == other.workoutId &&
          workoutName == other.workoutName &&
          date == other.date &&
          set == other.set &&
          reps == other.reps &&
          rir == other.rir &&
          weight == other.weight &&
          executionType == other.executionType &&
          notes == other.notes;

  @override
  int get hashCode =>
      id.hashCode ^
      workoutId.hashCode ^
      workoutName.hashCode ^
      date.hashCode ^
      set.hashCode ^
      reps.hashCode ^
      rir.hashCode ^
      weight.hashCode ^
      executionType.hashCode ^
      notes.hashCode;
}
