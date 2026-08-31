import 'dart:ui';

import 'app_localizations.dart';
import 'locale_resolver.dart';

/// `BuildContext` olmayan yerlerde (arka plan servisleri, bildirim kanalı)
/// cihaz dilindeki metinler.
///
/// Uygulama içinde dil seçimi yok: dil her zaman cihazdan gelir, bu yüzden
/// burada okunan dil arayüzdekiyle aynıdır.
Future<AppLocalizations> deviceLocalizations() => AppLocalizations.delegate
    .load(LocaleResolver.resolve(PlatformDispatcher.instance.locale));
