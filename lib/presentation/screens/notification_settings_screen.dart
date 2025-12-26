import 'package:flutter/material.dart';
import '../../core/models/notification_setting.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final List<NotificationSetting> settings;
  final bool hasPermission;
  final Function(NotificationSetting) onSettingToggled;
  final Function(PrayerType, int) onOffsetChanged;
  final Future<bool> Function()? onRequestPermission;
  final VoidCallback? onOpenAppSettings;

  const NotificationSettingsScreen({
    super.key,
    required this.settings,
    required this.hasPermission,
    required this.onSettingToggled,
    required this.onOffsetChanged,
    this.onRequestPermission,
    this.onOpenAppSettings,
  });

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late bool _hasPermission;

  @override
  void initState() {
    super.initState();
    _hasPermission = widget.hasPermission;
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

  Map<PrayerType, List<NotificationSetting>> _groupByPrayer() {
    final grouped = <PrayerType, List<NotificationSetting>>{};

    for (final setting in widget.settings) {
      if (!grouped.containsKey(setting.prayerType)) {
        grouped[setting.prayerType] = [];
      }
      grouped[setting.prayerType]!.add(setting);
    }

    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.minutesBefore.compareTo(b.minutesBefore));
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByPrayer();
    final prayers = [
      PrayerType.fajr,
      PrayerType.sunrise,
      PrayerType.dhuhr,
      PrayerType.asr,
      PrayerType.maghrib,
      PrayerType.isha,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim Ayarları')),
      body: Column(
        children: [
          if (!_hasPermission) _buildPermissionWarning(context),
          Expanded(
            child: ListView(
              children: prayers.map((prayer) {
                final prayerSettings = grouped[prayer] ?? [];
                return _buildPrayerSection(prayer, prayerSettings);
              }).toList(),
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

  Widget _buildPrayerSection(
    PrayerType prayer,
    List<NotificationSetting> prayerSettings,
  ) {
    return Card(
      key: Key('prayer_section_${prayer.name}'),
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _getPrayerName(prayer),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          if (prayerSettings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Bildirim ayarı yok',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...prayerSettings.map((setting) {
              return ListTile(
                key: Key('setting_${prayer.name}_${setting.minutesBefore}'),
                title: Text(
                  setting.minutesBefore == 0
                      ? 'Vaktinde'
                      : '${setting.minutesBefore} dakika önce',
                ),
                trailing: Switch(
                  key: Key('switch_${prayer.name}_${setting.minutesBefore}'),
                  value: setting.isActive && _hasPermission,
                  onChanged: _hasPermission
                      ? (value) => widget.onSettingToggled(
                          setting.copyWith(isActive: value),
                        )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }

  void _showAddNotificationDialog(BuildContext context) {
    PrayerType? selectedPrayer;
    int selectedOffset = 0;

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
              DropdownButtonFormField<int>(
                key: const Key('offset_dropdown'),
                value: selectedOffset,
                decoration: const InputDecoration(
                  labelText: 'Bildirim Zamanı',
                  border: OutlineInputBorder(),
                ),
                items: [0, 5, 10, 15, 30, 60].map((offset) {
                  return DropdownMenuItem(
                    value: offset,
                    child: Text(
                      offset == 0 ? 'Vaktinde' : '$offset dakika önce',
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedOffset = value ?? 0;
                  });
                },
              ),
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
                  : () {
                      widget.onOffsetChanged(selectedPrayer!, selectedOffset);
                      Navigator.of(context).pop();
                    },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
