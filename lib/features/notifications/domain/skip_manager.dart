import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/skipped_occurrence.dart';
import 'skip_rules.dart';

/// "Yalnızca bu sefer" atlamalarını yükler, yazar ve süresi geçenleri temizler.
///
/// Üç metot da güncel kümeyi döner: çağıran taraf ayrıca [load] yapmadan
/// durumu tazeleyebilsin.
class SkipManager {
  final LocalStorage _storage;
  final DateTime Function() _clock;

  SkipManager({required LocalStorage storage, DateTime Function()? clock})
    : _storage = storage,
      _clock = clock ?? DateTime.now;

  /// Kayıtları okur, süresi geçenleri eler ve elemeyi depoya da yansıtır.
  Future<Set<SkippedOccurrence>> load() async {
    final stored = await _storage.getSkippedOccurrences();
    final live = withoutExpired(stored, _clock());

    // Liste zamanla şişmesin diye temizlik kalıcı yazılır.
    if (live.length != stored.length) {
      await _storage.saveSkippedOccurrences(live.toList());
    }
    return live;
  }

  Future<Set<SkippedOccurrence>> skip(SkippedOccurrence occurrence) async {
    final live = await load();
    return _persist({...live, occurrence});
  }

  Future<Set<SkippedOccurrence>> unskip(SkippedOccurrence occurrence) async {
    final live = await load();
    return _persist({...live}..remove(occurrence));
  }

  Future<Set<SkippedOccurrence>> _persist(Set<SkippedOccurrence> next) async {
    await _storage.saveSkippedOccurrences(next.toList());
    return next;
  }
}
