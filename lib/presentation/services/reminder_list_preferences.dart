import 'dart:convert';

import '../../core/interfaces/local_storage.dart';
import '../../core/utils/app_logger.dart';

enum ReminderListKind { alarms, notifications }

enum ReminderSortMode { custom, nextFire, name }

/// Liste sırası yalnızca sunum tercihidir; alarm planlamasını değiştirmez.
///
/// Const oluşturucuya değiştirilmeyen bir [customOrder] verilmeli. Çalışma
/// anında üretilen listeler [copyWith] üzerinden korumalı kopyaya dönüştürülür.
class ReminderListPreferences {
  final ReminderSortMode sortMode;
  final List<String> customOrder;

  const ReminderListPreferences({
    this.sortMode = ReminderSortMode.custom,
    this.customOrder = const [],
  });

  ReminderListPreferences copyWith({
    ReminderSortMode? sortMode,
    List<String>? customOrder,
  }) => ReminderListPreferences(
    sortMode: sortMode ?? this.sortMode,
    customOrder: List<String>.unmodifiable(customOrder ?? this.customOrder),
  );

  /// Kimliği değişen bildirimin diğer satırlara göre konumunu korur.
  ReminderListPreferences replaceKey(String oldKey, String newKey) {
    if (oldKey == newKey || !customOrder.contains(oldKey)) return this;

    final seen = <String>{};
    final updated = <String>[];
    for (final key in customOrder) {
      if (key == newKey) continue;
      final replacement = key == oldKey ? newKey : key;
      if (seen.add(replacement)) updated.add(replacement);
    }
    return copyWith(customOrder: updated);
  }
}

/// Sıra ve sort modunu her liste için tek kayıtta atomik olarak saklar.
class ReminderListPreferencesStore {
  static const String alarmsKey = 'reminder_list_alarms';
  static const String notificationsKey = 'reminder_list_notifications';

  final LocalStorage _storage;

  ReminderListPreferencesStore({required LocalStorage storage})
    : _storage = storage;

  /// Bozuk tercihler varsayılana düşer; storage hataları çağırana aktarılır.
  Future<ReminderListPreferences> load(ReminderListKind kind) async {
    final stored = await _storage.getSetting(_keyFor(kind));
    if (stored == null) return const ReminderListPreferences();

    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) return _invalidPreferences(kind);

      final sortMode = switch (decoded['sortMode']) {
        'custom' => ReminderSortMode.custom,
        'nextFire' => ReminderSortMode.nextFire,
        'name' => ReminderSortMode.name,
        _ => null,
      };
      final customOrder = decoded['customOrder'];
      if (sortMode == null ||
          customOrder is! List ||
          customOrder.any((key) => key is! String)) {
        return _invalidPreferences(kind);
      }

      return ReminderListPreferences(
        sortMode: sortMode,
        customOrder: List<String>.unmodifiable(customOrder.cast<String>()),
      );
    } on FormatException {
      return _invalidPreferences(kind);
    }
  }

  Future<void> save(
    ReminderListKind kind,
    ReminderListPreferences preferences,
  ) => _storage.setSetting(
    _keyFor(kind),
    jsonEncode({
      'sortMode': preferences.sortMode.name,
      'customOrder': preferences.customOrder,
    }),
  );

  static String _keyFor(ReminderListKind kind) => switch (kind) {
    ReminderListKind.alarms => alarmsKey,
    ReminderListKind.notifications => notificationsKey,
  };

  ReminderListPreferences _invalidPreferences(ReminderListKind kind) {
    AppLogger().warning('Invalid reminder list preferences kind=${kind.name}');
    return const ReminderListPreferences();
  }
}

/// Yeni kayıtlar custom sıranın sonuna eklenir; eşit değerler giriş sırasını
/// korur. [items] değiştirilmez ve otomatik sıralama custom sırayı silmez.
List<T> sortReminderItems<T>({
  required List<T> items,
  required ReminderListPreferences preferences,
  required String Function(T) idOf,
  required String Function(T) nameOf,
  required DateTime? Function(T) nextFireOf,
}) {
  final customPositions = <String, int>{};
  for (final (index, key) in preferences.customOrder.indexed) {
    customPositions.putIfAbsent(key, () => index);
  }

  final indexedItems = items.indexed.toList();
  indexedItems.sort((a, b) {
    final comparison = switch (preferences.sortMode) {
      ReminderSortMode.custom =>
        (customPositions[idOf(a.$2)] ?? preferences.customOrder.length)
            .compareTo(
              customPositions[idOf(b.$2)] ?? preferences.customOrder.length,
            ),
      ReminderSortMode.nextFire => _compareNextFire(
        nextFireOf(a.$2),
        nextFireOf(b.$2),
      ),
      ReminderSortMode.name => nameOf(
        a.$2,
      ).toLowerCase().compareTo(nameOf(b.$2).toLowerCase()),
    };
    return comparison != 0 ? comparison : a.$1.compareTo(b.$1);
  });
  return indexedItems.map((entry) => entry.$2).toList();
}

int _compareNextFire(DateTime? a, DateTime? b) {
  if (a == null) return b == null ? 0 : 1;
  if (b == null) return -1;
  return a.compareTo(b);
}
