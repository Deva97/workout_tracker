/// A fluid query builder for filtering, sorting, pagination, and projection over entities of type [T].
class ExcelQuery<T> {
  final Iterable<T> _source;

  ExcelQuery(this._source);

  /// Filter entities by predicate condition.
  ExcelQuery<T> where(bool Function(T element) predicate) {
    return ExcelQuery<T>(_source.where(predicate));
  }

  /// Sort entities in ascending order using key selector.
  ExcelQuery<T> orderBy<K extends Comparable<dynamic>>(K Function(T element) keySelector) {
    final list = _source.toList();
    list.sort((a, b) => keySelector(a).compareTo(keySelector(b)));
    return ExcelQuery<T>(list);
  }

  /// Sort entities in descending order using key selector.
  ExcelQuery<T> orderByDescending<K extends Comparable<dynamic>>(K Function(T element) keySelector) {
    final list = _source.toList();
    list.sort((a, b) => keySelector(b).compareTo(keySelector(a)));
    return ExcelQuery<T>(list);
  }

  /// Skip [count] elements from query output.
  ExcelQuery<T> skip(int count) {
    return ExcelQuery<T>(_source.skip(count));
  }

  /// Take at most [count] elements from query output.
  ExcelQuery<T> take(int count) {
    return ExcelQuery<T>(_source.take(count));
  }

  /// Project elements into new type [R].
  Iterable<R> select<R>(R Function(T element) selector) {
    return _source.map(selector);
  }

  /// Return first matching element or throw if empty.
  T first([bool Function(T element)? predicate]) {
    if (predicate != null) {
      return _source.firstWhere(predicate);
    }
    return _source.first;
  }

  /// Return first matching element or `null` if none found.
  T? firstOrDefault([bool Function(T element)? predicate]) {
    final targetSource = predicate != null ? _source.where(predicate) : _source;
    if (targetSource.isEmpty) return null;
    return targetSource.first;
  }

  /// Return single element matching predicate or throw if zero or multiple exist.
  T single([bool Function(T element)? predicate]) {
    if (predicate != null) {
      return _source.singleWhere(predicate);
    }
    return _source.single;
  }

  /// Return single element matching predicate or `null` if none exist. Throws if multiple exist.
  T? singleOrDefault([bool Function(T element)? predicate]) {
    final targetSource = predicate != null ? _source.where(predicate) : _source;
    if (targetSource.isEmpty) return null;
    return targetSource.single;
  }

  /// Count elements matching predicate, or total elements if predicate is omitted.
  int count([bool Function(T element)? predicate]) {
    if (predicate != null) {
      return _source.where(predicate).length;
    }
    return _source.length;
  }

  /// Check if any element matches predicate, or if collection is non-empty if predicate is omitted.
  bool any([bool Function(T element)? predicate]) {
    if (predicate != null) {
      return _source.any(predicate);
    }
    return _source.isNotEmpty;
  }

  /// Check if all elements match predicate.
  bool all(bool Function(T element) predicate) {
    return _source.every(predicate);
  }

  /// Evaluate query and materialize results into a [List<T>].
  List<T> toList() {
    return _source.toList();
  }
}

