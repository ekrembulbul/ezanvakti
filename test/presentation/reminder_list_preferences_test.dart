import 'dart:convert';

import 'package:ezanvakti/core/interfaces/local_storage.dart';
import 'package:ezanvakti/presentation/services/reminder_list_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

typedef _Reminder = ({String id, String name, DateTime? nextFire});

List<_Reminder> _sort(
  List<_Reminder> items,
  ReminderListPreferences preferences,
) => sortReminderItems(
  items: items,
  preferences: preferences,
  idOf: (item) => item.id,
  nameOf: (item) => item.name,
  nextFireOf: (item) => item.nextFire,
);

class _SettingsStorage implements LocalStorage {
  final Map<String, String> values = {};
  final List<({String key, String value})> writes = [];
  Object? readError;
  Object? writeError;

  @override
  Future<String?> getSetting(String key) async {
    if (readError case final error?) throw error;
    return values[key];
  }

  @override
  Future<void> setSetting(String key, String value) async {
    if (writeError case final error?) throw error;
    values[key] = value;
    writes.add((key: key, value: value));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_SettingsStorage.${invocation.memberName}');
}

void main() {
  group('sortReminderItems', () {
    const items = <_Reminder>[
      (id: 'a', name: 'Evening', nextFire: null),
      (id: 'b', name: 'Morning', nextFire: null),
      (id: 'c', name: 'Noon', nextFire: null),
      (id: 'd', name: 'Night', nextFire: null),
    ];

    test('custom order puts saved items first and appends new items', () {
      final sorted = _sort(
        items,
        const ReminderListPreferences(customOrder: ['c', 'a']),
      );

      expect(sorted.map((item) => item.id), ['c', 'a', 'b', 'd']);
    });

    test('stale and repeated custom keys do not lose or repeat items', () {
      final sorted = _sort(
        items,
        const ReminderListPreferences(customOrder: ['missing', 'c', 'a', 'c']),
      );

      expect(sorted.map((item) => item.id), ['c', 'a', 'b', 'd']);
    });

    test('no saved custom order preserves the input order in a copy', () {
      final sorted = _sort(items, const ReminderListPreferences());

      expect(sorted.map((item) => item.id), ['a', 'b', 'c', 'd']);
      expect(identical(sorted, items), isFalse);
    });

    test('sorting leaves a mutable input list unchanged', () {
      final mutableItems = items.toList();

      _sort(
        mutableItems,
        const ReminderListPreferences(customOrder: ['c', 'a']),
      );

      expect(mutableItems.map((item) => item.id), ['a', 'b', 'c', 'd']);
    });

    test('next fire sorts earliest first with unknown times last', () {
      final sorted = _sort([
        (id: 'unknown', name: 'Unknown', nextFire: null),
        (id: 'late', name: 'Late', nextFire: DateTime(2026, 9, 7, 8)),
        (id: 'early', name: 'Early', nextFire: DateTime(2026, 9, 6, 8)),
      ], const ReminderListPreferences(sortMode: ReminderSortMode.nextFire));

      expect(sorted.map((item) => item.id), ['early', 'late', 'unknown']);
    });

    test('equal next fire times retain input order including null times', () {
      final time = DateTime(2026, 9, 6, 8);
      final sorted = _sort([
        (id: 'z', name: 'Unknown Z', nextFire: null),
        (id: 'b', name: 'Known B', nextFire: time),
        (id: 'a', name: 'Known A', nextFire: time),
        (id: 'y', name: 'Unknown Y', nextFire: null),
      ], const ReminderListPreferences(sortMode: ReminderSortMode.nextFire));

      expect(sorted.map((item) => item.id), ['b', 'a', 'z', 'y']);
    });

    test('name sort ignores case and retains input order for equal names', () {
      final sorted = _sort(const [
        (id: 'c', name: 'zebra', nextFire: null),
        (id: 'b', name: 'Alpha', nextFire: null),
        (id: 'a', name: 'alpha', nextFire: null),
        (id: 'd', name: 'Beta', nextFire: null),
      ], const ReminderListPreferences(sortMode: ReminderSortMode.name));

      expect(sorted.map((item) => item.id), ['b', 'a', 'd', 'c']);
    });

    test('switching automatic modes preserves the saved custom order', () {
      const preferences = ReminderListPreferences(customOrder: ['c', 'a']);
      final automatic = preferences.copyWith(sortMode: ReminderSortMode.name);
      final custom = automatic.copyWith(sortMode: ReminderSortMode.custom);

      expect(_sort(items, automatic).map((item) => item.id), [
        'a',
        'b',
        'd',
        'c',
      ]);
      expect(_sort(items, custom).map((item) => item.id), ['c', 'a', 'b', 'd']);
    });
  });

  group('ReminderListPreferences', () {
    test('replaceKey preserves the edited item position and sort mode', () {
      const preferences = ReminderListPreferences(
        sortMode: ReminderSortMode.nextFire,
        customOrder: ['a', 'old', 'c'],
      );

      final updated = preferences.replaceKey('old', 'new');

      expect(updated.customOrder, ['a', 'new', 'c']);
      expect(updated.sortMode, ReminderSortMode.nextFire);
      expect(preferences.customOrder, ['a', 'old', 'c']);
    });

    test('replaceKey preserves order when the old key is absent', () {
      const preferences = ReminderListPreferences(customOrder: ['a', 'b']);

      expect(preferences.replaceKey('missing', 'new').customOrder, ['a', 'b']);
    });

    test(
      'replaceKey removes a stale replacement without moving other items',
      () {
        const preferences = ReminderListPreferences(
          customOrder: ['new', 'a', 'old', 'b', 'old'],
        );

        expect(preferences.replaceKey('old', 'new').customOrder, [
          'a',
          'new',
          'b',
        ]);
      },
    );

    test('copyWith snapshots supplied custom order', () {
      final keys = ['a', 'b'];
      final preferences = const ReminderListPreferences().copyWith(
        customOrder: keys,
      );
      keys.add('c');

      expect(preferences.customOrder, ['a', 'b']);
      expect(() => preferences.customOrder.add('d'), throwsUnsupportedError);
    });
  });

  group('ReminderListPreferencesStore', () {
    late _SettingsStorage storage;
    late ReminderListPreferencesStore store;

    setUp(() {
      storage = _SettingsStorage();
      store = ReminderListPreferencesStore(storage: storage);
    });

    test(
      'missing preferences use custom input order without writing',
      () async {
        final preferences = await store.load(ReminderListKind.alarms);

        expect(preferences.sortMode, ReminderSortMode.custom);
        expect(preferences.customOrder, isEmpty);
        expect(storage.writes, isEmpty);
      },
    );

    test('mode and custom order survive a new store instance', () async {
      await store.save(
        ReminderListKind.alarms,
        const ReminderListPreferences(
          sortMode: ReminderSortMode.nextFire,
          customOrder: ['second', 'first'],
        ),
      );

      final reopened = ReminderListPreferencesStore(storage: storage);
      final preferences = await reopened.load(ReminderListKind.alarms);

      expect(preferences.sortMode, ReminderSortMode.nextFire);
      expect(preferences.customOrder, ['second', 'first']);
      expect(
        () => preferences.customOrder.add('third'),
        throwsUnsupportedError,
      );
    });

    test('alarm and notification preferences persist independently', () async {
      await store.save(
        ReminderListKind.alarms,
        const ReminderListPreferences(customOrder: ['alarm-b', 'alarm-a']),
      );
      await store.save(
        ReminderListKind.notifications,
        const ReminderListPreferences(
          sortMode: ReminderSortMode.name,
          customOrder: ['notification-a'],
        ),
      );

      final alarms = await store.load(ReminderListKind.alarms);
      final notifications = await store.load(ReminderListKind.notifications);

      expect(alarms.sortMode, ReminderSortMode.custom);
      expect(alarms.customOrder, ['alarm-b', 'alarm-a']);
      expect(notifications.sortMode, ReminderSortMode.name);
      expect(notifications.customOrder, ['notification-a']);
    });

    test('one setting write stores both mode and order atomically', () async {
      await store.save(
        ReminderListKind.alarms,
        const ReminderListPreferences(
          sortMode: ReminderSortMode.name,
          customOrder: ['b', 'a'],
        ),
      );

      expect(storage.writes, hasLength(1));
      expect(jsonDecode(storage.writes.single.value), {
        'sortMode': 'name',
        'customOrder': ['b', 'a'],
      });
    });

    for (final entry in <String, String>{
      'malformed JSON': '{',
      'null JSON': 'null',
      'list root': '[]',
      'missing fields': '{}',
      'unknown sort mode': '{"sortMode":"future","customOrder":["a"]}',
      'non-string sort mode': '{"sortMode":1,"customOrder":["a"]}',
      'non-list custom order': '{"sortMode":"name","customOrder":"a"}',
      'non-string custom key': '{"sortMode":"name","customOrder":["a",1]}',
    }.entries) {
      test('${entry.key} falls back without overwriting stored data', () async {
        storage.values[ReminderListPreferencesStore.alarmsKey] = entry.value;

        final preferences = await store.load(ReminderListKind.alarms);

        expect(preferences.sortMode, ReminderSortMode.custom);
        expect(preferences.customOrder, isEmpty);
        expect(storage.writes, isEmpty);
      });
    }

    test('invalid JSON logs a warning without stored content', () async {
      storage.values[ReminderListPreferencesStore.alarmsKey] =
          '{"customOrder":["private-reminder"';
      final events = <LogEvent>[];
      void onLog(LogEvent event) => events.add(event);
      Logger.addLogListener(onLog);
      addTearDown(() => Logger.removeLogListener(onLog));

      await store.load(ReminderListKind.alarms);

      expect(events, hasLength(1));
      expect(events.single.level, Level.warning);
      expect(
        events.single.message.toString(),
        isNot(contains('private-reminder')),
      );
      expect(events.single.error, isNull);
    });

    test('load propagates storage failures', () async {
      final failure = StateError('read failed');
      storage.readError = failure;

      await expectLater(
        store.load(ReminderListKind.alarms),
        throwsA(same(failure)),
      );
    });

    test('save propagates storage failures', () async {
      final failure = StateError('write failed');
      storage.writeError = failure;

      await expectLater(
        store.save(ReminderListKind.alarms, const ReminderListPreferences()),
        throwsA(same(failure)),
      );
    });
  });
}
