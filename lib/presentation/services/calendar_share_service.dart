import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models/location.dart';
import '../../core/utils/app_logger.dart';

/// Takvim ve imsakiye görüntüsünü paylaşır.
///
/// Görüntü çağırandan PNG olarak gelir (ekran dışı çizim,
/// `WidgetImageRenderer`); dosya adı ve paylaşım metni saf yardımcılarda
/// tutuluyor ki test edilebilsinler.
class CalendarShareService {
  final AppLogger _logger;

  CalendarShareService({AppLogger? logger}) : _logger = logger ?? AppLogger();

  static void logRenderFailure(Object error, StackTrace stack) =>
      AppLogger().error('Calendar image render failed', error, stack);

  Future<bool> sharePng({
    required Uint8List bytes,
    required Location location,
    required DateTime date,
    required String caption,
    Rect? originRect,
  }) async {
    Directory? directory;
    try {
      directory = await Directory.systemTemp.createTemp('ezan-vakti-share-');
      final file = await File(
        p.join(directory.path, fileNameFor(location, date)),
      ).writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: caption,
          sharePositionOrigin: originRect,
        ),
      );
      return true;
    } catch (error, stack) {
      _logger.error('Calendar share failed', error, stack);
      return false;
    } finally {
      if (directory != null) {
        try {
          await directory.delete(recursive: true);
        } catch (error, stack) {
          _logger.warning('Calendar share cleanup failed', error, stack);
        }
      }
    }
  }

  /// Paylaşılan dosyanın adı: konum ve tarih taşır, dosya sisteminde güvenli.
  static String fileNameFor(Location location, DateTime date) {
    final label = _slug(location.displayName);
    final month = date.month.toString().padLeft(2, '0');
    return 'ezan-vakti-$label-${date.year}-$month.png';
  }

  /// Paylaşım metni. Çeviri çağırandan gelir; servis `BuildContext` tutmaz.
  static String captionFor(
    Location location,
    DateTime date, {
    required String Function(String location, String period) format,
  }) {
    final period = '${date.year}/${date.month.toString().padLeft(2, '0')}';
    return format(location.displayName, period);
  }

  /// Türkçe karakterleri ve boşlukları dosya adına uygun hale getirir.
  static String _slug(String value) {
    const map = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'İ': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'Ç': 'c',
      'Ğ': 'g',
      'Ö': 'o',
      'Ş': 's',
      'Ü': 'u',
    };
    final buffer = StringBuffer();
    for (final char in value.toLowerCase().split('')) {
      final mapped = map[char] ?? char;
      buffer.write(RegExp(r'[a-z0-9]').hasMatch(mapped) ? mapped : '-');
    }
    return buffer
        .toString()
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
