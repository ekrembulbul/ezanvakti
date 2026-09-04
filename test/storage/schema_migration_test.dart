import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ezanvakti/features/prayer_times/data/sqlite_storage.dart';

/// Eski sürümlerden gelen kullanıcıların şeması sessizce bozulmasın.
///
/// 0.5.5 (şema v8) yüklü bir telefona 0.11.x geldiğinde `onUpgrade` v8'den
/// v13'e tek seferde çıkıyor. Blokların **artan sırada** çalışması şart:
/// v11 adımı, v10'da eklenen `sound_id`/`weekdays`/`label` kolonlarını
/// okuyor. Sıra bozukken bu yükseltme `no such column: sound_id` ile
/// patlıyordu ve uygulama açılış ekranında kalıyordu.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  /// v8 şeması: 0.5.5'in bıraktığı hâl. `notification_settings` burada hâlâ
  /// v3 sütunlarını taşıyor — `sound_id`, `weekdays`, `label` yok.
  Future<void> createV8Schema(Database db) async {
    await db.execute('''
      CREATE TABLE locations (
        id TEXT PRIMARY KEY,
        province TEXT NOT NULL,
        district TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        type TEXT NOT NULL,
        custom_name TEXT,
        created_at TEXT NOT NULL,
        method INTEGER,
        school INTEGER,
        latitude_adjustment INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE notification_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        prayer_type TEXT NOT NULL,
        is_active INTEGER NOT NULL,
        minutes_before INTEGER NOT NULL,
        UNIQUE(prayer_type, minutes_before)
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE alarms (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        label TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        hour INTEGER NOT NULL DEFAULT 0,
        minute INTEGER NOT NULL DEFAULT 0,
        anchor TEXT NOT NULL DEFAULT 'fajr',
        offset_minutes INTEGER NOT NULL DEFAULT 0,
        weekdays TEXT NOT NULL DEFAULT '',
        sound_id TEXT NOT NULL DEFAULT 'default',
        vibrate INTEGER NOT NULL DEFAULT 1,
        snooze_enabled INTEGER NOT NULL DEFAULT 1,
        snooze_minutes INTEGER NOT NULL DEFAULT 5,
        created_at TEXT NOT NULL,
        mission TEXT NOT NULL DEFAULT 'none',
        mission_level INTEGER NOT NULL DEFAULT 1,
        max_snoozes INTEGER,
        qr_payload TEXT
      )
    ''');
  }

  Future<Database> upgradeFrom(int oldVersion) async {
    final storage = SqliteStorage();
    // `singleInstance: false` olmadan tum testler ayni in-memory DB'yi
    // paylasiyor ve ikinci test "table locations already exists" aliyor.
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await createV8Schema(db);
    await db.insert('notification_settings', {
      'prayer_type': 'dhuhr',
      'is_active': 1,
      'minutes_before': 15,
    });
    await db.insert('alarms', {
      'id': 'a1',
      'kind': 'fixed',
      'sound_id': 'adhan',
      'created_at': DateTime(2026).toIso8601String(),
    });
    await storage.onUpgrade(db, oldVersion, 13);
    return db;
  }

  test('v8 -> v13 yukseltmesi hatasiz tamamlanir', () async {
    final db = await upgradeFrom(8);
    addTearDown(db.close);

    final columns = await db.rawQuery(
      "PRAGMA table_info('notification_settings')",
    );
    final names = columns.map((c) => c['name']).toSet();
    expect(
      names,
      containsAll(<String>['derived_kind', 'sound_id', 'weekdays', 'label']),
      reason: 'v13 sutunlarinin tamami olusmali',
    );
  });

  test('v8 -> v13 yukseltmesi mevcut bildirim ayarini korur', () async {
    final db = await upgradeFrom(8);
    addTearDown(db.close);

    final rows = await db.query('notification_settings');
    expect(rows, hasLength(1));
    expect(rows.single['prayer_type'], 'dhuhr');
    expect(rows.single['minutes_before'], 15);
    expect(rows.single['derived_kind'], '');
  });

  test('v8 -> v13 yukseltmesi kaldirilmis alarm sesini temizler', () async {
    final db = await upgradeFrom(8);
    addTearDown(db.close);

    final rows = await db.query('alarms');
    expect(rows.single['sound_id'], 'default');
  });

  test('yukseltme bloklari artan sirada duruyor', () {
    final source = File(
      'lib/features/prayer_times/data/sqlite_storage.dart',
    ).readAsStringSync();
    final upgradeBody = source.substring(
      source.indexOf('Future<void> onUpgrade('),
    );
    final versions = RegExp(
      r'if \(oldVersion < (\d+)\)',
    ).allMatches(upgradeBody).map((m) => int.parse(m.group(1)!)).toList();

    expect(versions, isNotEmpty);
    expect(
      versions,
      orderedEquals(List.of(versions)..sort()),
      reason:
          'Her adim bir oncekinin biraktigi semayi varsayiyor; sira bozulunca '
          'uzak surumlerden gelen yukseltme patliyor. Bulunan sira: $versions',
    );
  });

  test('v8 -> v13 yukseltmesi yeni tablolari olusturur', () async {
    final db = await upgradeFrom(8);
    addTearDown(db.close);

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final names = tables.map((t) => t['name']).toSet();
    expect(names, contains('qr_codes'));
    expect(names, contains('fasting_log'));
  });
}
