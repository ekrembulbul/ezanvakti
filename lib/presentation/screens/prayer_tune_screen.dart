import 'package:flutter/material.dart';

import '../../core/models/notification_setting.dart' show PrayerType;
import '../../l10n/l10n_extensions.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/settings/prayer_tune_selector.dart';

/// Vakit başına ± dakika düzeltmesini düzenler. Kaydedilince yeni harita geri
/// döndürülür; kaydetme ve yeniden yükleme çağırana aittir. Düzeltme okurken
/// uygulandığı için (ADR 0004) önbellek geçerli kalır, yeniden çekim olmaz.
class PrayerTuneScreen extends StatefulWidget {
  final Map<PrayerType, int> initial;

  const PrayerTuneScreen({super.key, required this.initial});

  @override
  State<PrayerTuneScreen> createState() => _PrayerTuneScreenState();
}

class _PrayerTuneScreenState extends State<PrayerTuneScreen> {
  late Map<PrayerType, int> _tune;

  @override
  void initState() {
    super.initState();
    _tune = Map<PrayerType, int>.from(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(title: context.l10n.settingsPrayerTune),
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    PrayerTuneSelector(
                      tune: _tune,
                      onChanged: (value) => setState(() => _tune = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_tune),
                child: Text(context.l10n.actionSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
