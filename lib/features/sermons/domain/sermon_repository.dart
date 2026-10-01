import 'dart:convert';

import '../../../core/interfaces/local_storage.dart';
import '../../../core/utils/app_logger.dart';
import '../data/sermons_api.dart';
import 'sermon.dart';

/// Hutbe listesi ve açılmış Türkçe metinler; ikisi de cihazda saklanır,
/// ağ yokken okunabilir. Listeden düşen hutbenin metni silinir.
class SermonRepository {
  final SermonsApi api;
  final LocalStorage storage;
  final DateTime Function() _now;

  static const String _indexKey = 'sermons_index';
  static const String _indexAtKey = 'sermons_index_at';
  static const String _textsKey = 'sermon_texts';
  static const String _fontStepKey = 'sermon_font_step';

  /// Liste bu süreden yeniyse sunucuya sorulmaz.
  static const Duration indexMaxAge = Duration(hours: 1);
  static const int fontStepCount = 5;
  static const int defaultFontStep = 2;

  SermonRepository({
    required this.api,
    required this.storage,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Saklanan liste bir saatten yeniyse onu, değilse sunucudakini döner. Ağ
  /// hatasında saklanan varsa onu döner, yoksa hata fırlatır.
  Future<List<SermonSummary>> index({bool force = false}) async {
    final stored = await _readIndex();
    final at = DateTime.tryParse(await storage.getSetting(_indexAtKey) ?? '');
    if (!force &&
        stored != null &&
        at != null &&
        _now().difference(at) < indexMaxAge) {
      return stored;
    }
    try {
      final fresh = await api.fetchIndex();
      await storage.setSetting(
        _indexKey,
        jsonEncode([for (final s in fresh) s.toJson()]),
      );
      await storage.setSetting(_indexAtKey, _now().toIso8601String());
      await _pruneTexts({for (final s in fresh) s.id});
      return fresh;
    } catch (e, s) {
      if (stored == null) rethrow;
      AppLogger().warning('Sermon index refresh failed; using stored', e, s);
      return stored;
    }
  }

  /// Saklıysa saklananı, değilse indirip saklar.
  Future<SermonText> text(String id) async {
    final texts = await _readTexts();
    final stored = texts[id];
    if (stored != null) {
      try {
        return SermonText.fromJson(stored as Map<String, dynamic>);
      } catch (e, s) {
        AppLogger().warning('Stored sermon text unreadable', e, s);
      }
    }
    final fresh = await api.fetchText(id);
    texts[id] = fresh.toJson();
    await storage.setSetting(_textsKey, jsonEncode(texts));
    return fresh;
  }

  /// Okuma ekranı yazı boyutu kademesi (0–4).
  Future<int> fontStep() async {
    final value = int.tryParse(await storage.getSetting(_fontStepKey) ?? '');
    return (value ?? defaultFontStep).clamp(0, fontStepCount - 1);
  }

  Future<void> setFontStep(int step) =>
      storage.setSetting(_fontStepKey, '${step.clamp(0, fontStepCount - 1)}');

  /// Ana sayfa kartı: en yeni hutbenin günü bugün ya da yarınsa o.
  static SermonSummary? featured(List<SermonSummary> index, DateTime now) {
    if (index.isEmpty) return null;
    final latest = index.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    final today = DateTime(now.year, now.month, now.day);
    final days = latest.date.difference(today).inDays;
    return days == 0 || days == 1 ? latest : null;
  }

  Future<List<SermonSummary>?> _readIndex() async {
    final raw = await storage.getSetting(_indexKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return [
        for (final s in jsonDecode(raw) as List)
          SermonSummary.fromJson(s as Map<String, dynamic>),
      ];
    } catch (e, s) {
      AppLogger().warning('Stored sermon index unreadable', e, s);
      return null;
    }
  }

  Future<Map<String, dynamic>> _readTexts() async {
    final raw = await storage.getSetting(_textsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e, s) {
      AppLogger().warning('Stored sermon texts unreadable', e, s);
      return {};
    }
  }

  Future<void> _pruneTexts(Set<String> keep) async {
    final texts = await _readTexts();
    final before = texts.length;
    texts.removeWhere((id, _) => !keep.contains(id));
    if (texts.length != before) {
      await storage.setSetting(_textsKey, jsonEncode(texts));
    }
  }
}
