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

/// Günün yaklaşık kerahat aralığı; başlangıç dahil, bitiş hariç.
///
/// Swift tarafı hesaplamaz: 45/10/45 dakikalık sabitler ve sınır kuralları
/// tek yerde (`KerahatTimes`) kalsın, widget uygulamayla aynı aralığı göstersin.
class WidgetKerahatInterval {
  final DateTime start;
  final DateTime end;

  const WidgetKerahatInterval({required this.start, required this.end});

  Map<String, String> toJson() => {'start': _hhmm(start), 'end': _hhmm(end)};
}

class WidgetSnapshotDay {
  final DateTime date;
  final WidgetDayTimes times;

  /// Uygulamanın gösterdiği hicri tarih (`HijriFormatter.format` çıktısı).
  ///
  /// Swift tarafında hesaplanmıyor: iOS'un `islamicUmmAlQura` takvimi
  /// uygulamanın kullandığı `hijri` paketinden gün kayabiliyor ve widget'ın
  /// uygulamadan farklı tarih göstermesi kabul edilemez.
  final String hijri;

  /// Günün kerahat aralıkları (v4); boş liste de geçerlidir.
  final List<WidgetKerahatInterval> kerahat;

  const WidgetSnapshotDay({
    required this.date,
    required this.times,
    required this.hijri,
    this.kerahat = const [],
  });

  Map<String, dynamic> toJson() => {
    'date': _yyyyMMdd(date),
    'hijri': hijri,
    'times': times.toJson(),
    'kerahat': kerahat.map((interval) => interval.toJson()).toList(),
  };
}

/// Widget'ın kullanacağı, uygulamanın dilindeki metinler.
///
/// Widget'ta ayrı bir çeviri dosyası tutmak yerine etiketler buradan
/// gönderiliyor: kullanıcı uygulama içinde dil seçtiğinde widget da o dile
/// geçer, cihaz dili farklı olsa bile.
class WidgetLabels {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String tomorrow;
  final String stale;
  final String openApp;
  final String updateApp;
  final String siriAnswer;
  final String durationHourMinute;
  final String durationHour;
  final String durationMinute;

  /// Kerahat satırı (v4): yaklaşırken "Kerahat" + sistem sayacı, aktifken
  /// "Kerahat vakti · bitiş {time}".
  final String kerahat;
  final String kerahatActive;
  final String kerahatUntil;

  const WidgetLabels({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.tomorrow,
    required this.stale,
    required this.openApp,
    required this.updateApp,
    required this.siriAnswer,
    required this.durationHourMinute,
    required this.durationHour,
    required this.durationMinute,
    required this.kerahat,
    required this.kerahatActive,
    required this.kerahatUntil,
  });

  Map<String, String> toJson() => {
    'fajr': fajr,
    'sunrise': sunrise,
    'dhuhr': dhuhr,
    'asr': asr,
    'maghrib': maghrib,
    'isha': isha,
    'tomorrow': tomorrow,
    'stale': stale,
    'openApp': openApp,
    'updateApp': updateApp,
    'siriAnswer': siriAnswer,
    'durationHourMinute': durationHourMinute,
    'durationHour': durationHour,
    'durationMinute': durationMinute,
    'kerahat': kerahat,
    'kerahatActive': kerahatActive,
    'kerahatUntil': kerahatUntil,
  };
}

class WidgetSnapshot {
  /// 2: günlere `hijri` alanı eklendi.
  /// 3: `labels` eklendi — widget metinleri uygulamanın dilinden geliyor.
  /// 4: günlere `kerahat` aralıkları ve etiketlere kerahat metinleri eklendi.
  ///
  /// Widget 1–3'ü de kabul eder; etiket yoksa Türkçe varsayılana, kerahat
  /// yoksa boş listeye düşer. Bilinmeyen sürümde widget "uygulamayı
  /// güncelleyin" durumuna geçer.
  static const int schemaVersion = 4;

  final String locationLabel;

  /// Yalnızca teşhis için. Bayatlık kararı buna değil, [days]'in son gününe
  /// bakılarak verilir: haftalarca açılmayan bir uygulamanın eski
  /// [generatedAt]'i, payload hâlâ geleceği kapsıyorsa bir sorun değildir.
  final DateTime generatedAt;

  final List<WidgetSnapshotDay> days;

  /// Widget metinleri; `null` ise payload v2 gibi yazılır.
  final WidgetLabels? labels;

  const WidgetSnapshot({
    required this.locationLabel,
    required this.generatedAt,
    required this.days,
    this.labels,
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'locationLabel': locationLabel,
    'generatedAt':
        '${_yyyyMMdd(generatedAt)}T${_hhmm(generatedAt)}:'
        '${_two(generatedAt.second)}',
    'days': days.map((day) => day.toJson()).toList(),
    if (labels != null) 'labels': labels!.toJson(),
  };
}

String _two(int value) => value.toString().padLeft(2, '0');

String _hhmm(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

String _yyyyMMdd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-'
    '${_two(date.day)}';
