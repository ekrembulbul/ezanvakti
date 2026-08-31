import 'package:flutter/material.dart';
import '../../l10n/l10n_extensions.dart';

import '../../core/models/calculation_params.dart';
import '../../core/models/calculation_settings.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/section_label.dart';
import '../widgets/location/calculation_params_selector.dart';
import '../widgets/settings/prayer_tune_selector.dart';
import '../../core/models/notification_setting.dart' show PrayerType;

/// Uygulama genelindeki varsayılan hesaplama ayarını (yöntem, İkindi mezhebi,
/// yüksek enlem düzeltmesi) düzenler. Kaydedilince yeni ayar geri döndürülür;
/// çağıran taraf kaydetme + önbellek temizliği + yeniden yüklemeyi üstlenir.
class CalculationSettingsScreen extends StatefulWidget {
  final CalculationSettings initial;

  const CalculationSettingsScreen({super.key, required this.initial});

  @override
  State<CalculationSettingsScreen> createState() =>
      _CalculationSettingsScreenState();
}

class _CalculationSettingsScreenState extends State<CalculationSettingsScreen> {
  late int _method;
  late AsrSchool _school;
  late LatitudeAdjustment _latitudeAdjustment;
  late Map<PrayerType, int> _tune;

  @override
  void initState() {
    super.initState();
    _method = widget.initial.method;
    _school = AsrSchool.fromValue(widget.initial.school);
    _latitudeAdjustment = LatitudeAdjustment.fromValue(
      widget.initial.latitudeAdjustmentMethod,
    );
    _tune = Map<PrayerType, int>.from(widget.initial.tune);
  }

  void _save() {
    final settings = CalculationSettings(
      method: _method,
      school: _school.value,
      latitudeAdjustmentMethod: _latitudeAdjustment.value,
      tune: _tune,
    );
    Navigator.of(context).pop(settings);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const SimpleAppBar(title: 'Hesaplama'),
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      context.l10n.calcGlobalNote,
                      style: AppTypography.rowSubtitle.copyWith(
                        color: tokens.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CalculationParamsSelector(
                      method: _method,
                      school: _school,
                      latitudeAdjustment: _latitudeAdjustment,
                      onMethodChanged: (value) => setState(() {
                        _method = value;
                        _school = AsrSchool.fromValue(
                          CalculationDefaults.schoolForMethod(value),
                        );
                      }),
                      onSchoolChanged: (value) =>
                          setState(() => _school = value),
                      onLatitudeAdjustmentChanged: (value) =>
                          setState(() => _latitudeAdjustment = value),
                    ),
                    const SizedBox(height: 28),
                    SectionLabel(context.l10n.calcTuneSection),
                    const SizedBox(height: 10),
                    PrayerTuneSelector(
                      tune: _tune,
                      onChanged: (value) => setState(() => _tune = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _save, child: const Text('Kaydet')),
            ],
          ),
        ),
      ),
    );
  }
}
