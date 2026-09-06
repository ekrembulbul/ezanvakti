import 'package:flutter/foundation.dart';
import '../../core/models/location.dart';
import '../../core/models/prayer_time.dart';
import '../../core/utils/app_logger.dart';
import '../../features/ramadan/domain/imsakiye_repository.dart';
import '../../features/ramadan/domain/ramadan_period.dart';

class ImsakiyeController extends ChangeNotifier {
  final ImsakiyeLoader loader;
  RamadanPeriod period;
  Location? _location;
  Object? _revision;
  List<PrayerTime> days = const [];
  Object? error;
  bool isLoading = false;
  bool _disposed = false;
  int _generation = 0;

  ImsakiyeController({required this.loader, required this.period});
  bool get canShare => !isLoading && days.length == period.dayCount;

  Future<void> updateSource(Location location, Object revision) {
    if (_location == location && _revision == revision) return Future.value();
    _location = location;
    _revision = revision;
    days = const [];
    return _load();
  }

  Future<void> selectPeriod(RamadanPeriod selected) {
    if (period == selected) return Future.value();
    period = selected;
    days = const [];
    return _load();
  }

  Future<void> refresh() => _load(forceRefresh: true);

  Future<void> _load({bool forceRefresh = false}) async {
    final location = _location;
    if (location == null || _disposed) return;
    final generation = ++_generation;
    final selected = period;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await loader(
        location: location,
        period: selected,
        forceRefresh: forceRefresh,
      );
      if (_disposed || generation != _generation) return;
      days = validateImsakiye(result, selected);
    } catch (failure, stack) {
      if (_disposed || generation != _generation) return;
      AppLogger().warning('Imsakiye load failed', failure, stack);
      error = failure;
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
