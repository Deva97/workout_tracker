import '../../data/orm/entity_mapper.dart';
import '../../data/orm/excel_column.dart';

class WeightRecord {
  final String id;
  final DateTime date;
  final double weight;
  final String unit;
  final String notes;

  const WeightRecord({
    required this.id,
    required this.date,
    required this.weight,
    this.unit = 'kg',
    this.notes = '',
  });

  WeightRecord copyWith({
    String? id,
    DateTime? date,
    double? weight,
    String? unit,
    String? notes,
  }) {
    return WeightRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'Date': date.toIso8601String(),
      'Weight': weight,
      'Unit': unit,
      'Notes': notes,
    };
  }

  factory WeightRecord.fromMap(Map<String, dynamic> map) {
    return WeightRecord(
      id: (map['ID'] ?? '').toString(),
      date: map['Date'] != null ? DateTime.parse(map['Date'].toString()) : DateTime.now(),
      weight: map['Weight'] is num ? (map['Weight'] as num).toDouble() : double.tryParse(map['Weight']?.toString() ?? '0') ?? 0.0,
      unit: (map['Unit'] ?? 'kg').toString(),
      notes: (map['Notes'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory WeightRecord.fromJson(Map<String, dynamic> json) => WeightRecord.fromMap(json);

  /// ExcelORM Schema Mapper for WeightRecord entity
  static final ExcelEntityMapper<WeightRecord> excelMapper = ExcelEntityMapper<WeightRecord>(
    createEntity: () => WeightRecord(
      id: '',
      date: DateTime.now(),
      weight: 0.0,
      unit: 'kg',
      notes: '',
    ),
    columns: [
      ExcelColumn<WeightRecord, String>(
        headerName: 'ID',
        getValue: (r) => r.id,
        setValue: (r, v) => r.copyWith(id: v),
        defaultValue: '',
      ),
      ExcelColumn<WeightRecord, DateTime>(
        headerName: 'Date',
        getValue: (r) => r.date,
        setValue: (r, v) => r.copyWith(date: v),
        defaultValue: DateTime.now(),
      ),
      ExcelColumn<WeightRecord, double>(
        headerName: 'Weight',
        getValue: (r) => r.weight,
        setValue: (r, v) => r.copyWith(weight: v),
        defaultValue: 0.0,
      ),
      ExcelColumn<WeightRecord, String>(
        headerName: 'Unit',
        getValue: (r) => r.unit,
        setValue: (r, v) => r.copyWith(unit: v),
        defaultValue: 'kg',
      ),
      ExcelColumn<WeightRecord, String>(
        headerName: 'Notes',
        getValue: (r) => r.notes,
        setValue: (r, v) => r.copyWith(notes: v),
        defaultValue: '',
      ),
    ],
  );

  @override
  String toString() =>
      'WeightRecord(id: $id, date: $date, weight: $weight, unit: $unit, notes: $notes)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          weight == other.weight &&
          unit == other.unit &&
          notes == other.notes;

  @override
  int get hashCode =>
      id.hashCode ^
      date.year.hashCode ^
      date.month.hashCode ^
      date.day.hashCode ^
      weight.hashCode ^
      unit.hashCode ^
      notes.hashCode;
}
