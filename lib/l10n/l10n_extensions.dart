import 'package:flutter/widgets.dart';

import '../core/models/app_language.dart';
import '../core/models/derived_time.dart';
import '../core/models/notification_setting.dart' show PrayerType;
import '../core/utils/time_formatter.dart';
import 'app_localizations.dart';

/// `AppLocalizations.of(context)` yerine `context.l10n`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Enum → çeviri eşlemeleri. ARB'de her enum değeri ayrı anahtar olduğu için
/// switch burada toplanıyor; çağıran taraflar tek satırla kullanıyor.
extension L10nLabels on AppLocalizations {
  String prayerName(PrayerType type) => switch (type) {
    PrayerType.fajr => prayerFajr,
    PrayerType.sunrise => prayerSunrise,
    PrayerType.dhuhr => prayerDhuhr,
    PrayerType.asr => prayerAsr,
    PrayerType.maghrib => prayerMaghrib,
    PrayerType.isha => prayerIsha,
  };

  String derivedName(DerivedTimeKind kind) => switch (kind) {
    DerivedTimeKind.ishraq => derivedIshraq,
    DerivedTimeKind.istiwa => derivedIstiwa,
    DerivedTimeKind.preMaghrib => derivedPreMaghrib,
    DerivedTimeKind.midnight => derivedMidnight,
    DerivedTimeKind.lastThird => derivedLastThird,
  };

  String derivedHint(DerivedTimeKind kind) => switch (kind) {
    DerivedTimeKind.ishraq => derivedIshraqHint,
    DerivedTimeKind.istiwa => derivedIstiwaHint,
    DerivedTimeKind.preMaghrib => derivedPreMaghribHint,
    DerivedTimeKind.midnight => derivedMidnightHint,
    DerivedTimeKind.lastThird => derivedLastThirdHint,
  };

  String languageLabel(AppLanguage language) => switch (language) {
    AppLanguage.system => languageSystem,
    AppLanguage.turkish => languageTurkish,
    AppLanguage.english => languageEnglish,
    AppLanguage.arabic => languageArabic,
  };

  String timeFormatLabel(TimeFormatPreference preference) => switch (preference) {
    TimeFormatPreference.system => timeFormatSystem,
    TimeFormatPreference.h24 => timeFormat24,
    TimeFormatPreference.h12 => timeFormat12,
  };
}
