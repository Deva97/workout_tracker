import 'excel_column.dart';

/// Provides reflection-free mapping between entity instances of type [T] and Excel sheet rows.
class ExcelEntityMapper<T> {
  final List<ExcelColumn<T, dynamic>> columns;
  final T Function() createEntity;

  const ExcelEntityMapper({
    required this.columns,
    required this.createEntity,
  });

  /// Returns the list of column header names mapped by this entity schema.
  List<String> get headers => columns.map((col) => col.headerName).toList();

  /// Converts a row of cell values indexed by header names into an instance of [T].
  T fromRow(Map<String, dynamic> rowMap) {
    T entity = createEntity();

    for (final col in columns) {
      final rawVal = rowMap[col.headerName] ?? rowMap[_findCaseInsensitiveKey(rowMap, col.headerName)];
      entity = col.setParsedValue(entity, rawVal);
    }

    return entity;
  }

  /// Converts an instance of [T] into a row cell value map (headerName -> rawCellValue).
  Map<String, dynamic> toRowCells(T entity) {
    final map = <String, dynamic>{};
    for (final col in columns) {
      map[col.headerName] = col.toCellValue(entity);
    }
    return map;
  }

  String? _findCaseInsensitiveKey(Map<String, dynamic> map, String targetKey) {
    final targetLower = targetKey.trim().toLowerCase();
    for (final key in map.keys) {
      if (key.trim().toLowerCase() == targetLower) {
        return key;
      }
    }
    return null;
  }
}

