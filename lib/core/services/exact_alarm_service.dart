import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/app_logger.dart';

class ExactAlarmService {
  static const _channel = MethodChannel('com.example.ezanvakti/exact_alarm');

  final AppLogger _logger = AppLogger();

  Future<bool> isExactAlarmAllowed() async {
    if (!Platform.isAndroid) return true;

    try {
      final allowed =
          await _channel.invokeMethod<bool>('isExactAlarmAllowed') ?? false;
      return allowed;
    } on PlatformException catch (e) {
      _logger.warning('Could not query exact alarm permission', e);
      return false;
    }
  }
}
