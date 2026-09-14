import 'dart:async';
import '../../l10n/l10n_extensions.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/location.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../features/qibla/data/heading_service.dart';
import '../../features/qibla/domain/qibla_alignment.dart';
import '../../features/qibla/domain/qibla_direction.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/state_widgets.dart';
import '../widgets/qibla/qibla_compass.dart';

export '../widgets/qibla/qibla_compass.dart' show kQiblaArrowKey;

const Key kQiblaCalibrationKey = Key('qibla_calibration');
const Key kQiblaAlignedKey = Key('qibla_aligned');

/// Kıble pusulası.
///
/// Açı konumdan hesaplanır (saf), yön cihazdan akar. İkisi hizalanınca
/// ([QiblaAlignment]) kadran onay rengine döner ve haptik geri bildirim
/// verilir — kullanıcı ekrana bakmadan da hizalandığını anlasın.
class QiblaScreen extends StatefulWidget {
  final Location? location;

  /// Testlerde sensör yerine bu akış dinlenir.
  final Stream<HeadingReading>? headings;

  const QiblaScreen({super.key, required this.location, this.headings});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  StreamSubscription<HeadingReading>? _subscription;
  HeadingReading? _reading;

  /// Haptik yalnızca hizaya **girerken** verilir; hizada kalırken sürekli
  /// titretmek rahatsız edici olurdu.
  bool _aligned = false;

  /// İbrenin sürekli açısı (tur): fark ±180 sınırını geçerken en kısa yoldan
  /// ilerler, yoksa animasyon ters yönde tam tur atar.
  double _turns = 0;
  double? _lastDelta;

  @override
  void initState() {
    super.initState();
    final stream = widget.headings ?? const HeadingService().headings;
    _subscription = stream.listen((reading) {
      if (!mounted) return;
      setState(() {
        _reading = reading;
        _track(_delta);
      });
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

  /// Yeni farkı ibre açısına ve hizalanma durumuna işler.
  void _track(double? delta) {
    if (delta == null) return;
    final last = _lastDelta;
    _turns = last == null
        ? delta / 360
        : _turns + QiblaAlignment.shortestStep(from: last, to: delta) / 360;
    _lastDelta = delta;

    final aligned = QiblaAlignment.resolve(delta: delta, wasAligned: _aligned);
    if (aligned && !_aligned) HapticFeedback.mediumImpact();
    _aligned = aligned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(title: context.l10n.qiblaTitle),
      body: AppSurface(child: _body()),
    );
  }

  Widget _body() {
    final qibla = _qibla;
    if (qibla == null) {
      return EmptyState(
        icon: Icons.location_off_rounded,
        message: context.l10n.qiblaNeedsLocation,
        subtitle: context.l10n.qiblaNeedsLocationHint,
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
            context.l10n.qiblaFromNorth,
            style: AppTypography.hint.copyWith(color: tokens.textTertiary),
          ),
          const SizedBox(height: 32),
          QiblaCompass(turns: delta == null ? null : _turns, aligned: _aligned),
          const SizedBox(height: 32),
          if (reading == null)
            Text(
              context.l10n.qiblaWaiting,
              style: AppTypography.rowSubtitle.copyWith(
                color: tokens.textSecondary,
              ),
            )
          else if (reading.needsCalibration)
            Text(
              key: kQiblaCalibrationKey,
              context.l10n.qiblaCalibrate,
              textAlign: TextAlign.center,
              style: AppTypography.rowSubtitle.copyWith(color: tokens.accent),
            )
          else
            _directionLine(delta),
        ],
      ),
    );
  }

  /// Hizalandıysa onay rengiyle onay, değilse hangi yöne kaç derece dönüleceği.
  Widget _directionLine(double? delta) {
    final tokens = context.tokens;
    if (delta != null && _aligned) {
      return Row(
        key: kQiblaAlignedKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 20, color: tokens.success),
          const SizedBox(width: 8),
          Text(
            context.l10n.qiblaAligned,
            style: AppTypography.rowTitle.copyWith(color: tokens.success),
          ),
        ],
      );
    }
    return Text(
      _directionText(delta),
      style: AppTypography.rowTitle.copyWith(color: tokens.textPrimary),
    );
  }

  String _directionText(double? delta) {
    if (delta == null) return context.l10n.qiblaWaiting;
    final degrees = delta.abs().round();
    return delta > 0
        ? context.l10n.qiblaTurnRight(degrees)
        : context.l10n.qiblaTurnLeft(degrees);
  }
}
