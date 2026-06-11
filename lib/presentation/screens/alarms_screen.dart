import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/notification_constants.dart';
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
    // Modelde boş küme = her gün. UI'da bunu 7 günün tamamı olarak gösteriyoruz
    // ki "Her gün" hızlı seçimi ve gün çipleri tutarlı/senkron olsun.
    final wd = a?.weekdays ?? const <int>{};
    _weekdays = wd.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : {...wd};
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
    // 7 günün tamamı = "her gün" → modelde boş küme olarak sakla (etiket sade
    // kalsın, repeats mantığı tutarlı olsun).
    final weekdaysToSave = _weekdays.length == 7 ? <int>{} : _weekdays;
    final alarm = Alarm(
      id: id,
      kind: _kind,
      label: _label.text.trim(),
      isActive: widget.alarm?.isActive ?? true,
      hour: _hour,
      minute: _minute,
      anchor: _anchor,
      offsetMinutes: _offset,
      weekdays: weekdaysToSave,
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
    final maxOffset = NotificationConstants.getMaxMinutesBefore(_anchor);
    final isBefore = _offset < 0;
    final isAfter = _offset > 0;
    final isExact = _offset == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(
          'Vakit',
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
            onChanged: (v) => setState(() {
              _anchor = v ?? _anchor;
              // Yeni vaktin sınırını aşan sapmayı kırp.
              final max = NotificationConstants.getMaxMinutesBefore(_anchor);
              if (_offset.abs() > max) _offset = _offset.sign * max;
            }),
          ),
        ),
        const SizedBox(height: 16),
        _section(
          'Zamanlama',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _timeChip('Önce', isBefore, () {
                    setState(() => _offset = -_anchorMagnitude(maxOffset));
                  }),
                  _timeChip('Tam vaktinde', isExact, () {
                    setState(() => _offset = 0);
                  }),
                  _timeChip('Sonra', isAfter, () {
                    setState(() => _offset = _anchorMagnitude(maxOffset));
                  }),
                ],
              ),
              if (!isExact) ...[
                const SizedBox(height: 12),
                _minutePicker(maxOffset, _offset.abs().clamp(1, maxOffset), isBefore),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Önce/Sonra'ya geçerken kullanılacak dakika büyüklüğü: mevcut sapma varsa
  /// onu, yoksa makul bir varsayılanı (15 dk) vaktin sınırına kırparak döner.
  int _anchorMagnitude(int maxOffset) {
    final current = _offset.abs();
    final base = current > 0 ? current : 15;
    return base.clamp(1, maxOffset);
  }

  Widget _timeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.gold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.gold : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.gold : Colors.white,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _minutePicker(int maxOffset, int magnitude, bool isBefore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: AppTheme.gold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBefore ? 'Vakitten önce' : 'Vakitten sonra',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '1 - $maxOffset dk',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(
                initialItem: (magnitude - 1).clamp(0, maxOffset - 1),
              ),
              magnification: 1.1,
              squeeze: 1.05,
              useMagnifier: true,
              itemExtent: 36,
              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                background: Colors.white.withValues(alpha: 0.08),
              ),
              onSelectedItemChanged: (index) {
                setState(() => _offset = (isBefore ? -1 : 1) * (index + 1));
              },
              children: List.generate(
                maxOffset,
                (i) => Center(
                  child: Text(
                    '${i + 1} dk',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isEveryDay => _weekdays.length == 7;
  bool get _isWeekdaysOnly =>
      _weekdays.length == 5 && _weekdays.containsAll(const {1, 2, 3, 4, 5});

  Widget _weekdaysSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _quickChip('Her gün', _isEveryDay, () {
              setState(() => _weekdays = {1, 2, 3, 4, 5, 6, 7});
            }),
            const SizedBox(width: 8),
            _quickChip('Hafta içi', _isWeekdaysOnly, () {
              setState(() => _weekdays = {1, 2, 3, 4, 5});
            }),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(7, (i) {
            final day = i + 1;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                child: _dayCell(day),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _quickChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.gold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.gold : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppTheme.gold : Colors.white,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _dayCell(int day) {
    const names = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pa'];
    final selected = _weekdays.contains(day);
    return GestureDetector(
      onTap: () => _toggleDay(day),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.gold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.gold
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          names[day - 1],
          style: TextStyle(
            color: selected ? AppTheme.gold : Colors.white70,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _toggleDay(int day) {
    setState(() {
      if (_weekdays.contains(day)) {
        // En az bir gün seçili kalsın (alarmın hiç çalmaması anlamsız).
        if (_weekdays.length > 1) _weekdays.remove(day);
      } else {
        _weekdays.add(day);
      }
    });
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
    const audioGroup = XTypeGroup(
      label: 'Ses',
      extensions: ['mp3', 'm4a', 'aac', 'wav', 'aiff', 'aif', 'caf', 'flac', 'ogg'],
      mimeTypes: ['audio/*'],
      uniformTypeIdentifiers: ['public.audio'],
    );
    final file = await openFile(acceptedTypeGroups: [audioGroup]);
    if (file == null) return;
    final soundId = await ServiceLocator().get<AlarmService>().importCustomSound(
      file.path,
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
      _customSoundName = file.name;
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
