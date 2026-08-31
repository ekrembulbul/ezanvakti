/// Bir günün oruç durumu.
enum FastingStatus {
  fasted,

  /// Tutulmadı, kazası var.
  missed,

  /// Tutulmadı ve kazası yok (yolculuk, hastalık, hayız gibi).
  exempt,
}

extension FastingStatusX on FastingStatus {
  String get storageValue => switch (this) {
    FastingStatus.fasted => 'fasted',
    FastingStatus.missed => 'missed',
    FastingStatus.exempt => 'exempt',
  };

  static FastingStatus? fromStorage(String? value) {
    if (value == null) return null;
    for (final status in FastingStatus.values) {
      if (status.storageValue == value) return status;
    }
    return null;
  }
}

/// Izgaradaki dokunuş döngüsü: boş → tuttum → kaza → muaf → boş.
FastingStatus? nextFastingStatus(FastingStatus? current) => switch (current) {
  null => FastingStatus.fasted,
  FastingStatus.fasted => FastingStatus.missed,
  FastingStatus.missed => FastingStatus.exempt,
  FastingStatus.exempt => null,
};

/// Kayıt anahtarı: `yyyy-MM-dd`.
String fastingLogKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
