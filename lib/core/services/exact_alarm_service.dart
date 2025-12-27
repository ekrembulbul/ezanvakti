import 'dart:io';

import 'package:flutter/services.dart';

class ExactAlarmService {
  static const _channel = MethodChannel('com.example.ezanvakti/exact_alarm');

  Future<bool> isExactAlarmAllowed() async {
    if (!Platform.isAndroid) return true;

    try {
      final allowed =
          await _channel.invokeMethod<bool>('isExactAlarmAllowed') ?? false;
      return allowed;
    } catch (_) {
      return false;
    }
  }
}
