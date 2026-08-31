import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_state.dart';
import '../../core/utils/time_formatter.dart';

/// Saat biçimlendirmesi için kısayol: kullanıcı tercihi [AppState]'ten,
/// cihazın 12/24 ayarı `MediaQuery`den okunur.
///
/// `context.tokens` ile aynı kalıp — çağıran her widget'ın iki kaynağı ayrı
/// ayrı okuması gerekmesin diye.
extension TimeFormatContext on BuildContext {
  String formatTime(DateTime time) => TimeFormatter.format(
    time,
    watch<AppState>().generalSettings.timeFormat,
    systemUses24h: MediaQuery.alwaysUse24HourFormatOf(this),
  );

  String formatHourMinute(int hour, int minute) =>
      TimeFormatter.formatHourMinute(
        hour,
        minute,
        watch<AppState>().generalSettings.timeFormat,
        systemUses24h: MediaQuery.alwaysUse24HourFormatOf(this),
      );
}
