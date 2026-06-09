import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/interfaces/alarm_service.dart';

/// Android tarafında native alarm modülüyle (AlarmManager + tam ekran çalar +
/// foreground service) konuşan [AlarmService] gerçeklemesi.
class AndroidAlarmService implements AlarmService {
  static const _channel = MethodChannel('com.ekrembulbul.ezanvakti/alarm');

  @override
  Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('isSupported') ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('requestPermission') ?? false;
  }

  @override
  Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return false;
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
    if (!Platform.isAndroid) return;
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
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('cancelAlarm', {'id': id});
  }

  @override
  Future<void> cancelAllAlarms() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('cancelAllAlarms');
  }
}
