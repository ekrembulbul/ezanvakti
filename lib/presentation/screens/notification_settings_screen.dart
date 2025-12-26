import 'package:flutter/material.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../core/di/service_locator.dart';
import '../utils/prayer_name_helper.dart';
import '../widgets/add_notification_dialog.dart';
import '../widgets/notification_setting_tile.dart';
import '../widgets/notification_permission_warning.dart';
import '../widgets/notification_empty_state.dart';
import '../widgets/delete_notification_dialog.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final bool hasPermission;
  final Future<bool> Function()? onRequestPermission;
  final VoidCallback? onOpenAppSettings;
  final PrayerTime? prayerTime;

  const NotificationSettingsScreen({
    super.key,
    required this.hasPermission,
    this.onRequestPermission,
    this.onOpenAppSettings,
    this.prayerTime,
    List<NotificationSetting>? settings,
    Future<void> Function(NotificationSetting)? onSettingToggled,
    Future<void> Function(PrayerType, int)? onOffsetChanged,
    Future<void> Function(PrayerType, int)? onDeleteSetting,
  });

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late final NotificationSettingsManager _manager;
  List<NotificationSetting> _settings = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _manager = ServiceLocator().get<NotificationSettingsManager>();
    _hasPermission = widget.hasPermission;
    _loadSettings();
  }

  @override
  void didUpdateWidget(NotificationSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hasPermission != widget.hasPermission) {
      setState(() {
        _hasPermission = widget.hasPermission;
      });
    }
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _manager.getSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ayarlar yüklenemedi: $e')));
      }
    }
  }

  Future<void> _addNotification(
    PrayerType prayerType,
    int minutesBefore,
  ) async {
    try {
      final newSetting = NotificationSetting(
        prayerType: prayerType,
        isActive: true,
        minutesBefore: minutesBefore,
      );

      final exists = _settings.any(
        (s) => s.prayerType == prayerType && s.minutesBefore == minutesBefore,
      );

      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu bildirim zaten mevcut')),
          );
        }
        return;
      }

      await _manager.addSetting(newSetting);
      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bildirim eklendi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bildirim eklenemedi: $e')));
      }
    }
  }

  Future<void> _deleteNotification(
    PrayerType prayerType,
    int minutesBefore,
  ) async {
    try {
      await _manager.removeSetting(
        prayerType: prayerType,
        minutesBefore: minutesBefore,
      );
      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bildirim silindi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bildirim silinemedi: $e')));
      }
    }
  }

  Future<void> _toggleNotification(NotificationSetting setting) async {
    try {
      await _manager.updateSetting(
        setting.copyWith(isActive: !setting.isActive),
      );
      await _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bildirim güncellenemedi: $e')));
      }
    }
  }

  Future<void> _requestPermission() async {
    if (widget.onRequestPermission != null) {
      final granted = await widget.onRequestPermission!();
      if (mounted) {
        setState(() {
          _hasPermission = granted;
        });
        if (granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bildirim izni verildi')),
          );
        }
      }
    }
  }

  List<NotificationSetting> _sortedSettings() {
    final sorted = [..._settings];
    sorted.sort((a, b) {
      final orderCompare = PrayerNameHelper.getPrayerOrder(
        a.prayerType,
      ).compareTo(PrayerNameHelper.getPrayerOrder(b.prayerType));
      if (orderCompare != 0) return orderCompare;
      return a.minutesBefore.compareTo(b.minutesBefore);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Ayarları'),
        actions: [
          if (!_hasPermission)
            IconButton(
              icon: const Icon(Icons.notifications_off),
              onPressed: _requestPermission,
              tooltip: 'Bildirim izni iste',
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_hasPermission)
            NotificationPermissionWarning(
              onRequestPermission: _requestPermission,
              onOpenAppSettings: widget.onOpenAppSettings,
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _settings.isEmpty
                ? const NotificationEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadSettings,
                    child: ListView.builder(
                      itemCount: _sortedSettings().length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final setting = _sortedSettings()[index];
                        return NotificationSettingTile(
                          setting: setting,
                          hasPermission: _hasPermission,
                          onToggle: () => _toggleNotification(setting),
                          onDelete: () => _confirmDelete(setting),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_notification_button'),
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
        tooltip: 'Bildirim Ekle',
      ),
    );
  }

  Future<void> _confirmDelete(NotificationSetting setting) async {
    final confirmed = await DeleteNotificationDialog.show(context, setting);
    if (confirmed) {
      await _deleteNotification(setting.prayerType, setting.minutesBefore);
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AddNotificationDialog(
        prayerTime: widget.prayerTime,
        onAdd: (prayerType, minutesBefore) async {
          await _addNotification(prayerType, minutesBefore);
        },
      ),
    );
  }
}
