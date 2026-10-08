/// Telefonun Rahatsız Etme'de olacağı tek kesintisiz aralık.
class QuietInterval {
  final DateTime start;
  final DateTime end;

  const QuietInterval(this.start, this.end);

  Map<String, int> toMap() => {
    'startMillis': start.millisecondsSinceEpoch,
    'endMillis': end.millisecondsSinceEpoch,
  };

  @override
  bool operator ==(Object other) =>
      other is QuietInterval && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'QuietInterval($start – $end)';
}
