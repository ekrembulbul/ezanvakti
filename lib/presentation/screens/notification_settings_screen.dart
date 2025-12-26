import 'package:flutter/material.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../core/di/service_locator.dart';
import '../widgets/permission_warning_card.dart';
import '../widgets/notification_setting_tile.dart';
import '../widgets/add_notification_dialog.dart';
import '../utils/prayer_name_helper.dart';

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

  @override
  Widget build(BuildContext context) {
    final sortedSettings = _sorted(_settings);
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim Ayarları')),
      body: Column(
        children: [
          if (!_hasPermission)
            PermissionWarningCard(
              onRequestPermission: widget.onRequestPermission,
              onOpenAppSettings: widget.onOpenAppSettings,
              onPermissionGranted: (granted) {
                if (granted && mounted) {
                  setState(() {
                    _hasPermission = true;
                  });
                }
              },
            ),
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
                      return NotificationSettingTile(
                        setting: setting,
                        hasPermission: _hasPermission,
                        onToggled: (updatedSetting) async {
                          await widget.onSettingToggled(updatedSetting);
                          await _refreshFromStorage();
                        },
                        onDelete: widget.onDeleteSetting != null
                            ? () async {
                                await widget.onDeleteSetting!(
                                  setting.prayerType,
                                  setting.minutesBefore,
                                );
                                await _refreshFromStorage();
                              }
                            : null,
                      );
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

  void _showAddNotificationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AddNotificationDialog(
        prayerTime: widget.prayerTime,
        onAdd: (prayer, offset) async {
          await widget.onOffsetChanged(prayer, offset);
          await _refreshFromStorage();
        },
      ),
    );
  }

  List<NotificationSetting> _sorted(List<NotificationSetting> items) {
    final sorted = [...items]
      ..sort((a, b) {
        final o = PrayerNameHelper.getPrayerOrder(
          a.prayerType,
        ).compareTo(PrayerNameHelper.getPrayerOrder(b.prayerType));
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
}
