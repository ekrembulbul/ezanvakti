import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models/location.dart';
import '../../core/utils/app_logger.dart';

/// Aylık vakit tablosunu görsel olarak paylaşır.
///
/// Görüntüyü çekmek `RepaintBoundary`ye bağlı; dosya adı ve paylaşım metni
/// saf yardımcılarda tutuluyor ki test edilebilsinler.
class CalendarShareService {
  final AppLogger _logger;

  CalendarShareService({AppLogger? logger}) : _logger = logger ?? AppLogger();

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
    String Function(String location, String period)? format,
  }) {
    final period =
        '${date.year}/${date.month.toString().padLeft(2, '0')}';
    return format?.call(location.displayName, period) ??
        '${location.displayName} · $period namaz vakitleri';
  }

  /// Türkçe karakterleri ve boşlukları dosya adına uygun hale getirir.
  static String _slug(String value) {
    const map = {
      'ç': 'c', 'ğ': 'g', 'ı': 'i', 'İ': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
      'Ç': 'c', 'Ğ': 'g', 'Ö': 'o', 'Ş': 's', 'Ü': 'u',
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

  /// [boundaryKey] ile işaretli alanı PNG'ye çevirip paylaşım sayfasını açar.
  ///
  /// Görüntü alınamazsa sessizce başarısız olmaz: `false` döner ve çağıran
  /// kullanıcıya bilgi verir.
  Future<bool> shareTable({
    required RenderRepaintBoundary? boundary,
    required Location location,
    required DateTime date,
    Rect? originRect,
    String Function(String location, String period)? captionFormat,
  }) async {
    if (boundary == null) {
      _logger.warning('Takvim paylasimi: cizim alani bulunamadi');
      return false;
    }
    try {
      // 2.5x: paylaşılan görüntü telefon ekranından büyük yerlerde de okunur
      // kalsın, ama dosya boyutu makul olsun.
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        _logger.warning('Takvim paylasimi: PNG kodlanamadi');
        return false;
      }
      final file = await _writeTempFile(
        bytes.buffer.asUint8List(),
        fileNameFor(location, date),
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: captionFor(location, date, format: captionFormat),
          sharePositionOrigin: originRect,
        ),
      );
      return true;
    } catch (e, stackTrace) {
      _logger.error('Takvim paylasilamadi', e, stackTrace);
      return false;
    }
  }

  Future<File> _writeTempFile(Uint8List bytes, String name) async {
    final file = File(p.join(Directory.systemTemp.path, name));
    return file.writeAsBytes(bytes, flush: true);
  }
}
