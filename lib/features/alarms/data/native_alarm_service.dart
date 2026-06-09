import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/interfaces/alarm_service.dart';

/// Native alarm modülüyle (Android: AlarmManager + tam ekran çalar; iOS 26+:
/// AlarmKit) tek bir platform channel üzerinden konuşan [AlarmService].
/// Desteklenmeyen platformlarda (web/masaüstü, iOS < 26) güvenle no-op döner.
class NativeAlarmService implements AlarmService {
  static const _channel = MethodChannel('com.ekrembulbul.ezanvakti/alarm');

  bool get _hasNative => Platform.isAndroid || Platform.isIOS;

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
}
