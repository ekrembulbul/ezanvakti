import 'package:flutter/foundation.dart';
import '../../core/models/location.dart';
import '../../core/models/prayer_time.dart';
import '../../core/utils/app_logger.dart';
import '../../features/prayer_times/domain/calendar_month_repository.dart';

/// Vakit Takvimi'nin ay ay gezinmesi (spec 2026-09-28 §3.5).
///
/// `ImsakiyeController` kalıbındadır: nesil sayacı, hızlı ok basışlarında
/// yalnız son ayın yanıtını uygular. Ay değişirken önceki ayın [days]'i yeni
/// ay gelene kadar kalır (ekranda eski tablo + ince ilerleme çizgisi); hangi
/// aya ait oldukları [loadedMonth]'tadır. Konum/düzeltme değişince ya da
/// yükleme başarısız olunca günler temizlenir: başka ayın ya da eski
/// düzeltmenin tablosu yanlış etiketle görünmesin.
class CalendarMonthController extends ChangeNotifier {
  final CalendarMonthLoader loader;

  /// Gezinme aralığı: bu yılın Ocak'ı … gelecek yılın Aralık'ı.
  final DateTime firstMonth;
  final DateTime lastMonth;

  DateTime _month;
  DateTime? _loadedMonth;
  Location? _location;
  Object? _revision;
  List<PrayerTime> days = const [];
  Object? error;
  bool isLoading = false;
  bool _disposed = false;
  int _generation = 0;

  CalendarMonthController({required this.loader, required DateTime now})
    : _month = DateTime(now.year, now.month),
      firstMonth = DateTime(now.year),
      lastMonth = DateTime(now.year + 1, 12);

  /// Seçili ay (ayın 1'i, yerel saat).
  DateTime get month => _month;

  /// [days]'in ait olduğu ay; henüz sonuç yoksa ya da temizlendiyse `null`.
  DateTime? get loadedMonth => _loadedMonth;

  bool get canGoPrevious => _month.isAfter(firstMonth);
  bool get canGoNext => _month.isBefore(lastMonth);

  /// Paylaşım yalnız seçili ayın günleri yüklüyken ve yükleme yokken.
  bool get canShare => !isLoading && _loadedMonth == _month && days.isNotEmpty;

  /// Sunucu o yılı henüz yayımlamamış (boş sonuç): hata değil, bilgi.
  bool get isUnavailable =>
      !isLoading && error == null && _loadedMonth == _month && days.isEmpty;

  Future<void> updateSource(Location location, Object revision) {
    if (_location == location && _revision == revision) return Future.value();
    _location = location;
    _revision = revision;
    // Konum ya da düzeltme değişti: eldeki günler artık geçersiz.
    days = const [];
    _loadedMonth = null;
    return _load();
  }

  Future<void> selectMonth(DateTime selected) {
    final normalized = DateTime(selected.year, selected.month);
    if (normalized == _month ||
        normalized.isBefore(firstMonth) ||
        normalized.isAfter(lastMonth)) {
      return Future.value();
    }
    _month = normalized;
    // Önceki ayın günleri yeni ay gelene kadar ekranda kalır.
    return _load();
  }

  Future<void> previous() =>
      selectMonth(DateTime(_month.year, _month.month - 1));

  Future<void> next() => selectMonth(DateTime(_month.year, _month.month + 1));

  Future<void> refresh() => _load(forceRefresh: true);

  Future<void> _load({bool forceRefresh = false}) async {
    final location = _location;
    if (location == null || _disposed) return;
    final generation = ++_generation;
    final selected = _month;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await loader(
        location: location,
        month: selected,
        forceRefresh: forceRefresh,
      );
      if (_disposed || generation != _generation) return;
      days = result;
      _loadedMonth = selected;
    } catch (failure, stack) {
      if (_disposed || generation != _generation) return;
      AppLogger().warning('Calendar month load failed', failure, stack);
      error = failure;
      days = const [];
      _loadedMonth = null;
    } finally {
      if (!_disposed && generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
