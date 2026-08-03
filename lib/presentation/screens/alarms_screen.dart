import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/interfaces/alarm_service.dart';
import '../../core/models/alarm.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
import '../../features/alarms/domain/alarms_manager.dart';
import '../utils/prayer_name_helper.dart';
import '../widgets/common/app_bar_widgets.dart';
import 'alarm_edit_screen.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  final _manager = ServiceLocator().get<AlarmsManager>();
  List<Alarm> _alarms = [];
  bool _loading = true;
  bool _supported = true;
  bool _granted = true;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshPermissionState();
  }

  Future<void> _load() async {
    final alarms = await _manager.getAlarms();
    if (mounted) {
      setState(() {
        _alarms = alarms;
        _loading = false;
      });
    }
  }

  Future<void> _refreshPermissionState() async {
    final service = ServiceLocator().get<AlarmService>();
    final supported = await service.isSupported();
    final granted = supported ? await service.isPermissionGranted() : false;
    if (mounted) {
      setState(() {
        _supported = supported;
        _granted = granted;
      });
    }
  }

  Future<void> _requestPermission() async {
    await ServiceLocator().get<AlarmService>().requestPermission();
    await _refreshPermissionState();
  }

  Future<void> _reschedule() async {
    final prayerTimes = context.read<AppState>().prayerTimes;
    await ServiceLocator().get<AlarmScheduler>().scheduleAlarms(
      prayerTimes: prayerTimes,
    );
  }

  Future<void> _ensurePermission() async {
    final service = ServiceLocator().get<AlarmService>();
    if (!await service.isSupported()) return;
    if (!await service.isPermissionGranted()) {
      await service.requestPermission();
    }
    await _refreshPermissionState();
  }

  Future<void> _addOrEdit([Alarm? existing]) async {
    final result = await Navigator.of(context).push<Alarm>(
      MaterialPageRoute(builder: (_) => AlarmEditScreen(alarm: existing)),
    );
    if (result == null) return;
    await _ensurePermission();
    await _manager.save(result);
    await _reschedule();
    await _load();
  }

  Future<void> _toggle(Alarm alarm, bool value) async {
    await _manager.setActive(alarm, value);
    await _reschedule();
    await _load();
  }

  Future<void> _delete(Alarm alarm) async {
    await _manager.delete(alarm.id);
    await _reschedule();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Alarm silindi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = _permissionBanner();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const SimpleAppBar(title: 'Alarmlar', showBack: false),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.primaryDark,
        icon: const Icon(Icons.add),
        label: const Text('Alarm ekle'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.nightGradient),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.gold),
                )
              : Column(
                  children: [
                    ?banner,
                    Expanded(
                      child: _alarms.isEmpty
                          ? _empty()
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                              itemCount: _alarms.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => _AlarmCard(
                                alarm: _alarms[i],
                                onTap: () => _addOrEdit(_alarms[i]),
                                onToggle: (v) => _toggle(_alarms[i], v),
                                onDelete: () => _delete(_alarms[i]),
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// iOS < 26'da destek yok; izin verilmemişse uyarı + "İzin ver" gösterir.
  /// Her şey yolundaysa null döner (banner gizli).
  Widget? _permissionBanner() {
    if (!_supported) {
      return _banner(
        icon: Icons.info_outline_rounded,
        text:
            'Sesli alarm bu cihazda desteklenmiyor (iOS 26 ve üzeri gerekir). '
            'Alarmlar kaydedilir ancak çalmaz.',
      );
    }
    if (!_granted) {
      return _banner(
        icon: Icons.notifications_off_rounded,
        text: 'Alarmların çalması için izin gerekiyor.',
        action: TextButton(
          onPressed: _requestPermission,
          child: const Text('İzin ver', style: TextStyle(color: AppTheme.gold)),
        ),
      );
    }
    return null;
  }

  Widget _banner({required IconData icon, required String text, Widget? action}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12.5,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.alarm_off_rounded,
            size: 56,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'Henüz alarm yok',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 4),
          Text(
            'Sabit saatli veya vakte göre alarm ekle',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _AlarmCard({
    required this.alarm,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alarmTimeLabel(alarm),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alarmSubtitle(alarm),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                onPressed: onDelete,
              ),
              Switch(
                value: alarm.isActive,
                activeThumbColor: AppTheme.gold,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "07:30" (sabit) veya "İmsak −30 dk" (çıpalı).
String alarmTimeLabel(Alarm alarm) {
  if (alarm.kind == AlarmKind.fixed) {
    final h = alarm.hour.toString().padLeft(2, '0');
    final m = alarm.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  final name = PrayerNameHelper.getName(alarm.anchor);
  if (alarm.offsetMinutes == 0) return name;
  final sign = alarm.offsetMinutes < 0 ? '−' : '+';
  return '$name $sign${alarm.offsetMinutes.abs()} dk';
}

String alarmSubtitle(Alarm alarm) {
  final parts = <String>[];
  if (alarm.label.isNotEmpty) parts.add(alarm.label);
  parts.add(weekdaysLabel(alarm.weekdays));
  return parts.join(' · ');
}

String weekdaysLabel(Set<int> weekdays) {
  if (weekdays.isEmpty || weekdays.length == 7) return 'Her gün';
  if (weekdays.length == 5 && weekdays.containsAll(const {1, 2, 3, 4, 5})) {
    return 'Hafta içi';
  }
  if (weekdays.length == 2 && weekdays.containsAll(const {6, 7})) {
    return 'Hafta sonu';
  }
  const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  final sorted = weekdays.toList()..sort();
  return sorted.map((d) => names[d - 1]).join(', ');
}
