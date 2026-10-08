import '../../../core/theme/day_phase.dart';
import '../../prayer_times/domain/day_ruler_math.dart';

/// Widget'a gönderilen payload'ın tipli karşılığı.
///
/// Saatler `"HH:mm"`, tarihler `"yyyy-MM-dd"` olarak serileştirilir; offset'li
/// ISO timestamp **bilerek** kullanılmaz. Uygulama vakitleri timezone
/// taşımayan cihaz-yerel wall-clock olarak üretiyor
/// (`diyanet_provider.dart`, `_parseDay`); offset yazmak widget'a uygulamada
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

  /// Altı vaktin epoch milisaniyesi. Android widget'ı saati buradan biçimler;
  /// `"HH:mm"`'den gün kurmak zorunda kalmaz.
  Map<String, int> toEpochJson() => {
    'fajr': fajr.millisecondsSinceEpoch,
    'sunrise': sunrise.millisecondsSinceEpoch,
    'dhuhr': dhuhr.millisecondsSinceEpoch,
    'asr': asr.millisecondsSinceEpoch,
    'maghrib': maghrib.millisecondsSinceEpoch,
    'isha': isha.millisecondsSinceEpoch,
  };

  /// Gün içindeki sıraya göre (İmsak … Yatsı); zaman çizelgesindeki `slot`
  /// indeksi bu sıradır.
  List<DateTime> get ordered => [fajr, sunrise, dhuhr, asr, maghrib, isha];
}

/// Gün cetveli: ana ekrandaki cetvelin parçaları ve vakit çentikleri (0..1).
class WidgetRuler {
  final List<RulerSegment> segments;
  final List<double> marks;

  const WidgetRuler({required this.segments, required this.marks});

  Map<String, dynamic> toJson() => {
    'segments': [
      for (final segment in segments)
        {
          'start': _ratio(segment.start),
          'end': _ratio(segment.end),
          'kind': segment.kind.name,
          'gapBefore': segment.gapBefore,
          'gapAfter': segment.gapAfter,
        },
    ],
    'marks': [for (final mark in marks) _ratio(mark)],
  };
}

/// Zaman çizelgesindeki kerahat durumu.
enum WidgetKerahatState { approaching, active }

class WidgetTimelineKerahat {
  final WidgetKerahatState state;
  final DateTime start;
  final DateTime end;

  const WidgetTimelineKerahat({
    required this.state,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() => {
    'state': state.name,
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
  };
}

/// Zaman çizelgesinin bir anı: [at]'ten bir sonraki girişe kadar geçerli.
///
/// Android widget'ı ve sabit satır hesap yapmaz, yalnız o anki girişi seçer
/// (ADR 0004). [day] gösterilen günün (sıradaki vaktin günü) indeksi, [slot]
/// o günün sıradaki vakti (0 İmsak … 5 Yatsı).
class WidgetTimelineEntry {
  final DateTime at;
  final int day;
  final int slot;
  final bool tomorrow;
  final DayPhase phase;
  final WidgetTimelineKerahat? kerahat;

  const WidgetTimelineEntry({
    required this.at,
    required this.day,
    required this.slot,
    required this.tomorrow,
    required this.phase,
    this.kerahat,
  });

  Map<String, dynamic> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'day': day,
    'slot': slot,
    'tomorrow': tomorrow,
    'phase': phase.name,
    'kerahat': kerahat?.toJson(),
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

  /// Uygulamanın gösterdiği Diyanet Hicri tarihi (`HijriFormatter.formatHijri`).
  ///
  /// Swift tarafında hesaplanmıyor: iOS'un `islamicUmmAlQura` takvimi
  /// Diyanet'ten gün kayabiliyor ve widget'ın uygulamadan farklı tarih
  /// göstermesi kabul edilemez. Veri yoksa `null`; Swift tarafı opsiyonel okur.
  final String? hijri;

  /// Günün kerahat aralıkları (v4); boş liste de geçerlidir.
  final List<WidgetKerahatInterval> kerahat;

  /// Uygulamanın dilinde gün adı ("Perşembe"); eklemeli alan.
  final String? weekday;

  /// Uygulamanın dilinde kısa tarih ("8 Ekim"); eklemeli alan.
  final String? dateLabel;

  /// Yılsız hicri tarih ("27 Rebiülahir"); eklemeli alan.
  final String? hijriShort;

  /// Gün cetveli; eklemeli alan.
  final WidgetRuler? ruler;

  const WidgetSnapshotDay({
    required this.date,
    required this.times,
    this.hijri,
    this.kerahat = const [],
    this.weekday,
    this.dateLabel,
    this.hijriShort,
    this.ruler,
  });

  Map<String, dynamic> toJson() => {
    'date': _yyyyMMdd(date),
    'hijri': hijri,
    'times': times.toJson(),
    'kerahat': kerahat.map((interval) => interval.toJson()).toList(),
    'weekday': weekday,
    'dateLabel': dateLabel,
    'hijriShort': hijriShort,
    'epochs': times.toEpochJson(),
    if (ruler != null) 'ruler': ruler!.toJson(),
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

  /// Kerahat şeridi (v4): tek kelime, yanına sistem sayacı gelir.
  final String kerahat;

  /// Şerit yaklaşırken (2026-09-21): tek kelime, sayaç başlangıca sayar.
  /// Ek alan; şema sürümü aynı, eski widget'lar yok sayar.
  final String kerahatSoon;

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
    required this.kerahatSoon,
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
    'kerahatSoon': kerahatSoon,
  };
}

class WidgetSnapshot {
  /// 2: günlere `hijri` alanı eklendi.
  /// 3: `labels` eklendi — widget metinleri uygulamanın dilinden geliyor.
  /// 4: günlere `kerahat` aralıkları ve etiketlere kerahat metinleri eklendi.
  ///    Sonradan eklemeli alanlar (sürüm aynı, eski widget yok sayar):
  ///    günlere `weekday`, `dateLabel`, `hijriShort`, `epochs`, `ruler`;
  ///    köke `timeline` (Android widget'ı ve sabit satır yalnız bunu okur).
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

  /// Değişim anları; eklemeli alan.
  final List<WidgetTimelineEntry> timeline;

  const WidgetSnapshot({
    required this.locationLabel,
    required this.generatedAt,
    required this.days,
    this.labels,
    this.timeline = const [],
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'locationLabel': locationLabel,
    'generatedAt':
        '${_yyyyMMdd(generatedAt)}T${_hhmm(generatedAt)}:'
        '${_two(generatedAt.second)}',
    'days': days.map((day) => day.toJson()).toList(),
    if (labels != null) 'labels': labels!.toJson(),
    'timeline': timeline.map((entry) => entry.toJson()).toList(),
  };
}

String _two(int value) => value.toString().padLeft(2, '0');

String _hhmm(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

String _yyyyMMdd(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-'
    '${_two(date.day)}';

/// Oranlar 4 ondalıkla: payload küçük kalsın, piksel farkı olmasın.
double _ratio(double value) => double.parse(value.toStringAsFixed(4));
