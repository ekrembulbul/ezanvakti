import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/location.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../features/qibla/data/heading_service.dart';
import '../../features/qibla/domain/qibla_direction.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/state_widgets.dart';

const Key kQiblaArrowKey = Key('qibla_arrow');
const Key kQiblaCalibrationKey = Key('qibla_calibration');

/// Kıble pusulası.
///
/// Açı konumdan hesaplanır (saf), yön cihazdan akar. İkisi hizalanınca
/// (±[_kAlignedDegrees]) haptik geri bildirim verilir — kullanıcı ekrana
/// bakmadan da hizalandığını anlasın.
class QiblaScreen extends StatefulWidget {
  final Location? location;

  /// Testlerde sensör yerine bu akış dinlenir.
  final Stream<HeadingReading>? headings;

  const QiblaScreen({super.key, required this.location, this.headings});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

const double _kAlignedDegrees = 5;

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<HeadingReading>? _subscription;
  HeadingReading? _reading;

  /// Haptik yalnızca hizaya **girerken** verilir; hizada kalırken sürekli
  /// titretmek rahatsız edici olurdu.
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    final stream = widget.headings ?? const HeadingService().headings;
    _subscription = stream.listen((reading) {
      if (!mounted) return;
      setState(() => _reading = reading);
      _handleAlignment();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  double? get _qibla {
    final location = widget.location;
    final latitude = location?.latitude;
    final longitude = location?.longitude;
    if (latitude == null || longitude == null) return null;
    return QiblaDirection.bearing(latitude: latitude, longitude: longitude);
  }

  double? get _delta {
    final qibla = _qibla;
    final reading = _reading;
    if (qibla == null || reading == null) return null;
    return QiblaDirection.difference(reading.degrees, qibla);
  }

  void _handleAlignment() {
    final delta = _delta;
    if (delta == null) return;
    final aligned = delta.abs() <= _kAlignedDegrees;
    if (aligned && !_wasAligned) HapticFeedback.mediumImpact();
    _wasAligned = aligned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const SimpleAppBar(title: 'Kıble'),
      body: AppSurface(child: _body()),
    );
  }

  Widget _body() {
    final qibla = _qibla;
    if (qibla == null) {
      return const EmptyState(
        icon: Icons.location_off_rounded,
        message: 'Konum gerekiyor',
        subtitle: 'Kıble yönü için önce bir konum seç ya da GPS ile bul.',
      );
    }

    final tokens = context.tokens;
    final reading = _reading;
    final delta = _delta;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${qibla.round()}°',
            style: AppTypography.screenTitle.copyWith(
              color: tokens.textPrimary,
              fontSize: 40,
            ),
          ),
          Text(
            'Kuzeyden sağa doğru',
            style: AppTypography.hint.copyWith(color: tokens.textTertiary),
          ),
          const SizedBox(height: 32),
          _compass(delta, tokens.accent, tokens.surface, tokens.border),
          const SizedBox(height: 32),
          if (reading == null)
            Text(
              'Pusula bekleniyor…',
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
              ),
            )
          else if (reading.needsCalibration)
            Text(
              key: kQiblaCalibrationKey,
              'Pusula kalibrasyon istiyor. Telefonu havada sekiz çizerek '
              'birkaç saniye hareket ettir.',
              textAlign: TextAlign.center,
              style: AppTypography.rowSubtitle.copyWith(color: tokens.accent),
            )
          else
            Text(
              delta != null && delta.abs() <= _kAlignedDegrees
                  ? 'Kıbleye dönüksün'
                  : '${delta!.abs().round()}° ${delta > 0 ? 'sağa' : 'sola'} dön',
              style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
            ),
        ],
      ),
    );
  }

  /// Ok, kıbleye olan **farkı** gösterir: cihaz döndükçe ok hedefe yaklaşır.
  Widget _compass(
    double? delta,
    Color accent,
    Color surface,
    Color border,
  ) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: surface,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
      child: delta == null
          ? Icon(Icons.explore_outlined, size: 64, color: border)
          : Transform.rotate(
              key: kQiblaArrowKey,
              angle: delta * math.pi / 180,
              child: Icon(Icons.navigation_rounded, size: 96, color: accent),
            ),
    );
  }
}
