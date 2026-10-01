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

  /// Saklıysa saklananı döner; saklı değilse, listedeki değişiklik zamanı
  /// saklanandan farklıysa ya da hutbe günü henüz geçmediyse (Diyanet metni
  /// cuma ~11:30'a kadar düzeltebiliyor) sunucuya sorar. Sorarken ağ hatası
  /// olursa saklananı döner; saklı metin yoksa hata fırlatır.
  Future<SermonText> text(String id) async {
    final texts = await _readTexts();
    SermonText? stored;
    final raw = texts[id];
    if (raw != null) {
      try {
        stored = SermonText.fromJson(raw as Map<String, dynamic>);
      } catch (e, s) {
        AppLogger().warning('Stored sermon text unreadable', e, s);
      }
    }
    if (stored != null && !await _isStale(stored)) return stored;
    try {
      final fresh = await api.fetchText(id);
      texts[id] = fresh.toJson();
      await storage.setSetting(_textsKey, jsonEncode(texts));
      return fresh;
    } catch (e, s) {
      if (stored == null) rethrow;
      AppLogger().warning('Sermon text refresh failed; using stored', e, s);
      return stored;
    }
  }

  Future<bool> _isStale(SermonText stored) async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    if (!stored.date.isBefore(today)) return true;
    final summary = (await _readIndex())
        ?.where((s) => s.id == stored.id)
        .firstOrNull;
    final listed = summary?.modifiedAt;
    return listed != null && listed != stored.modifiedAt;
  }

  /// Okuma ekranı yazı boyutu kademesi (0–4).
  Future<int> fontStep() async {
    final value = int.tryParse(await storage.getSetting(_fontStepKey) ?? '');
    return (value ?? defaultFontStep).clamp(0, fontStepCount - 1);
  }

  Future<void> setFontStep(int step) =>
      storage.setSetting(_fontStepKey, '${step.clamp(0, fontStepCount - 1)}');

  /// Ana sayfa kartı: tarihi bugün olan hutbe, yoksa yarın olan. Bayram
  /// hutbesi bayramdan günler önce yayımlanabildiği için "en yeni" hutbeye
  /// bakılmaz; o haftanın cuma kartı da çıkar.
  static SermonSummary? featured(List<SermonSummary> index, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    SermonSummary? on(DateTime day) =>
        index.where((s) => s.date == day).firstOrNull;
    return on(today) ?? on(DateTime(now.year, now.month, now.day + 1));
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
