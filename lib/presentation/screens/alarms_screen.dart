import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/interfaces/alarm_service.dart';
import '../../core/models/alarm.dart';
import '../../core/providers/app_state.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
import '../../features/alarms/domain/alarms_manager.dart';
import '../utils/prayer_name_helper.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/grouped_list.dart';
import '../widgets/common/info_banner.dart';
import '../widgets/common/section_label.dart';
import '../widgets/common/state_widgets.dart';
import '../widgets/common/swipe_to_delete.dart';
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: 'Alarmlar',
        showBack: false,
        // Tasarimda ekleme eylemi app bar'in saginda; FAB alt bilgi satirini
        // ortuyordu.
        actions: [
          AppBarActionButton(
            icon: Icons.add_rounded,
            onTap: () => _addOrEdit(),
            tooltip: 'Alarm ekle',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppSurface(
        child: _loading
            ? const LoadingState()
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ?_permissionBanner(),
                    Expanded(child: _alarms.isEmpty ? _empty() : _list()),
                    _footer(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _list() {
    final tokens = context.tokens;

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        SectionLabel('${_alarms.length} alarm'),
        const SizedBox(height: 10),
        GroupedList(
          children: [
            for (final alarm in _alarms)
              SwipeToDelete(
                itemKey: ValueKey(alarm.id),
                confirmText:
                    '${alarmTimeLabel(alarm)} alarmını silmek istiyor musunuz?',
                onDelete: () => _delete(alarm),
                child: GroupedRow(
                  icon: Icons.alarm_rounded,
                  title: Text(alarmTimeLabel(alarm)),
                  subtitle: Text(alarmSubtitle(alarm)),
                  onTap: () => _addOrEdit(alarm),
                  dimmed: !alarm.isActive,
                  trailing: Switch(
                    value: alarm.isActive,
                    onChanged: (value) => _toggle(alarm, value),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            'Silmek için satırı sola kaydırın. Alarmlar vakit güncellendiğinde '
            'otomatik yeniden planlanır.',
            style: AppTypography.hint.copyWith(
              color: tokens.textTertiary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(Icons.bedtime_rounded, size: 16, color: tokens.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              // Sıradaki alarmın saatini yazan sürüm ayrı bir turda gelecek.
              'Alarmlar vakit verisi güncellendikçe yeniden planlanır.',
              style: AppTypography.hint.copyWith(color: tokens.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  /// iOS < 26'da destek yok; izin verilmemişse uyarı + "İzin ver" gösterir.
  /// Her şey yolundaysa null döner (banner gizli).
  Widget? _permissionBanner() {
    if (!_supported) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: InfoBanner(
          icon: Icons.info_outline_rounded,
          text:
              'Sesli alarm bu cihazda desteklenmiyor (iOS 26 ve üzeri gerekir). '
              'Alarmlar kaydedilir ancak çalmaz.',
        ),
      );
    }
    if (!_granted) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: InfoBanner(
          icon: Icons.notifications_off_rounded,
          text: 'Alarmların çalması için izin gerekiyor.',
          action: TextButton(
            onPressed: _requestPermission,
            child: const Text('İzin ver'),
          ),
        ),
      );
    }
    return null;
  }

  Widget _empty() {
    return const EmptyState(
      icon: Icons.alarm_off_rounded,
      message: 'Henüz alarm yok',
      subtitle: 'Sabit saatli veya vakte göre alarm ekle',
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
