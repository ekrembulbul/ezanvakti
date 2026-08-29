/// Widget'a gönderilen payload'ın tipli karşılığı.
///
/// Saatler `"HH:mm"`, tarihler `"yyyy-MM-dd"` olarak serileştirilir; offset'li
/// ISO timestamp **bilerek** kullanılmaz. Uygulama vakitleri timezone
/// taşımayan cihaz-yerel wall-clock olarak üretiyor
/// (`awqat_salah_provider.dart:407`); offset yazmak widget'a uygulamada
/// olmayan bir timezone semantiği uydurmak olurdu.
class WidgetDayTimes {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  const WidgetDayTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  Map<String, String> toJson() => {
    'fajr': _hhmm(fajr),
    'sunrise': _hhmm(sunrise),
    'dhuhr': _hhmm(dhuhr),
    'asr': _hhmm(asr),
    'maghrib': _hhmm(maghrib),
    'isha': _hhmm(isha),
  };
}

class WidgetSnapshotDay {
  final DateTime date;
  final WidgetDayTimes times;

  const WidgetSnapshotDay({required this.date, required this.times});

  Map<String, dynamic> toJson() => {
    'date': _yyyyMMdd(date),
    'times': times.toJson(),
  };
}

class WidgetSnapshot {
  /// Swift tarafı bilmediği bir sürüm görürse "uygulamayı güncelleyin"
  /// durumuna düşer. Payload'ın şekli değişirse bu artırılmalı.
  static const int schemaVersion = 1;

  final String locationLabel;

  /// Yalnızca teşhis için. Bayatlık kararı buna değil, [days]'in son gününe
  /// bakılarak verilir: haftalarca açılmayan bir uygulamanın eski
  /// [generatedAt]'i, payload hâlâ geleceği kapsıyorsa bir sorun değildir.
  final DateTime generatedAt;

  final List<WidgetSnapshotDay> days;

  const WidgetSnapshot({
    required this.locationLabel,
    required this.generatedAt,
    required this.days,
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'locationLabel': locationLabel,
    'generatedAt':
        '${_yyyyMMdd(generatedAt)}T${_hhmm(generatedAt)}:'
        '${_two(generatedAt.second)}',
    'days': days.map((day) => day.toJson()).toList(),
  };
}

String _two(int value) => value.toString().padLeft(2, '0');

String _hhmm(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

String _yyyyMMdd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-'
    '${_two(date.day)}';
