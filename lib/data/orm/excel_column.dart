/// Defines mapping and value converters for a single column in an Excel sheet.
class ExcelColumn<T, V> {
  /// The header column title in the Excel sheet (case-insensitive mapping).
  final String headerName;

  /// Extracts the column value [V] from an entity instance [T].
  final V Function(T entity) getValue;

  /// Updates or constructs a copy of [T] with a new column value [V].
  final T Function(T entity, V value) setValue;

  /// Optional fallback default value if Excel cell is empty or null.
  final V defaultValue;

  const ExcelColumn({
    required this.headerName,
    required this.getValue,
    required this.setValue,
    required this.defaultValue,
  });

  /// Parse raw cell value from Excel row cell into typed value [V] and assign to [entity].
  T setParsedValue(T entity, dynamic rawValue) {
    final V parsed = parseCellValue(rawValue);
    return setValue(entity, parsed);
  }

  /// Parse raw cell value from Excel row cell into typed value [V].
  V parseCellValue(dynamic rawValue) {
    if (rawValue == null) return defaultValue;

    final extractedValue = rawValue;
    if (extractedValue == null) return defaultValue;

    if (V == String) {
      return extractedValue.toString() as V;
    } else if (V == int) {
      if (extractedValue is int) return extractedValue as V;
      if (extractedValue is double) return extractedValue.toInt() as V;
      final parsed = int.tryParse(extractedValue.toString());
      return (parsed ?? defaultValue) as V;
    } else if (V == double) {
      if (extractedValue is double) return extractedValue as V;
      if (extractedValue is int) return extractedValue.toDouble() as V;
      final parsed = double.tryParse(extractedValue.toString());
      return (parsed ?? defaultValue) as V;
    } else if (V == bool) {
      if (extractedValue is bool) return extractedValue as V;
      final str = extractedValue.toString().toLowerCase();
      if (str == 'true' || str == '1' || str == 'yes') return true as V;
      if (str == 'false' || str == '0' || str == 'no') return false as V;
      return defaultValue;
    } else if (V == DateTime) {
      if (extractedValue is DateTime) return extractedValue as V;
      final parsed = DateTime.tryParse(extractedValue.toString());
      return (parsed ?? defaultValue) as V;
    }

    return extractedValue as V;
  }

  /// Converts typed value [V] from entity into a format compatible with Excel sheet row writing.
  dynamic toCellValue(T entity) {
    final value = getValue(entity);
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value;
  }
}

