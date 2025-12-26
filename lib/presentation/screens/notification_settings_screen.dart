import 'package:flutter/material.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../core/di/service_locator.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final List<NotificationSetting> settings;
  final bool hasPermission;
  final Future<void> Function(NotificationSetting) onSettingToggled;
  final Future<void> Function(PrayerType, int) onOffsetChanged;
  final Future<bool> Function()? onRequestPermission;
  final VoidCallback? onOpenAppSettings;
  final PrayerTime? prayerTime;
  final Future<void> Function(PrayerType, int)? onDeleteSetting;

  const NotificationSettingsScreen({
    super.key,
    required this.settings,
    required this.hasPermission,
    required this.onSettingToggled,
    required this.onOffsetChanged,
    this.onRequestPermission,
    this.onOpenAppSettings,
    this.prayerTime,
    this.onDeleteSetting,
  });

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late bool _hasPermission;
  late List<NotificationSetting> _settings;
  late final NotificationSettingsManager _manager;

  @override
  void initState() {
    super.initState();
    _hasPermission = widget.hasPermission;
    _settings = [...widget.settings];
    _manager = ServiceLocator().get<NotificationSettingsManager>();
  }

  @override
  void didUpdateWidget(covariant NotificationSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasPermission != widget.hasPermission) {
      _hasPermission = widget.hasPermission;
    }
    if (oldWidget.settings != widget.settings) {
      _settings = [...widget.settings];
    }
  }

  String _getPrayerName(PrayerType type) {
    switch (type) {
      case PrayerType.fajr:
        return 'İmsak';
      case PrayerType.sunrise:
        return 'Güneş';
      case PrayerType.dhuhr:
        return 'Öğle';
      case PrayerType.asr:
        return 'İkindi';
      case PrayerType.maghrib:
        return 'Akşam';
      case PrayerType.isha:
        return 'Yatsı';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedSettings = _sorted(_settings);
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim Ayarları')),
      body: Column(
        children: [
          if (!_hasPermission) _buildPermissionWarning(context),
          Expanded(
            child: sortedSettings.isEmpty
                ? const Center(
                    child: Text(
                      'Henüz eklenmiş bildirim yok',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: sortedSettings.length,
                    itemBuilder: (context, index) {
                      final setting = sortedSettings[index];
                      return _buildSettingTile(setting);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_notification_button'),
        onPressed: () => _showAddNotificationDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPermissionWarning(BuildContext context) {
    return Container(
      key: const Key('permission_warning'),
      color: Colors.orange.shade100,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'Bildirim izni verilmedi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Bildirim almak için izin vermeniz gerekmektedir.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onRequestPermission != null)
                TextButton(
                  key: const Key('request_permission_button'),
                  onPressed: () async {
                    final granted = await widget.onRequestPermission!.call();
                    if (granted && mounted) {
                      setState(() {
                        _hasPermission = true;
                      });
                    }
                  },
                  child: const Text('İzin Ver'),
                ),
              if (widget.onOpenAppSettings != null)
                TextButton(
                  key: const Key('open_settings_button'),
                  onPressed: widget.onOpenAppSettings,
                  child: const Text('Ayarlara Git'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(NotificationSetting setting) {
    final isAtTime = setting.minutesBefore == 0;
    final label = isAtTime
        ? '${_getPrayerName(setting.prayerType)} • Vaktinde'
        : '${_getPrayerName(setting.prayerType)} • ${setting.minutesBefore} dk önce';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        key: Key('setting_${setting.prayerType.name}_${setting.minutesBefore}'),
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              key: Key(
                'switch_${setting.prayerType.name}_${setting.minutesBefore}',
              ),
              value: setting.isActive && _hasPermission,
              onChanged: _hasPermission
                  ? (value) async {
                      await widget.onSettingToggled(
                        setting.copyWith(isActive: value),
                      );
                      await _refreshFromStorage();
                    }
                  : null,
            ),
            if (widget.onDeleteSetting != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Sil',
                onPressed: () async {
                  await widget.onDeleteSetting!(
                    setting.prayerType,
                    setting.minutesBefore,
                  );
                  await _refreshFromStorage();
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAddNotificationDialog(BuildContext context) {
    PrayerType? selectedPrayer;
    bool isBefore = false;
    int selectedOffset = 5;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Bildirim Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<PrayerType>(
                key: const Key('prayer_dropdown'),
                value: selectedPrayer,
                decoration: const InputDecoration(
                  labelText: 'Vakit',
                  border: OutlineInputBorder(),
                ),
                items:
                    [
                      PrayerType.fajr,
                      PrayerType.sunrise,
                      PrayerType.dhuhr,
                      PrayerType.asr,
                      PrayerType.maghrib,
                      PrayerType.isha,
                    ].map((prayer) {
                      return DropdownMenuItem(
                        value: prayer,
                        child: Text(_getPrayerName(prayer)),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPrayer = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Vaktinde'),
                      selected: !isBefore,
                      onSelected: (_) {
                        setState(() {
                          isBefore = false;
                          selectedOffset = 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Vakitten önce'),
                      selected: isBefore,
                      onSelected: (_) {
                        setState(() {
                          isBefore = true;
                          if (selectedOffset == 0) {
                            selectedOffset = 5;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (isBefore) ...[
                const SizedBox(height: 12),
                _OffsetPicker(
                  maxOffset: _maxOffsetFor(selectedPrayer),
                  value: selectedOffset,
                  onChanged: (value) {
                    setState(() {
                      selectedOffset = value;
                    });
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              key: const Key('cancel_button'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              key: const Key('save_button'),
              onPressed: selectedPrayer == null
                  ? null
                  : () async {
                      final maxOffset = _maxOffsetFor(selectedPrayer);
                      if (isBefore &&
                          maxOffset != null &&
                          selectedOffset > maxOffset) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Bu vakitten en fazla $maxOffset dk önce bildirim ekleyebilirsin.',
                            ),
                          ),
                        );
                        return;
                      }
                      await widget.onOffsetChanged(
                        selectedPrayer!,
                        isBefore ? selectedOffset : 0,
                      );
                      await _refreshFromStorage();
                      Navigator.of(context).pop();
                    },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  List<NotificationSetting> _sorted(List<NotificationSetting> items) {
    final sorted = [...items]
      ..sort((a, b) {
        final order = {
          PrayerType.fajr: 0,
          PrayerType.sunrise: 1,
          PrayerType.dhuhr: 2,
          PrayerType.asr: 3,
          PrayerType.maghrib: 4,
          PrayerType.isha: 5,
        };
        final o = order[a.prayerType]!.compareTo(order[b.prayerType]!);
        if (o != 0) return o;
        return a.minutesBefore.compareTo(b.minutesBefore);
      });
    return sorted;
  }

  Future<void> _refreshFromStorage() async {
    final latest = await _manager.getSettings();
    if (!mounted) return;
    setState(() {
      _settings = latest;
    });
  }

  int? _maxOffsetFor(PrayerType? prayer) {
    if (prayer == null || widget.prayerTime == null) return null;
    final previous = _previousPrayer(prayer);
    if (previous == null) return null;

    final currentTime = _timeFor(prayer);
    final previousTime = _timeFor(previous);
    if (currentTime == null || previousTime == null) return null;

    final diff = currentTime.difference(previousTime).inMinutes;
    final maxOffset = diff - 1;
    return maxOffset < 1 ? 1 : maxOffset;
  }

  PrayerType? _previousPrayer(PrayerType prayer) {
    switch (prayer) {
      case PrayerType.fajr:
        return null;
      case PrayerType.sunrise:
        return PrayerType.fajr;
      case PrayerType.dhuhr:
        return PrayerType.sunrise;
      case PrayerType.asr:
        return PrayerType.dhuhr;
      case PrayerType.maghrib:
        return PrayerType.asr;
      case PrayerType.isha:
        return PrayerType.maghrib;
    }
  }

  DateTime? _timeFor(PrayerType prayer) {
    final pt = widget.prayerTime;
    if (pt == null) return null;
    switch (prayer) {
      case PrayerType.fajr:
        return pt.fajr;
      case PrayerType.sunrise:
        return pt.sunrise;
      case PrayerType.dhuhr:
        return pt.dhuhr;
      case PrayerType.asr:
        return pt.asr;
      case PrayerType.maghrib:
        return pt.maghrib;
      case PrayerType.isha:
        return pt.isha;
    }
  }
}

class _OffsetPicker extends StatelessWidget {
  final int value;
  final int? maxOffset;
  final ValueChanged<int> onChanged;

  const _OffsetPicker({
    required this.value,
    required this.onChanged,
    this.maxOffset,
  });

  @override
  Widget build(BuildContext context) {
    final max = (maxOffset ?? 120).clamp(1, 240);
    final displayValue = value.clamp(1, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Dakika'), Text('$displayValue dk önce')],
        ),
        Slider(
          value: displayValue.toDouble(),
          min: 1,
          max: max.toDouble(),
          divisions: max,
          label: '$displayValue',
          onChanged: (v) => onChanged(v.round()),
        ),
        Text(
          maxOffset == null
              ? 'Önerilen aralık: 1-${max} dk'
              : 'En fazla $maxOffset dk önce',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }
}
