import '../../core/models/prayer_time.dart';
import '../../core/models/skipped_occurrence.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
import '../../features/notifications/domain/skip_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/interfaces/alarm_service.dart';
import '../../core/interfaces/notification_service.dart';
import '../../core/models/alarm.dart';
import '../../core/models/notification_setting.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/exact_alarm_service.dart';
import '../../core/theme/tokens_context.dart';
import '../../features/alarms/domain/alarms_manager.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../services/reminder_rescheduler.dart';
import '../utils/alarm_labels.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/sliding_segment.dart';
import '../widgets/notifications/add_notification_bottom_sheet.dart';
import '../widgets/reminders/alarms_section.dart';
import '../widgets/reminders/notifications_section.dart';
import 'alarm_edit_screen.dart';

enum ReminderTab { notifications, alarms }

/// Bildirimler ve alarmların tek ekranda birleşmiş hali.
///
/// Listeler `AppState`'te tutulur; bu ekran yalnızca mutasyonu sahiplenir.
/// İzin durumu ekran ömrüne bağlı olduğu için burada kalır.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with WidgetsBindingObserver {
  late final NotificationSettingsManager _settingsManager;
  late final NotificationService _notificationService;
  late final ExactAlarmService _exactAlarmService;
  late final AlarmsManager _alarmsManager;
  late final AlarmService _alarmService;
  late final ReminderRescheduler _rescheduler;

  ReminderTab _tab = ReminderTab.notifications;
  bool _hasPermission = false;
  bool _exactAlarmAllowed = true;
  bool _alarmSupported = true;
  bool _alarmGranted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final locator = ServiceLocator();
    _settingsManager = locator.get<NotificationSettingsManager>();
    _notificationService = locator.get<NotificationService>();
    _exactAlarmService = locator.get<ExactAlarmService>();
    _alarmsManager = locator.get<AlarmsManager>();
    _alarmService = locator.get<AlarmService>();
    _rescheduler = locator.get<ReminderRescheduler>();
    _hasPermission = context.read<AppState>().hasNotificationPermission;
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı sistem ayarlarından dönünce izin durumunu tazele.
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final hasPermission = await _notificationService.isPermissionGranted();
    final exactAllowed = await _exactAlarmService.isExactAlarmAllowed();
    final supported = await _alarmService.isSupported();
    final granted = supported
        ? await _alarmService.isPermissionGranted()
        : false;

    if (!mounted) return;
    setState(() {
      _hasPermission = hasPermission;
      _exactAlarmAllowed = exactAllowed;
      _alarmSupported = supported;
      _alarmGranted = granted;
    });
  }

  /// Planlamayı tazeler. Vakit verisi yoksa planlanamaz; silinen/kapatılan
  /// kaydın eski OS kopyası tetiklenmesin diye hepsi iptal edilir. Aktif
  /// ayarlar bir sonraki veri yüklemesinde yeniden planlanır.
  Future<void> _reschedule(AppState appState) async {
    final rescheduled = await _rescheduler.reschedule(
      location: appState.activeLocation,
      prayerTimes: appState.prayerTimes,
      skips: appState.skips,
    );
    if (!rescheduled) await _notificationService.cancelAllNotifications();
  }

  Future<void> _syncNotifications(AppState appState) async {
    appState.setNotificationSettings(await _settingsManager.getSettings());
    await _reschedule(appState);
  }

  Future<void> _syncAlarms(AppState appState) async {
    appState.setAlarms(await _alarmsManager.getAlarms());
    await _reschedule(appState);
  }

  // --- Bildirim mutasyonları ---

  Future<void> _addNotification(PrayerType type, int minutesBefore) async {
    final appState = context.read<AppState>();
    final exists = appState.notificationSettings.any(
      (s) => s.prayerType == type && s.minutesBefore == minutesBefore,
    );
    if (exists) {
      _snack('Bu bildirim zaten mevcut', isError: true);
      return;
    }

    await _settingsManager.addSetting(
      NotificationSetting(
        prayerType: type,
        isActive: true,
        minutesBefore: minutesBefore,
      ),
    );
    await _syncNotifications(appState);
    _snack('Bildirim eklendi');
  }

  Future<void> _updateNotification(
    NotificationSetting original,
    PrayerType type,
    int minutesBefore,
  ) async {
    final appState = context.read<AppState>();
    final duplicate = appState.notificationSettings.any(
      (s) =>
          s.prayerType == type &&
          s.minutesBefore == minutesBefore &&
          !(s.prayerType == original.prayerType &&
              s.minutesBefore == original.minutesBefore),
    );
    if (duplicate) {
      _snack('Bu bildirim zaten mevcut', isError: true);
      return;
    }

    final updated = original.copyWith(
      prayerType: type,
      minutesBefore: minutesBefore,
    );
    final keyChanged =
        type != original.prayerType || minutesBefore != original.minutesBefore;

    if (keyChanged) {
      await _settingsManager.removeSetting(
        prayerType: original.prayerType,
        minutesBefore: original.minutesBefore,
      );
      await _settingsManager.addSetting(updated);
    } else {
      await _settingsManager.updateSetting(updated);
    }

    await _syncNotifications(appState);
    _snack('Bildirim güncellendi');
  }

  Future<void> _deleteNotification(NotificationSetting setting) async {
    final appState = context.read<AppState>();
    await _settingsManager.removeSetting(
      prayerType: setting.prayerType,
      minutesBefore: setting.minutesBefore,
    );
    await _syncNotifications(appState);
    _snack('Bildirim silindi');
  }

  Future<void> _toggleNotification(NotificationSetting setting) async {
    final appState = context.read<AppState>();
    await _settingsManager.updateSetting(
      setting.copyWith(isActive: !setting.isActive),
    );
    await _syncNotifications(appState);
  }

  // --- Alarm mutasyonları ---

  Future<void> _ensureAlarmPermission() async {
    if (!await _alarmService.isSupported()) return;
    if (!await _alarmService.isPermissionGranted()) {
      await _alarmService.requestPermission();
    }
    await _refreshPermissions();
  }

  Future<void> _addOrEditAlarm([Alarm? existing]) async {
    final appState = context.read<AppState>();
    final result = await Navigator.of(context).push<Alarm>(
      MaterialPageRoute(builder: (_) => AlarmEditScreen(alarm: existing)),
    );
    if (result == null) return;

    await _ensureAlarmPermission();
    await _alarmsManager.save(result);
    await _syncAlarms(appState);
  }

  /// Her alarmın bir sonraki çalma anı. Atlama **uygulanmadan** hesaplanır:
  /// kullanıcı tam da bu örneği atlamak/geri almak istiyor.
  Map<String, DateTime> _nextFireByAlarm(AppState appState) {
    final byDate = <DateTime, PrayerTime>{
      for (final pt in appState.prayerTimes)
        DateTime(pt.date.year, pt.date.month, pt.date.day): pt,
    };
    final now = DateTime.now();
    final result = <String, DateTime>{};
    for (final alarm in appState.alarms) {
      final fire = AlarmScheduler.computeNextFire(
        alarm: alarm,
        now: now,
        prayerTimesByDate: byDate,
      );
      if (fire != null) result[alarm.id] = fire;
    }
    return result;
  }

  /// Tek seferlik atlama. Kalıcı kapatma satırdaki anahtarda kalır.
  Future<void> _toggleSkip(SkippedOccurrence occurrence, bool skipped) async {
    final appState = context.read<AppState>();
    final manager = ServiceLocator().get<SkipManager>();
    final next = skipped
        ? await manager.skip(occurrence)
        : await manager.unskip(occurrence);
    appState.setSkips(next);
    await _syncAlarms(appState);
  }

  /// Ertelenmiş görevli alarm kapatılmak istendi. Kapatmak, görevi yapmadan
  /// alarmdan kurtulmanın arka kapısı olurdu.
  void _onDisableBlocked(Alarm alarm) {
    _snack(
      'Bu alarm ertelendi ve görevi bekliyor; '
      'görevi yapmadan kapatılamaz.',
    );
  }

  Future<void> _toggleAlarm(Alarm alarm, bool isActive) async {
    final appState = context.read<AppState>();
    await _alarmsManager.setActive(alarm, isActive);
    await _syncAlarms(appState);
  }

  Future<void> _deleteAlarm(Alarm alarm) async {
    final appState = context.read<AppState>();
    await _alarmsManager.delete(alarm.id);
    await _syncAlarms(appState);
    _snack('${alarmTimeLabel(alarm)} alarmı silindi');
  }

  // --- Ekleme düğmesi ---

  /// Seçili segmentin tipini ekler; tip sormaz çünkü segment zaten bağlamı
  /// veriyor.
  void _add() {
    if (_tab == ReminderTab.alarms) {
      _addOrEditAlarm();
      return;
    }
    _showNotificationSheet();
  }

  void _showNotificationSheet({NotificationSetting? initial}) {
    final appState = context.read<AppState>();
    final prayerTime =
        appState.todaysPrayerTime ??
        (appState.prayerTimes.isNotEmpty ? appState.prayerTimes.first : null);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AddNotificationBottomSheet(
        prayerTime: prayerTime,
        initialSetting: initial,
        submitLabel: initial == null ? null : 'Güncelle',
        title: initial == null ? null : 'Bildirimi Güncelle',
        onAdd: (type, minutes) => initial == null
            ? _addNotification(type, minutes)
            : _updateNotification(initial, type, minutes),
      ),
    );
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    // Onceki snackbar'i hemen kaldir; yeni islem mesaji beklemeden gosterilsin.
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : context.tokens.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: SimpleAppBar(
        title: 'Hatırlatıcılar',
        showBack: false,
        // Tasarimda ekleme eylemi app bar'in saginda; FAB son satiri ortuyordu.
        actions: [
          AppBarActionButton(
            key: const Key('add_reminder_button'),
            icon: Icons.add_rounded,
            onTap: _add,
            tooltip: _tab == ReminderTab.alarms ? 'Alarm ekle' : 'Bildirim ekle',
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
              const SizedBox(height: 8),
              SlidingSegment<ReminderTab>(
                items: const [
                  SegmentItem(
                    value: ReminderTab.notifications,
                    label: 'Bildirimler',
                    icon: Icons.notifications_rounded,
                  ),
                  SegmentItem(
                    value: ReminderTab.alarms,
                    label: 'Alarmlar',
                    icon: Icons.alarm_rounded,
                  ),
                ],
                selected: _tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<AppState>(
      builder: (context, appState, _) => IndexedStack(
        index: _tab.index,
        children: [
          NotificationsSection(
            settings: appState.notificationSettings,
            hasPermission: _hasPermission,
            exactAlarmAllowed: _exactAlarmAllowed,
            onRequestPermission: () async {
              final granted = await _notificationService.requestPermission();
              appState.setNotificationPermission(granted);
              return granted;
            },
            onPermissionChanged: (granted) {
              setState(() => _hasPermission = granted);
              appState.setNotificationPermission(granted);
            },
            onOpenExactAlarmSettings:
                _notificationService.openExactAlarmSettings,
            onToggle: _toggleNotification,
            onEdit: (setting) => _showNotificationSheet(initial: setting),
            onDelete: _deleteNotification,
          ),
          AlarmsSection(
            missionSession: appState.missionSession,
            onDisableBlocked: _onDisableBlocked,
            nextFireByAlarm: _nextFireByAlarm(appState),
            skips: appState.skips,
            onSkipChanged: _toggleSkip,
            alarms: appState.alarms,
            isSupported: _alarmSupported,
            isPermissionGranted: _alarmGranted,
            onRequestPermission: () async {
              await _alarmService.requestPermission();
              await _refreshPermissions();
            },
            onToggle: _toggleAlarm,
            onEdit: _addOrEditAlarm,
            onDelete: _deleteAlarm,
          ),
        ],
      ),
    );
  }
}
