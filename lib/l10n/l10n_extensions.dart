import 'package:flutter/widgets.dart';

import '../core/models/app_language.dart';
import '../core/models/calculation_params.dart';
import '../features/alarms/domain/abort_gate.dart';
import '../core/models/derived_time.dart';
import '../core/models/religious_day.dart';
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

  /// Gün kısaltması (1=Pazartesi .. 7=Pazar).
  String weekdayShort(int weekday) => switch (weekday) {
    1 => weekdayShortMon,
    2 => weekdayShortTue,
    3 => weekdayShortWed,
    4 => weekdayShortThu,
    5 => weekdayShortFri,
    6 => weekdayShortSat,
    _ => weekdayShortSun,
  };

  /// Çip içindeki tek/iki harflik gün.
  String weekdayLetter(int weekday) => switch (weekday) {
    1 => weekdayLetterMon,
    2 => weekdayLetterTue,
    3 => weekdayLetterWed,
    4 => weekdayLetterThu,
    5 => weekdayLetterFri,
    6 => weekdayLetterSat,
    _ => weekdayLetterSun,
  };

  String religiousDayName(ReligiousDayId id) => switch (id) {
    ReligiousDayId.newYear => religiousNewYear,
    ReligiousDayId.ashura => religiousAshura,
    ReligiousDayId.mawlid => religiousMawlid,
    ReligiousDayId.regaib => religiousRegaib,
    ReligiousDayId.miraj => religiousMiraj,
    ReligiousDayId.baraat => religiousBaraat,
    ReligiousDayId.ramadanStart => religiousRamadanStart,
    ReligiousDayId.qadr => religiousQadr,
    ReligiousDayId.eidFitr => religiousEidFitr,
    ReligiousDayId.arafah => religiousArafah,
    ReligiousDayId.eidAdha => religiousEidAdha,
  };

  String asrSchoolLabel(AsrSchool school) => switch (school) {
    AsrSchool.shafi => asrShafi,
    AsrSchool.hanafi => asrHanafi,
  };

  String latitudeAdjustmentLabel(LatitudeAdjustment value) => switch (value) {
    LatitudeAdjustment.auto => latAuto,
    LatitudeAdjustment.middleOfNight => latMidnight,
    LatitudeAdjustment.oneSeventh => latOneSeventh,
    LatitudeAdjustment.angleBased => latAngle,
  };

  String abortPhrase(AbortPhrase phrase) => switch (phrase) {
    AbortPhrase.short => abortDismissing,
    AbortPhrase.long => abortDismissingHard,
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
