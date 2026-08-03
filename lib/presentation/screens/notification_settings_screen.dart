import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/models/notification_setting.dart';
import '../../core/models/prayer_time.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../../features/notifications/domain/notification_scheduler.dart';
import '../../core/interfaces/notification_service.dart';
import '../../core/services/exact_alarm_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/providers/app_state.dart';
import 'package:provider/provider.dart';
import '../utils/prayer_name_helper.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/grouped_list.dart';
import '../widgets/common/info_banner.dart';
import '../widgets/common/section_label.dart';
import '../widgets/common/swipe_to_delete.dart';
import '../widgets/common/state_widgets.dart';
import '../widgets/notifications/permission_warning_card.dart';
import '../widgets/notifications/notification_tile.dart';
import '../widgets/notifications/add_notification_bottom_sheet.dart';

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

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  late final NotificationSettingsManager _manager;
  late final NotificationService _notificationService;
  late final ExactAlarmService _exactAlarmService;
  List<NotificationSetting> _settings = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _exactAlarmAllowed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _manager = ServiceLocator().get<NotificationSettingsManager>();
    _notificationService = ServiceLocator().get<NotificationService>();
    _exactAlarmService = ServiceLocator().get<ExactAlarmService>();
    _hasPermission = widget.hasPermission;
    _loadSettings();
    _checkExactAlarm();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı sistem ayarlarından dönünce izin/exact alarm durumunu tazele.
    if (state == AppLifecycleState.resumed) {
      _checkExactAlarm();
      _refreshPermission();
    }
  }

  Future<void> _checkExactAlarm() async {
    final allowed = await _exactAlarmService.isExactAlarmAllowed();
    if (mounted) setState(() => _exactAlarmAllowed = allowed);
  }

  Future<void> _refreshPermission() async {
    final granted = await _notificationService.isPermissionGranted();
    if (mounted) setState(() => _hasPermission = granted);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      await _rescheduleNotifications();
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
      await _rescheduleNotifications();
      _showSnackBar('Bildirim silindi');
    } catch (e) {
      _showSnackBar('Bildirim silinemedi: $e', isError: true);
    }
  }

  Future<void> _updateNotification(
    NotificationSetting original,
    PrayerType prayerType,
    int minutesBefore,
  ) async {
    try {
      final duplicateExists = _settings.any(
        (s) =>
            s.prayerType == prayerType &&
            s.minutesBefore == minutesBefore &&
            !(s.prayerType == original.prayerType &&
                s.minutesBefore == original.minutesBefore),
      );

      if (duplicateExists) {
        _showSnackBar('Bu bildirim zaten mevcut', isError: true);
        return;
      }

      final updated = original.copyWith(
        prayerType: prayerType,
        minutesBefore: minutesBefore,
      );

      final keyChanged =
          prayerType != original.prayerType ||
          minutesBefore != original.minutesBefore;

      if (keyChanged) {
        await _manager.removeSetting(
          prayerType: original.prayerType,
          minutesBefore: original.minutesBefore,
        );
        await _manager.addSetting(updated);
      } else {
        await _manager.updateSetting(updated);
      }

      await _loadSettings();
      await _rescheduleNotifications();
      _showSnackBar('Bildirim güncellendi');
    } catch (e) {
      _showSnackBar('Bildirim güncellenemedi: $e', isError: true);
    }
  }

  Future<void> _toggleNotification(NotificationSetting setting) async {
    try {
      await _manager.updateSetting(
        setting.copyWith(isActive: !setting.isActive),
      );
      await _loadSettings();
      await _rescheduleNotifications();
    } catch (e) {
      _showSnackBar('Bildirim güncellenemedi: $e', isError: true);
    }
  }

  Future<void> _rescheduleNotifications() async {
    try {
      final appState = context.read<AppState>();
      final location = appState.activeLocation;
      final prayerTimes = appState.prayerTimes;

      if (location != null && prayerTimes.isNotEmpty) {
        final scheduler = ServiceLocator().get<NotificationScheduler>();
        await scheduler.scheduleNotifications(
          location: location,
          prayerTimes: prayerTimes,
        );
      } else {
        // Vakit verisi yokken yeniden planlayamayız; yine de silinen/kapatılan
        // bildirimlerin eski OS kopyaları tetiklenmesin diye hepsini iptal et.
        // Aktif ayarlar bir sonraki veri yüklemesinde yeniden planlanır.
        await ServiceLocator()
            .get<NotificationService>()
            .cancelAllNotifications();
      }
    } catch (e) {
      _showSnackBar('Bildirimler güncellenemedi: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      // Onceki snackbar'i hemen kaldir; yeni islem mesaji beklemeden gosterilsin.
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : context.tokens.accent,
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

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddNotificationBottomSheet(
        onAdd: _addNotification,
        prayerTime: widget.prayerTime,
      ),
    );
  }

  void _showEditDialog(NotificationSetting setting) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AddNotificationBottomSheet(
        prayerTime: widget.prayerTime,
        initialSetting: setting,
        submitLabel: 'Güncelle',
        title: 'Bildirimi Güncelle',
        onAdd: (prayerType, minutesBefore) =>
            _updateNotification(setting, prayerType, minutesBefore),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: 'Bildirimler',
        // Tasarimda ekleme eylemi app bar'in saginda; FAB son satiri ortuyordu.
        actions: [
          AppBarActionButton(
            key: const Key('add_notification_button'),
            icon: Icons.add_rounded,
            onTap: _showAddDialog,
            tooltip: 'Bildirim ekle',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppSurface(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              if (!_hasPermission)
                PermissionWarningCard(
                  onRequestPermission: widget.onRequestPermission,
                  onOpenAppSettings: widget.onOpenAppSettings,
                  onPermissionGranted: (granted) {
                    if (mounted) {
                      setState(() => _hasPermission = granted);
                      if (granted) _showSnackBar('Bildirim izni verildi');
                    }
                  },
                ),
              if (_hasPermission && !_exactAlarmAllowed) ...[
                InfoBanner(
                  icon: Icons.alarm_off_rounded,
                  text: 'Tam zamanlı alarm kapalı. Bildirimler gecikebilir.',
                  action: TextButton(
                    onPressed: _notificationService.openExactAlarmSettings,
                    child: const Text('Aç'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingState();

    if (_settings.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        message: 'Henüz bildirim yok',
        subtitle: 'Namaz vakitlerinde hatırlatma almak için\nbildirim ekleyin.',
      );
    }

    final tokens = context.tokens;
    final sorted = _sortedSettings();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text(
          'Her vakit için tam vaktinde veya X dakika önce hatırlatma '
          'alabilirsiniz.',
          style: AppTypography.hint.copyWith(
            color: tokens.textTertiary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        SectionLabel('${sorted.length} hatırlatma'),
        const SizedBox(height: 10),
        GroupedList(
          children: [
            for (final setting in sorted)
              SwipeToDelete(
                itemKey: ValueKey(
                  '${setting.prayerType.name}-${setting.minutesBefore}',
                ),
                confirmText:
                    '${PrayerNameHelper.getName(setting.prayerType)} '
                    'bildirimini silmek istiyor musunuz?',
                onDelete: () => _deleteNotification(
                  setting.prayerType,
                  setting.minutesBefore,
                ),
                child: NotificationTile(
                  setting: setting,
                  hasPermission: _hasPermission,
                  onToggle: () => _toggleNotification(setting),
                  onTap: () => _showEditDialog(setting),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Silmek için satırı sola kaydırın.',
          style: AppTypography.hint.copyWith(color: tokens.textTertiary),
        ),
      ],
    );
  }
}

