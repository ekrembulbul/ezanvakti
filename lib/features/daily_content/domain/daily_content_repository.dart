import 'dart:convert';

import '../../../core/interfaces/local_storage.dart';
import '../../../core/utils/app_logger.dart';
import '../data/daily_content_api.dart';
import 'daily_content.dart';

/// Günün içeriğini sunucudan alır ve son alınanı saklar. Geçmiş biriktirmez:
/// yeni gün gelince eskisinin üzerine yazar.
class DailyContentRepository {
  final DailyContentApi api;
  final LocalStorage storage;
  final DateTime Function() _now;

  static const String _contentKey = 'daily_content';
  static const String _attemptKey = 'daily_content_attempt';

  /// "Henüz yok" ya da hatadan sonra yeniden denemeden önce beklenen süre.
  static const Duration retryAfter = Duration(minutes: 30);

  /// Saklanan içeriğin gösterilebileceği en büyük yaş.
  static const int maxAgeDays = 7;

  DailyContentRepository({
    required this.api,
    required this.storage,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Bugünün içeriği saklıysa onu döner; değilse (son denemeden 30 dk
  /// geçtiyse) sunucuya sorar. Sunucu yoksa ya da hata verirse saklananı döner;
  /// depo dahil hiçbir hatada fırlatmaz (loglar).
  Future<DailyContent?> load() async {
    DailyContent? stored;
    try {
      stored = await _readStored();
      final now = _now();
      final today = DateTime(now.year, now.month, now.day);
      if (stored != null && stored.day == today) return stored;

      final lastAttempt = DateTime.tryParse(
        await storage.getSetting(_attemptKey) ?? '',
      );
      if (lastAttempt != null && now.difference(lastAttempt) < retryAfter) {
        return stored;
      }
      await storage.setSetting(_attemptKey, now.toIso8601String());
      final fresh = await api.fetch(today);
      if (fresh == null) return stored;
      await storage.setSetting(_contentKey, jsonEncode(fresh.toJson()));
      return fresh;
    } catch (e, s) {
      AppLogger().warning('Daily content load failed', e, s);
      return stored;
    }
  }

  /// [content] en çok 7 günlükse onu, değilse `null` döner.
  static DailyContent? visible(DailyContent? content, DateTime now) {
    if (content == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final age = today.difference(content.day).inDays;
    return age <= maxAgeDays ? content : null;
  }

  Future<DailyContent?> _readStored() async {
    final raw = await storage.getSetting(_contentKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DailyContent.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e, s) {
      AppLogger().warning('Stored daily content unreadable', e, s);
      return null;
    }
  }
}
