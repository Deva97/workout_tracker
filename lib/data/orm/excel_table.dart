import 'dart:collection';
import 'entity_mapper.dart';
import 'excel_query.dart';

/// Represents a strongly-typed entity set mapped to an Excel sheet.
class ExcelTable<T> extends IterableMixin<T> {
  final String sheetName;
  final ExcelEntityMapper<T> mapper;
  final List<T> _entities = [];

  ExcelTable({
    required this.sheetName,
    required this.mapper,
    List<T>? initialEntities,
  }) {
    if (initialEntities != null) {
      _entities.addAll(initialEntities);
    }
  }

  @override
  Iterator<T> get iterator => _entities.iterator;

  /// Creates a fluid query builder starting from this table.
  ExcelQuery<T> query() => ExcelQuery<T>(_entities);

  /// Fluid query shorthand: filter table entities matching [predicate].
  ExcelQuery<T> whereQuery(bool Function(T element) predicate) => query().where(predicate);

  /// Fluid query shorthand: sort table entities by [keySelector].
  ExcelQuery<T> orderBy<K extends Comparable<dynamic>>(K Function(T element) keySelector) =>
      query().orderBy(keySelector);

  /// Fluid query shorthand: sort table entities descending by [keySelector].
  ExcelQuery<T> orderByDescending<K extends Comparable<dynamic>>(K Function(T element) keySelector) =>
      query().orderByDescending(keySelector);

  /// Return first matching element or `null` if empty.
  T? firstOrDefault([bool Function(T element)? predicate]) => query().firstOrDefault(predicate);

  /// Add entity to table set.
  void add(T entity) {
    _entities.add(entity);
  }

  /// Add multiple entities to table set.
  void addAll(Iterable<T> entities) {
    _entities.addAll(entities);
  }

  /// Update matching entity in table set based on key predicate.
  bool update(T updatedEntity, bool Function(T existing) keyPredicate) {
    final index = _entities.indexWhere(keyPredicate);
    if (index != -1) {
      _entities[index] = updatedEntity;
      return true;
    }
    return false;
  }

  /// Update entities matching [predicate] using [updater] function.
  int updateWhere(T Function(T existing) updater, bool Function(T element) predicate) {
    int count = 0;
    for (int i = 0; i < _entities.length; i++) {
      if (predicate(_entities[i])) {
        _entities[i] = updater(_entities[i]);
        count++;
      }
    }
    return count;
  }

  /// Delete matching entity from table set.
  bool delete(T entity) {
    return _entities.remove(entity);
  }

  /// Delete entities matching [predicate] from table set.
  int deleteWhere(bool Function(T element) predicate) {
    final initialLength = _entities.length;
    _entities.removeWhere(predicate);
    return initialLength - _entities.length;
  }

  /// Clear all entities from table set.
  void clear() {
    _entities.clear();
  }

  /// Return view of internal entities list.
  @override
  List<T> toList({bool growable = true}) {
    return List<T>.from(_entities, growable: growable);
  }
}
