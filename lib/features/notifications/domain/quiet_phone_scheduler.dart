import 'dart:io';

import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/quiet_interval.dart';
import '../../../core/utils/app_logger.dart';
import 'quiet_phone_planner.dart';

/// Sessiz pencerelerin telefon susturma planını native'e yollar (yalnız
/// Android). Vakit verisi yoksa hiçbir şey göndermez: geçici veri hatası
/// mevcut planı silmesin. Hata loglanır, çağırana gitmez — bildirim ve
/// alarm planlaması bundan etkilenmemeli.
class QuietPhoneScheduler {
  final LocalStorage storage;
  final Future<void> Function(List<QuietInterval> intervals) send;
  final bool enabled;
  final DateTime Function() clock;

  QuietPhoneScheduler({
    required this.storage,
    required this.send,
    bool? enabled,
    DateTime Function()? clock,
  }) : enabled = enabled ?? Platform.isAndroid,
       clock = clock ?? DateTime.now;

  Future<void> schedule({required List<PrayerTime> prayerTimes}) async {
    if (!enabled || prayerTimes.isEmpty) return;
    try {
      final windows = await storage.getQuietWindows();
      final intervals = QuietPhonePlanner.plan(
        windows: windows,
        prayerTimes: prayerTimes,
        now: clock(),
      );
      await send(intervals);
    } catch (error, stackTrace) {
      AppLogger().error('Quiet phone schedule failed', error, stackTrace);
    }
  }
}
