import 'package:flutter/material.dart';

import '../../core/models/calculation_params.dart';
import '../../core/models/calculation_settings.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/location/calculation_params_selector.dart';

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

  @override
  void initState() {
    super.initState();
    _method = widget.initial.method;
    _school = AsrSchool.fromValue(widget.initial.school);
    _latitudeAdjustment = LatitudeAdjustment.fromValue(
      widget.initial.latitudeAdjustmentMethod,
    );
  }

  void _save() {
    final settings = CalculationSettings(
      method: _method,
      school: _school.value,
      latitudeAdjustmentMethod: _latitudeAdjustment.value,
    );
    Navigator.of(context).pop(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(title: 'Hesaplama'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.nightGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        'Tüm konumlar için varsayılan ayar. Bir konum kendi '
                        'ayarını seçmediği sürece bu kullanılır.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
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
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Kaydet',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
