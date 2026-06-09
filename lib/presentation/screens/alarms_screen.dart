import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/interfaces/alarm_service.dart';
import '../../core/models/alarm.dart';
import '../../core/models/notification_setting.dart' show PrayerType;
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
import '../../features/alarms/domain/alarms_manager.dart';
import '../utils/prayer_name_helper.dart';

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
      MaterialPageRoute(builder: (_) => _AlarmEditScreen(alarm: existing)),
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
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Alarmlar'),
        backgroundColor: AppTheme.primaryMedium,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.primaryDark,
        icon: const Icon(Icons.add),
        label: const Text('Alarm ekle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : Column(
              children: [
                ?banner,
                Expanded(
                  child: _alarms.isEmpty
                      ? _empty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                          itemCount: _alarms.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
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
  if (weekdays.isEmpty) return 'Her gün';
  const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  final sorted = weekdays.toList()..sort();
  return sorted.map((d) => names[d - 1]).join(', ');
}

class _AlarmEditScreen extends StatefulWidget {
  final Alarm? alarm;
  const _AlarmEditScreen({this.alarm});

  @override
  State<_AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<_AlarmEditScreen> {
  late AlarmKind _kind;
  late int _hour;
  late int _minute;
  late PrayerType _anchor;
  late int _offset; // negatif=önce, pozitif=sonra
  late Set<int> _weekdays;
  late String _soundId;
  late bool _vibrate;
  late bool _snoozeEnabled;
  late int _snoozeMinutes;
  late TextEditingController _label;
  String? _customSoundName;

  static const _pickSoundValue = '__pick__';

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    final now = TimeOfDay.now();
    _kind = a?.kind ?? AlarmKind.fixed;
    _hour = a?.hour ?? now.hour;
    _minute = a?.minute ?? now.minute;
    _anchor = a?.anchor ?? PrayerType.fajr;
    _offset = a?.offsetMinutes ?? 0;
    _weekdays = {...(a?.weekdays ?? const <int>{})};
    _soundId = a?.soundId ?? 'adhan';
    _vibrate = a?.vibrate ?? true;
    _snoozeEnabled = a?.snoozeEnabled ?? true;
    _snoozeMinutes = a?.snoozeMinutes ?? 5;
    _label = TextEditingController(text: a?.label ?? '');
    if (_soundId.startsWith('custom:')) {
      _customSoundName = _soundId.substring('custom:'.length);
    }
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _save() {
    final id = widget.alarm?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final alarm = Alarm(
      id: id,
      kind: _kind,
      label: _label.text.trim(),
      isActive: widget.alarm?.isActive ?? true,
      hour: _hour,
      minute: _minute,
      anchor: _anchor,
      offsetMinutes: _offset,
      weekdays: _weekdays,
      soundId: _soundId,
      vibrate: _vibrate,
      snoozeEnabled: _snoozeEnabled,
      snoozeMinutes: _snoozeMinutes,
    );
    Navigator.of(context).pop(alarm);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: Text(widget.alarm == null ? 'Alarm ekle' : 'Alarmı düzenle'),
        backgroundColor: AppTheme.primaryMedium,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Kaydet', style: TextStyle(color: AppTheme.gold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _kindToggle(),
          const SizedBox(height: 16),
          if (_kind == AlarmKind.fixed) _fixedSection() else _anchoredSection(),
          const SizedBox(height: 16),
          _section('Tekrar', _weekdaysSelector()),
          const SizedBox(height: 16),
          _section('Etiket', _labelField()),
          const SizedBox(height: 16),
          _section('Ses', _soundSelector()),
          const SizedBox(height: 8),
          _switchTile('Titreşim', _vibrate, (v) => setState(() => _vibrate = v)),
          _switchTile('Ertele (snooze)', _snoozeEnabled, (v) {
            setState(() => _snoozeEnabled = v);
          }),
          if (_snoozeEnabled) _snoozeMinutesSelector(),
        ],
      ),
    );
  }

  Widget _kindToggle() {
    return SegmentedButton<AlarmKind>(
      segments: const [
        ButtonSegment(value: AlarmKind.fixed, label: Text('Sabit saat')),
        ButtonSegment(value: AlarmKind.anchored, label: Text('Vakte göre')),
      ],
      selected: {_kind},
      onSelectionChanged: (s) => setState(() => _kind = s.first),
    );
  }

  Widget _fixedSection() {
    return _section(
      'Saat',
      InkWell(
        onTap: _pickTime,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.schedule, color: AppTheme.gold),
            ],
          ),
        ),
      ),
    );
  }

  Widget _anchoredSection() {
    final before = _offset <= 0;
    final minutes = _offset.abs();
    return _section(
      'Vakit ve sapma',
      Column(
        children: [
          DropdownButtonFormField<PrayerType>(
            initialValue: _anchor,
            dropdownColor: AppTheme.primaryMedium,
            style: const TextStyle(color: Colors.white),
            decoration: _fieldDecoration('Vakit'),
            items: PrayerNameHelper.getAllPrayerTypes()
                .map(
                  (p) => DropdownMenuItem(
                    value: p,
                    child: Text(PrayerNameHelper.getName(p)),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _anchor = v ?? _anchor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<bool>(
                  initialValue: before,
                  dropdownColor: AppTheme.primaryMedium,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Yön'),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Önce')),
                    DropdownMenuItem(value: false, child: Text('Sonra')),
                  ],
                  onChanged: (v) => setState(() {
                    final b = v ?? true;
                    _offset = (b ? -1 : 1) * minutes;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: minutes.toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _fieldDecoration('Dakika'),
                  onChanged: (v) {
                    final m = int.tryParse(v) ?? 0;
                    setState(() => _offset = (before ? -1 : 1) * m);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekdaysSelector() {
    const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return Wrap(
      spacing: 6,
      children: List.generate(7, (i) {
        final day = i + 1;
        final selected = _weekdays.contains(day);
        return FilterChip(
          label: Text(names[i]),
          selected: selected,
          showCheckmark: false,
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          selectedColor: AppTheme.gold.withValues(alpha: 0.3),
          labelStyle: const TextStyle(color: Colors.white),
          onSelected: (v) => setState(() {
            if (v) {
              _weekdays.add(day);
            } else {
              _weekdays.remove(day);
            }
          }),
        );
      }),
    );
  }

  Widget _labelField() {
    return TextField(
      controller: _label,
      style: const TextStyle(color: Colors.white),
      decoration: _fieldDecoration('Örn. Sahur'),
    );
  }

  Widget _soundSelector() {
    final isCustom = _soundId.startsWith('custom:');
    return DropdownButtonFormField<String>(
      initialValue: _soundId,
      isExpanded: true,
      dropdownColor: AppTheme.primaryMedium,
      style: const TextStyle(color: Colors.white),
      decoration: _fieldDecoration('Ses'),
      items: [
        const DropdownMenuItem(value: 'adhan', child: Text('Ezan')),
        const DropdownMenuItem(value: 'alarm', child: Text('Alarm sesi')),
        const DropdownMenuItem(value: 'default', child: Text('Varsayılan')),
        if (isCustom)
          DropdownMenuItem(
            value: _soundId,
            child: Text(
              _customSoundName ?? 'Özel ses',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const DropdownMenuItem(
          value: _pickSoundValue,
          child: Row(
            children: [
              Icon(Icons.library_music_outlined, size: 18, color: AppTheme.gold),
              SizedBox(width: 8),
              Text('Cihazdan ses seç…'),
            ],
          ),
        ),
      ],
      onChanged: (v) {
        if (v == _pickSoundValue) {
          _pickCustomSound();
          return;
        }
        setState(() => _soundId = v ?? 'adhan');
      },
    );
  }

  Future<void> _pickCustomSound() async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null) return;
    final soundId = await ServiceLocator().get<AlarmService>().importCustomSound(
      path,
    );
    if (!mounted) return;
    if (soundId == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Ses dosyası alınamadı')));
      return;
    }
    setState(() {
      _soundId = soundId;
      _customSoundName = path.split('/').last;
    });
  }

  Widget _snoozeMinutesSelector() {
    return _switchRow(
      'Erteleme süresi',
      DropdownButton<int>(
        value: _snoozeMinutes,
        dropdownColor: AppTheme.primaryMedium,
        style: const TextStyle(color: Colors.white),
        items: const [5, 10, 15, 20]
            .map((m) => DropdownMenuItem(value: m, child: Text('$m dk')))
            .toList(),
        onChanged: (v) => setState(() => _snoozeMinutes = v ?? 5),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      value: value,
      activeThumbColor: AppTheme.gold,
      onChanged: onChanged,
    );
  }

  Widget _switchRow(String title, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white)),
          trailing,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
