import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/interfaces/alarm_service.dart';
import '../../../core/models/alarm_mission.dart';
import '../../../core/models/alarm_theme.dart';
import '../../../core/models/mission_stop_event.dart';

/// Native alarm modülüyle (Android: AlarmManager + tam ekran çalar; iOS 26+:
/// AlarmKit) tek bir platform channel üzerinden konuşan [AlarmService].
/// Desteklenmeyen platformlarda (web/masaüstü, iOS < 26) güvenle no-op döner.
class NativeAlarmService implements AlarmService {
  static const _channel = MethodChannel('com.ekrembulbul.ezanvakti/alarm');

  static final _missionStops = StreamController<MissionStopEvent>.broadcast();
  static bool _handlerAttached = false;

  NativeAlarmService() {
    // Tek sefer: native, uygulama ayaktayken bu kanaldan bize cagri yapiyor.
    if (_handlerAttached) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'missionStopped') return null;
      _missionStops.add(
        MissionStopEvent.fromMap(call.arguments as Map<Object?, Object?>),
      );
      return null;
    });
  }

  @override
  Stream<MissionStopEvent> get missionStops => _missionStops.stream;

  /// `dart:io Platform` yerine [defaultTargetPlatform]: testlerde
  /// `debugDefaultTargetPlatformOverride` ile ayarlanabiliyor ve web'de
  /// patlamıyor.
  bool get _hasNative =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<bool> isSupported() async {
    if (!_hasNative) return false;
    return await _channel.invokeMethod<bool>('isSupported') ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_hasNative) return false;
    return await _channel.invokeMethod<bool>('requestPermission') ?? false;
  }

  @override
  Future<bool> isPermissionGranted() async {
    if (!_hasNative) return false;
    return await _channel.invokeMethod<bool>('isPermissionGranted') ?? false;
  }

  @override
  Future<void> scheduleAlarm({
    required String id,
    required DateTime scheduledTime,
    required String label,
    required String soundId,
    required bool vibrate,
    required bool snoozeEnabled,
    required int snoozeMinutes,
    required AlarmTheme theme,
    required AlarmMission mission,
    required int missionLevel,
    required Map<String, dynamic> chainConfig,
  }) async {
    if (!_hasNative) return;
    await _channel.invokeMethod('scheduleAlarm', {
      'id': id,
      'timeMillis': scheduledTime.millisecondsSinceEpoch,
      'label': label,
      'soundId': soundId,
      'vibrate': vibrate,
      'snoozeEnabled': snoozeEnabled,
      'snoozeMinutes': snoozeMinutes,
      'theme': theme.toMap(),
      'mission': mission.name,
      'missionLevel': missionLevel,
      'missionEnabled': mission.requiresGate,
      'chainConfig': chainConfig,
    });
  }

  @override
  Future<void> cancelAlarm(String id) async {
    if (!_hasNative) return;
    await _channel.invokeMethod('cancelAlarm', {'id': id});
  }

  @override
  Future<void> cancelAllAlarms() async {
    if (!_hasNative) return;
    await _channel.invokeMethod('cancelAllAlarms');
  }

  @override
  Future<String?> importCustomSound(String sourcePath) async {
    if (!_hasNative) return null;
    final name = sourcePath.split('/').last;
    return await _channel.invokeMethod<String>('importCustomSound', {
      'path': sourcePath,
      'name': name,
    });
  }

  @override
  Future<List<MissionStopEvent>> consumeMissionEvents() async {
    if (!_hasNative) return const [];
    final raw = await _channel.invokeMethod<List<Object?>>(
      'consumeMissionEvents',
    );
    if (raw == null) return const [];
    return [
      for (final e in raw) MissionStopEvent.fromMap(e as Map<Object?, Object?>),
    ];
  }

  @override
  Future<void> beginMission(String alarmId) async {
    if (!_hasNative) return;
    await _channel.invokeMethod('beginMission', {'id': alarmId});
  }

  @override
  Future<void> completeMission(String alarmId) async {
    if (!_hasNative) return;
    await _channel.invokeMethod('completeMission', {'id': alarmId});
  }

  @override
  Future<void> abortMission(String alarmId) async {
    if (!_hasNative) return;
    await _channel.invokeMethod('abortMission', {'id': alarmId});
  }
}
