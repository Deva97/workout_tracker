import 'package:excel/excel.dart';
import 'entity_mapper.dart';
import 'excel_table.dart';

/// Base Unit of Work context for reading, manipulating, and saving Excel workbooks.
abstract class ExcelContext {
  /// Parses Excel bytes into a strongly-typed [ExcelTable<T>].
  ///
  /// When [reverseRows] is true, rows are visited from bottom to top and
  /// parsing stops before adding the first entity for which [stopWhen] returns
  /// true.
  ExcelTable<T> loadTableFromBytes<T>({
    required List<int> bytes,
    required ExcelEntityMapper<T> mapper,
    String? sheetName,
    bool reverseRows = false,
    bool Function(T entity)? stopWhen,
  }) {
    assert(stopWhen == null || reverseRows);
    final decoder = Excel.decodeBytes(bytes);
    if (decoder.tables.isEmpty) {
      return ExcelTable<T>(sheetName: sheetName ?? 'Sheet1', mapper: mapper);
    }

    final targetSheetName = sheetName ?? decoder.tables.keys.first;
    final sheet = decoder.tables[targetSheetName] ?? decoder.tables.values.first;

    if (sheet.maxRows == 0) {
      return ExcelTable<T>(sheetName: targetSheetName, mapper: mapper);
    }

    final headerRow = sheet.row(0);
    final headerNames = headerRow
        .map((cell) => cell?.value?.toString().trim() ?? '')
        .toList();

    final entities = <T>[];

    final rowIndices = reverseRows
        ? Iterable<int>.generate(
            sheet.maxRows - 1,
            (index) => sheet.maxRows - index - 1,
          )
        : Iterable<int>.generate(sheet.maxRows - 1, (index) => index + 1);

    for (final i in rowIndices) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;

      final rowMap = <String, dynamic>{};
      for (int c = 0; c < headerNames.length && c < row.length; c++) {
        final headerName = headerNames[c];
        if (headerName.isNotEmpty) {
          rowMap[headerName] = row[c]?.value;
        }
      }

      // Check if row has any non-empty data
      final hasData = rowMap.values.any((val) {
        if (val == null) return false;
        return val.toString().trim().isNotEmpty;
      });

      if (hasData) {
        final entity = mapper.fromRow(rowMap);
        if (stopWhen?.call(entity) ?? false) break;
        entities.add(entity);
      }
    }

    return ExcelTable<T>(
      sheetName: targetSheetName,
      mapper: mapper,
      initialEntities: reverseRows ? entities.reversed.toList() : entities,
    );
  }

  /// Encodes an [ExcelTable<T>] entity set back into raw `.xlsx` file byte buffer.
  List<int> saveTableToBytes<T>(ExcelTable<T> table) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.tables.keys.first;
    final targetSheet = table.sheetName.isNotEmpty ? table.sheetName : 'Sheet1';

    if (defaultSheet != targetSheet) {
      excel.rename(defaultSheet, targetSheet);
    }

    final sheet = excel[targetSheet];

    // Write header row
    sheet.appendRow(table.mapper.headers);

    // Write data rows
    for (final entity in table) {
      final rowCellsMap = table.mapper.toRowCells(entity);
      final rowCells = table.mapper.headers
          .map((header) => rowCellsMap[header] ?? '')
          .toList();
      sheet.appendRow(rowCells);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel table to bytes.');
    }
    return bytes;
  }
}

