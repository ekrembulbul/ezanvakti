import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/prayer_time.dart';
import '../../../core/models/location.dart';
import '../../../core/models/notification_setting.dart';
import '../../../core/exceptions/parse_exception.dart';
import '../../../core/utils/app_logger.dart';

class SqliteStorage implements LocalStorage {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'ezanvakti.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE prayer_times (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location_id TEXT NOT NULL,
        date TEXT NOT NULL,
        fajr TEXT NOT NULL,
        sunrise TEXT NOT NULL,
        dhuhr TEXT NOT NULL,
        asr TEXT NOT NULL,
        maghrib TEXT NOT NULL,
        isha TEXT NOT NULL,
        UNIQUE(location_id, date)
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
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
      CREATE TABLE locations (
        id TEXT PRIMARY KEY,
        province TEXT NOT NULL,
        district TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        type TEXT NOT NULL,
        custom_name TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_prayer_times_location_date 
      ON prayer_times(location_id, date)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE locations (
          id TEXT PRIMARY KEY,
          province TEXT NOT NULL,
          district TEXT NOT NULL,
          latitude REAL,
          longitude REAL,
          type TEXT NOT NULL,
          custom_name TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS notification_settings');
      await db.execute('''
        CREATE TABLE notification_settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          prayer_type TEXT NOT NULL,
          is_active INTEGER NOT NULL,
          minutes_before INTEGER NOT NULL,
          UNIQUE(prayer_type, minutes_before)
        )
      ''');
    }
  }

  @override
  Future<void> init() async {
    await database;
  }

  @override
  Future<void> savePrayerTimes(
    List<PrayerTime> prayerTimes,
    String locationId,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (final prayerTime in prayerTimes) {
      batch.insert('prayer_times', {
        'location_id': locationId,
        'date': prayerTime.date.toIso8601String(),
        'fajr': prayerTime.fajr.toIso8601String(),
        'sunrise': prayerTime.sunrise.toIso8601String(),
        'dhuhr': prayerTime.dhuhr.toIso8601String(),
        'asr': prayerTime.asr.toIso8601String(),
        'maghrib': prayerTime.maghrib.toIso8601String(),
        'isha': prayerTime.isha.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  @override
  Future<List<PrayerTime>> getPrayerTimes({
    required String locationId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final logger = AppLogger();
    try {
      final db = await database;
      final results = await db.query(
        'prayer_times',
        where: 'location_id = ? AND date >= ? AND date <= ?',
        whereArgs: [
          locationId,
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ],
        orderBy: 'date ASC',
      );

      return results.map((row) {
        try {
          return PrayerTime.fromJson(row);
        } catch (e, stackTrace) {
          logger.parseError(
            context: 'SqliteStorage.getPrayerTimes - PrayerTime.fromJson',
            error: e,
            stackTrace: stackTrace,
            additionalData: {'row': row},
          );
          throw ParseException(
            message: 'Failed to parse prayer time from database',
            originalError: e,
            stackTrace: stackTrace,
            context: 'SqliteStorage.getPrayerTimes',
          );
        }
      }).toList();
    } catch (e, stackTrace) {
      if (e is ParseException) rethrow;
      logger.error('Error in SqliteStorage.getPrayerTimes', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<PrayerTime?> getDailyPrayerTime({
    required String locationId,
    required DateTime date,
  }) async {
    final logger = AppLogger();
    try {
      final db = await database;
      final dateStr = DateTime(
        date.year,
        date.month,
        date.day,
      ).toIso8601String();

      final results = await db.query(
        'prayer_times',
        where: 'location_id = ? AND date = ?',
        whereArgs: [locationId, dateStr],
        limit: 1,
      );

      if (results.isEmpty) return null;

      try {
        return PrayerTime.fromJson(results.first);
      } catch (e, stackTrace) {
        logger.parseError(
          context: 'SqliteStorage.getDailyPrayerTime - PrayerTime.fromJson',
          error: e,
          stackTrace: stackTrace,
          additionalData: {'row': results.first},
        );
        throw ParseException(
          message: 'Failed to parse prayer time from database',
          originalError: e,
          stackTrace: stackTrace,
          context: 'SqliteStorage.getDailyPrayerTime',
        );
      }
    } catch (e, stackTrace) {
      if (e is ParseException) rethrow;
      logger.error('Error in SqliteStorage.getDailyPrayerTime', e, stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteOldPrayerTimes(DateTime cutoffDate) async {
    final db = await database;
    await db.delete(
      'prayer_times',
      where: 'date < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  @override
  Future<void> saveActiveLocation(Location location) async {
    final db = await database;
    await db.insert('settings', {
      'key': 'active_location',
      'value': json.encode(location.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Location?> getActiveLocation() async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['active_location'],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final value = results.first['value'] as String;
    return Location.fromJson(json.decode(value) as Map<String, dynamic>);
  }

  @override
  Future<void> saveNotificationSettings(
    List<NotificationSetting> settings,
  ) async {
    final db = await database;
    // Atomic replace: deleting the old rows and inserting the new ones must
    // not be interrupted, otherwise settings could be lost on a crash.
    await db.transaction((txn) async {
      await txn.delete('notification_settings');

      final batch = txn.batch();
      for (final setting in settings) {
        batch.insert('notification_settings', {
          'prayer_type': setting.prayerType.name,
          'is_active': setting.isActive ? 1 : 0,
          'minutes_before': setting.minutesBefore,
        });
      }

      await batch.commit(noResult: true);
    });
  }

  Future<void> addNotificationSetting(NotificationSetting setting) async {
    final db = await database;
    await db.insert('notification_settings', {
      'prayer_type': setting.prayerType.name,
      'is_active': setting.isActive ? 1 : 0,
      'minutes_before': setting.minutesBefore,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteNotificationSetting({
    required PrayerType prayerType,
    required int minutesBefore,
  }) async {
    final db = await database;
    await db.delete(
      'notification_settings',
      where: 'prayer_type = ? AND minutes_before = ?',
      whereArgs: [prayerType.name, minutesBefore],
    );
  }

  Future<void> updateNotificationSetting(NotificationSetting setting) async {
    final db = await database;
    await db.update(
      'notification_settings',
      {'is_active': setting.isActive ? 1 : 0},
      where: 'prayer_type = ? AND minutes_before = ?',
      whereArgs: [setting.prayerType.name, setting.minutesBefore],
    );
  }

  @override
  Future<List<NotificationSetting>> getNotificationSettings() async {
    final db = await database;
    final results = await db.query('notification_settings');

    final settings = <NotificationSetting>[];
    for (final row in results) {
      final typeName = row['prayer_type'] as String;
      final matches = PrayerType.values.where((e) => e.name == typeName);
      if (matches.isEmpty) continue; // Skip unknown prayer types (enum drift).
      settings.add(
        NotificationSetting(
          prayerType: matches.first,
          isActive: (row['is_active'] as int) == 1,
          minutesBefore: row['minutes_before'] as int,
        ),
      );
    }
    return settings;
  }

  @override
  Future<void> saveLastUpdateTime(DateTime time) async {
    final db = await database;
    await db.insert('settings', {
      'key': 'last_update_time',
      'value': time.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<DateTime?> getLastUpdateTime() async {
    final db = await database;
    final results = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['last_update_time'],
      limit: 1,
    );

    if (results.isEmpty) return null;
    final value = results.first['value'] as String;
    try {
      return DateTime.parse(value);
    } on FormatException catch (e) {
      AppLogger().warning('Invalid last_update_time in storage, ignoring', e);
      return null;
    }
  }

  @override
  Future<List<Location>> getSavedLocations() async {
    final db = await database;
    final results = await db.query('locations', orderBy: 'created_at DESC');

    return results.map((row) {
      return Location(
        id: row['id'] as String,
        province: row['province'] as String,
        district: row['district'] as String,
        latitude: row['latitude'] as double?,
        longitude: row['longitude'] as double?,
        type: LocationType.values.firstWhere(
          (e) => e.name == row['type'],
          orElse: () => LocationType.manual,
        ),
        customName: row['custom_name'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> saveLocation(Location location) async {
    final db = await database;
    await db.insert('locations', {
      'id': location.id,
      'province': location.province,
      'district': location.district,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'type': location.type.name,
      'custom_name': location.customName,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> updateLocation(Location location) async {
    final db = await database;
    await db.update(
      'locations',
      {
        'province': location.province,
        'district': location.district,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'type': location.type.name,
        'custom_name': location.customName,
      },
      where: 'id = ?',
      whereArgs: [location.id],
    );
  }

  @override
  Future<void> deleteLocation(String locationId) async {
    final db = await database;
    await db.delete('locations', where: 'id = ?', whereArgs: [locationId]);
  }
}
