import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../core/utils/prayer_utils.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../core/di/service_locator.dart';
import '../utils/prayer_name_helper.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/state_widgets.dart';
import '../widgets/notifications/notification_widgets.dart';

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
      setState(() => _hasPermission = widget.hasPermission);
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
        _showSnackBar('Ayarlar yüklenemedi: $e', isError: true);
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
        _showSnackBar('Bu bildirim zaten mevcut', isError: true);
        return;
      }

      await _manager.addSetting(newSetting);
      await _loadSettings();
      _showSnackBar('Bildirim eklendi');
    } catch (e) {
      _showSnackBar('Bildirim eklenemedi: $e', isError: true);
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
      _showSnackBar('Bildirim silindi');
    } catch (e) {
      _showSnackBar('Bildirim silinemedi: $e', isError: true);
    }
  }

  Future<void> _toggleNotification(NotificationSetting setting) async {
    try {
      await _manager.updateSetting(
        setting.copyWith(isActive: !setting.isActive),
      );
      await _loadSettings();
    } catch (e) {
      _showSnackBar('Bildirim güncellenemedi: $e', isError: true);
    }
  }

  Future<void> _requestPermission() async {
    if (widget.onRequestPermission != null) {
      final granted = await widget.onRequestPermission!();
      if (mounted) {
        setState(() => _hasPermission = granted);
        if (granted) _showSnackBar('Bildirim izni verildi');
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : AppTheme.gold,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
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

  Future<bool> _confirmDelete(NotificationSetting setting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.primaryMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Bildirimi Sil',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${PrayerUtils.getPrayerName(setting.prayerType)} bildirimi silinsin mi?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteNotification(setting.prayerType, setting.minutesBefore);
    }
    return false;
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddNotificationBottomSheet(onAdd: _addNotification),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const SimpleAppBar(title: 'Bildirimler'),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.nightGradient),
        child: SafeArea(
          child: Column(
            children: [
              if (!_hasPermission)
                PermissionWarningCard(onRequestPermission: _requestPermission),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_notification_button'),
        onPressed: _showAddDialog,
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.primaryDark,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Bildirim Ekle',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }

    if (_settings.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        message: 'Henüz bildirim yok',
        subtitle: 'Namaz vakitlerinde hatırlatma almak için\nbildirim ekleyin.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSettings,
      color: AppTheme.gold,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _sortedSettings().length,
        itemBuilder: (context, index) {
          final setting = _sortedSettings()[index];
          return NotificationTile(
            setting: setting,
            hasPermission: _hasPermission,
            onToggle: () => _toggleNotification(setting),
            onDismiss: () => _confirmDelete(setting),
          );
        },
      ),
    );
  }
}
