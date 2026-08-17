import '../../core/models/alarm_mission.dart';
import '../../features/alarms/domain/snooze_options.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/constants/notification_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/interfaces/alarm_service.dart';
import '../../core/models/alarm.dart';
import '../../core/models/notification_setting.dart' show PrayerType;
import '../../core/theme/app_tokens.dart';
import '../../core/theme/tokens_context.dart';
import '../utils/prayer_name_helper.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/section_label.dart';
import '../widgets/common/sliding_segment.dart';

class AlarmEditScreen extends StatefulWidget {
  final Alarm? alarm;
  const AlarmEditScreen({super.key, this.alarm});

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
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
  late AlarmMission _mission;
  late int _missionLevel;
  int? _maxSnoozes;
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
    _mission = a?.mission ?? AlarmMission.none;
    _missionLevel = a?.missionLevel ?? 1;
    _maxSnoozes = a?.maxSnoozes;
    _label = TextEditingController(text: a?.label ?? '');
    if (_soundId.startsWith('custom:')) {
      _customSoundName = _soundId.substring('custom:'.length);
    }
  }

  /// Bu ekranda çok sayıda yardımcı metot renk okuyor; her birinde
  /// `context.tokens` yazmak yerine tek kısayol.
  AppTokens get tokens => context.tokens;

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
      mission: _mission,
      missionLevel: _missionLevel,
      maxSnoozes: _maxSnoozes,
    );
    Navigator.of(context).pop(normalizeAlarmSnoozeLimit(alarm));
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
      // Transparent SimpleAppBar arkasında gradient'in üst rengi görünür →
      // kesintisiz. `extendBodyBehindAppBar` olmadan gradyan app bar'ın
      // altından başlıyor ve üstte saydam Scaffold siyah bir şerit bırakıyordu.
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: widget.alarm == null ? 'Alarm ekle' : 'Alarmı düzenle',
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Kaydet',
              style: TextStyle(color: context.tokens.accent),
            ),
          ),
        ],
      ),
      body: AppSurface(
        child: ListView(
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
          if (_snoozeEnabled) _maxSnoozesSelector(),
          _missionSelector(),
          ],
        ),
      ),
    );
  }

  Widget _kindToggle() {
    return SlidingSegment<AlarmKind>(
      items: const [
        SegmentItem(value: AlarmKind.fixed, label: 'Sabit saat'),
        SegmentItem(value: AlarmKind.anchored, label: 'Vakte göre'),
      ],
      selected: _kind,
      onChanged: (kind) => setState(() => _kind = kind),
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
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(Icons.schedule, color: tokens.accent),
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
            dropdownColor: tokens.backgroundStops[1],
            style: TextStyle(color: tokens.textPrimary),
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
              ? tokens.accent.withValues(alpha: 0.2)
              : tokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? tokens.accent : tokens.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? tokens.accent : tokens.textPrimary,
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
        color: tokens.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.access_time_rounded,
                  color: tokens.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBefore ? 'Vakitten önce' : 'Vakitten sonra',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '1 - $maxOffset dk',
                    style: TextStyle(
                      color: tokens.textSecondary,
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
              // Seçim bandı tekerleğin *üstüne* çizilir; opak bir renk seçili
              // satırı tamamen örter. `surface` açık temada opak beyaz, bu
              // yüzden yatak rengi (mürekkep %5) kullanılıyor.
              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                background: tokens.trackSurface,
              ),
              onSelectedItemChanged: (index) {
                setState(() => _offset = (isBefore ? -1 : 1) * (index + 1));
              },
              children: List.generate(
                maxOffset,
                (i) => Center(
                  child: Text(
                    '${i + 1} dk',
                    style: TextStyle(
                      color: tokens.textPrimary,
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
  bool get _isWeekendOnly =>
      _weekdays.length == 2 && _weekdays.containsAll(const {6, 7});

  Widget _weekdaysSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _quickChip('Her gün', _isEveryDay, () {
              setState(() => _weekdays = {1, 2, 3, 4, 5, 6, 7});
            }),
            _quickChip('Hafta içi', _isWeekdaysOnly, () {
              setState(() => _weekdays = {1, 2, 3, 4, 5});
            }),
            _quickChip('Hafta sonu', _isWeekendOnly, () {
              setState(() => _weekdays = {6, 7});
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
              ? tokens.accent.withValues(alpha: 0.2)
              : tokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? tokens.accent : tokens.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? tokens.accent : tokens.textPrimary,
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
              ? tokens.accent.withValues(alpha: 0.2)
              : tokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? tokens.accent
                : tokens.surface,
          ),
        ),
        child: Text(
          names[day - 1],
          style: TextStyle(
            color: selected ? tokens.accent : tokens.textSecondary,
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
      style: TextStyle(color: tokens.textPrimary),
      decoration: _fieldDecoration('Örn. Sahur'),
    );
  }

  Widget _soundSelector() {
    final isCustom = _soundId.startsWith('custom:');
    return DropdownButtonFormField<String>(
      initialValue: _soundId,
      isExpanded: true,
      dropdownColor: tokens.backgroundStops[1],
      style: TextStyle(color: tokens.textPrimary),
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
        DropdownMenuItem(
          value: _pickSoundValue,
          child: Row(
            children: [
              Icon(Icons.library_music_outlined, size: 18, color: tokens.accent),
              const SizedBox(width: 8),
              const Text('Cihazdan ses seç…'),
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
        dropdownColor: tokens.backgroundStops[1],
        style: TextStyle(color: tokens.textPrimary),
        items: kSnoozeMinuteOptions
            .map((m) => DropdownMenuItem(value: m, child: Text('$m dk')))
            .toList(),
        onChanged: (v) => setState(() => _snoozeMinutes = v ?? 5),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SectionLabel(title), const SizedBox(height: 8), child],
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TextStyle(color: tokens.textPrimary)),
      value: value,
      activeThumbColor: tokens.accent,
      onChanged: onChanged,
    );
  }

  /// Görev seçimi. Bu turda yalnızca matematik açık; sallama ve QR kendi
  /// turlarında listeye eklenecek.
  Widget _missionSelector() {
    const available = [AlarmMission.none, AlarmMission.math];
    const labels = {AlarmMission.none: 'Yok', AlarmMission.math: 'Matematik'};
    return _switchRow(
      'Kapatma görevi',
      DropdownButton<AlarmMission>(
        value: available.contains(_mission) ? _mission : AlarmMission.none,
        dropdownColor: tokens.backgroundStops[1],
        style: TextStyle(color: tokens.textPrimary),
        items: available
            .map(
              (m) => DropdownMenuItem(value: m, child: Text(labels[m] ?? 'Yok')),
            )
            .toList(),
        onChanged: (v) => setState(() {
          _mission = v ?? AlarmMission.none;
          // Gorev acilirsa sinirsiz erteleme kapiyi islevsiz birakir.
          if (_mission.requiresGate && _maxSnoozes == null) {
            _maxSnoozes = kMaxSnoozeOptions.last;
          }
        }),
      ),
    );
  }

  /// Erteleme sayısı. Görev açıkken "Sınırsız" listelenmez.
  Widget _maxSnoozesSelector() {
    final allowUnlimited = !_mission.requiresGate;
    final values = <int?>[...kMaxSnoozeOptions, if (allowUnlimited) null];
    final current = values.contains(_maxSnoozes)
        ? _maxSnoozes
        : kMaxSnoozeOptions.last;
    return _switchRow(
      'Erteleme sayısı',
      DropdownButton<int?>(
        value: current,
        dropdownColor: tokens.backgroundStops[1],
        style: TextStyle(color: tokens.textPrimary),
        items: values
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(v == null ? 'Sınırsız' : '$v kez'),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _maxSnoozes = v),
      ),
    );
  }

  Widget _switchRow(String title, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: tokens.textPrimary)),
          trailing,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: tokens.textTertiary),
      filled: true,
      fillColor: tokens.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
