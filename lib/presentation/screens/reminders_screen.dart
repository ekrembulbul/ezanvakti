import 'dart:async';

import '../services/upcoming_resolver.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/derived_time.dart';
import '../../core/models/skipped_occurrence.dart';
import '../../features/alarms/domain/alarm_scheduler.dart';
import '../../features/notifications/domain/skip_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/interfaces/local_storage.dart';
import '../../core/interfaces/alarm_service.dart';
import '../../core/interfaces/notification_service.dart';
import '../../core/models/alarm.dart';
import '../../core/models/notification_setting.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/exact_alarm_service.dart';
import '../../core/utils/app_logger.dart';
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
    // Ekrandan çıkmak planlamayı iptal etmemeli: kullanıcı bir kaydı silmiş
    // olabilir ve onun eski OS kopyası hâlâ kurulu.
    _flushReschedule();
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

  /// Planlamanın bekletildiği süre.
  ///
  /// [_reschedule] tüm bildirim ve alarmları OS'ten iptal edip yeniden
  /// kuruyor; simülatörde 63 bildirim için ~370 ms sürüyor ve bu boyunca UI
  /// isolate'i meşgul. Silme animasyonu ve snackbar girişiyle çakışınca
  /// kullanıcı bunu takılma olarak görüyor. Bekleme ayrıca sil + "Geri al"
  /// gibi hızlı ardışık mutasyonları tek planlamada birleştiriyor.
  static const Duration _kReschedulePause = Duration(milliseconds: 400);

  Timer? _rescheduleTimer;
  AppState? _pendingReschedule;

  /// Planlama işlerinin sırası: silme ile hemen ardından gelen geri almanın
  /// planlamaları iç içe girmesin.
  Future<void> _syncQueue = Future<void>.value();

  void _queueReschedule(AppState appState) {
    _pendingReschedule = appState;
    _rescheduleTimer?.cancel();
    _rescheduleTimer = Timer(_kReschedulePause, _flushReschedule);
  }

  void _flushReschedule() {
    _rescheduleTimer?.cancel();
    _rescheduleTimer = null;
    final appState = _pendingReschedule;
    if (appState == null) return;
    _pendingReschedule = null;

    _syncQueue = _syncQueue
        .then((_) => _reschedule(appState))
        .then((_) => _refreshScheduleFailures())
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger().error(
            'Hatırlatıcı planlaması başarısız',
            error,
            stackTrace,
          );
        });
  }

  /// Listeyi tazeler, planlamayı sıraya alır. Planlamayı **beklemez**.
  Future<void> _syncNotifications(AppState appState) async {
    appState.setNotificationSettings(await _settingsManager.getSettings());
    _queueReschedule(appState);
  }

  /// Son planlamada kurulamayan alarmlar; satır uyarısı için.
  Map<String, String> _scheduleFailures = {};

  Future<void> _refreshScheduleFailures() async {
    final failures = await ServiceLocator()
        .get<LocalStorage>()
        .getAlarmScheduleFailures();
    if (mounted) setState(() => _scheduleFailures = failures);
  }

  Future<void> _syncAlarms(AppState appState) async {
    appState.setAlarms(await _alarmsManager.getAlarms());
    _queueReschedule(appState);
  }

  // --- Bildirim mutasyonları ---

  Future<void> _addNotification(
    PrayerType type,
    int minutesBefore, [
    Set<int> weekdays = const {},
    String? label,
  ]) async {
    final appState = context.read<AppState>();
    final setting = NotificationSetting(
      prayerType: type,
      isActive: true,
      minutesBefore: minutesBefore,
      weekdays: weekdays,
      label: label,
      soundId: appState.generalSettings.defaultSound,
    );
    final exists = appState.notificationSettings.any(
      (s) =>
          s.prayerType == type &&
          s.minutesBefore == minutesBefore &&
          s.weekdaysCsv == setting.weekdaysCsv,
    );
    if (exists) {
      _snack('Bu bildirim zaten mevcut', isError: true);
      return;
    }

    await _settingsManager.addSetting(setting);
    await _syncNotifications(appState);
    _snack('Bildirim eklendi');
  }

  /// Hazır şablon: Cuma öğle vaktinden 45 dk önce, "Cuma namazı" etiketiyle.
  Future<void> _addFridayReminder() async {
    await _addNotification(PrayerType.dhuhr, 45, const {5}, 'Cuma namazı');
  }

  Future<void> _updateNotification(
    NotificationSetting original,
    PrayerType type,
    int minutesBefore, [
    Set<int> weekdays = const {},
    String? label,
  ]) async {
    final appState = context.read<AppState>();
    final updated = NotificationSetting(
      prayerType: type,
      isActive: original.isActive,
      minutesBefore: minutesBefore,
      soundId: original.soundId,
      weekdays: weekdays,
      label: label,
    );
    final duplicate = appState.notificationSettings.any(
      (s) =>
          s.prayerType == type &&
          s.minutesBefore == minutesBefore &&
          s.weekdaysCsv == updated.weekdaysCsv &&
          !(s.prayerType == original.prayerType &&
              s.minutesBefore == original.minutesBefore &&
              s.weekdaysCsv == original.weekdaysCsv),
    );
    if (duplicate) {
      _snack('Bu bildirim zaten mevcut', isError: true);
      return;
    }

    final keyChanged =
        type != original.prayerType ||
        minutesBefore != original.minutesBefore ||
        updated.weekdaysCsv != original.weekdaysCsv;

    if (keyChanged) {
      await _settingsManager.removeSetting(
        prayerType: original.prayerType,
        minutesBefore: original.minutesBefore,
        weekdays: original.weekdaysCsv,
        derivedKind: original.derivedKind?.storageValue ?? '',
      );
      await _settingsManager.addSetting(updated);
    } else {
      await _settingsManager.updateSetting(updated);
    }

    await _syncNotifications(appState);
    _snack('Bildirim güncellendi');
  }

  /// Onay sorulmadan siler; geri alma "Geri al" ile verilir.
  Future<void> _deleteNotification(NotificationSetting setting) async {
    final appState = context.read<AppState>();
    await _settingsManager.removeSetting(
      prayerType: setting.prayerType,
      minutesBefore: setting.minutesBefore,
      weekdays: setting.weekdaysCsv,
      derivedKind: setting.derivedKind?.storageValue ?? '',
    );
    await _syncNotifications(appState);
    _snack(
      'Bildirim silindi',
      action: SnackBarAction(
        label: 'Geri al',
        textColor: Colors.white,
        onPressed: () => _restoreNotification(setting),
      ),
    );
  }

  Future<void> _restoreNotification(NotificationSetting setting) async {
    final appState = context.read<AppState>();
    await _settingsManager.addSetting(setting);
    await _syncNotifications(appState);
  }

  /// Kapatma, "yalnızca bu sefer"in giriş kapısı: kayıt kapatılır ve altta
  /// çıkan çubuk tek seferliğe çevirme seçeneğini sunar.
  Future<void> _toggleNotification(NotificationSetting setting) async {
    final appState = context.read<AppState>();
    final turningOff = setting.isActive;
    // Sıradaki tetiklenme kapatmadan **önce** hesaplanmalı: kapalı kayıt
    // planlamada yer almıyor.
    final fireAt = turningOff ? _nextFireOf(appState, setting) : null;

    await _settingsManager.updateSetting(
      setting.copyWith(isActive: !setting.isActive),
    );
    await _syncNotifications(appState);
    if (!turningOff) return;

    _snack(
      'Bildirim kapatıldı',
      action: fireAt == null
          ? null
          : SnackBarAction(
              label: 'Yalnızca bu sefer',
              textColor: Colors.white,
              onPressed: () => _skipOnceNotification(setting, fireAt),
            ),
    );
  }

  DateTime? _nextFireOf(AppState appState, NotificationSetting setting) =>
      resolveNextFirePerNotification(
        settings: appState.notificationSettings,
        prayerTimes: appState.prayerTimes,
        now: DateTime.now(),
      )[notificationKey(setting)];

  /// Kapatılan bildirimi geri açar ve yalnızca sıradaki örneği atlar.
  Future<void> _skipOnceNotification(
    NotificationSetting setting,
    DateTime fireAt,
  ) async {
    final appState = context.read<AppState>();
    await _settingsManager.updateSetting(setting.copyWith(isActive: true));
    await _syncNotifications(appState);
    await _toggleSkip(
      SkippedOccurrence(
        kind: SkipKind.notification,
        reference: notificationKey(setting),
        fireAt: fireAt,
      ),
      true,
    );
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

  /// Kapatma, "yalnızca bu sefer"in giriş kapısı: alarm kapatılır ve altta
  /// çıkan çubuk tek seferliğe çevirme seçeneğini sunar.
  Future<void> _toggleAlarm(Alarm alarm, bool isActive) async {
    final appState = context.read<AppState>();
    // Sıradaki çalış kapatmadan **önce** hesaplanmalı: kapalı alarm
    // planlamada yer almıyor.
    final fireAt = isActive ? null : _nextFireByAlarm(appState)[alarm.id];

    await _alarmsManager.setActive(alarm, isActive);
    await _syncAlarms(appState);
    if (isActive) return;

    _snack(
      'Alarm kapatıldı',
      action: fireAt == null
          ? null
          : SnackBarAction(
              label: 'Yalnızca bu sefer',
              textColor: Colors.white,
              onPressed: () => _skipOnceAlarm(alarm, fireAt),
            ),
    );
  }

  /// Kapatılan alarmı geri açar ve yalnızca sıradaki çalışı atlar.
  Future<void> _skipOnceAlarm(Alarm alarm, DateTime fireAt) async {
    final appState = context.read<AppState>();
    await _alarmsManager.setActive(alarm, true);
    await _syncAlarms(appState);
    await _toggleSkip(
      SkippedOccurrence(
        kind: SkipKind.alarm,
        reference: alarm.id,
        fireAt: fireAt,
      ),
      true,
    );
  }

  /// Kaydırınca onay sorulmadan siler; geri alma "Geri al" ile veriliyor.
  ///
  /// Silinen alarm bellekte tutuluyor ve geri alınırsa aynı id ile yeniden
  /// kaydediliyor, böylece atlama kayıtları ve görev geçmişi eşleşmeye devam
  /// ediyor.
  Future<void> _deleteAlarm(Alarm alarm) async {
    final appState = context.read<AppState>();
    await _alarmsManager.delete(alarm.id);
    await _syncAlarms(appState);
    _snack(
      '${alarmTimeLabel(alarm)} alarmı silindi',
      action: SnackBarAction(
        label: 'Geri al',
        textColor: Colors.white,
        onPressed: () => _restoreAlarm(alarm),
      ),
    );
  }

  Future<void> _restoreAlarm(Alarm alarm) async {
    final appState = context.read<AppState>();
    await _alarmsManager.save(alarm);
    await _syncAlarms(appState);
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
        onAdd: (type, minutes, weekdays, label) => initial == null
            ? _addNotification(type, minutes, weekdays, label)
            : _updateNotification(initial, type, minutes, weekdays, label),
      ),
    );
  }

  void _snack(
    String message, {
    bool isError = false,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!mounted) return;
    // Onceki snackbar'i hemen kaldir; yeni islem mesaji beklemeden gosterilsin.
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: duration,
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : context.tokens.accent,
        // Eylemli snackbar Flutter'da varsayilan olarak **kalici**
        // (`persist = action != null`): kullanici eyleme dokunmazsa hic
        // kapanmiyordu. Sure dolunca kendiliginden kalksin.
        persist: false,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        // Varsayilan esik 0.25: eylem etiketi cubugun dortte birinden genisse
        // alt satira duesuyor ve cubuk iki kat yukseliyor. "Yalnizca bu sefer"
        // bu esigi asiyordu; yaziyi kisaltmak yerine esigi yukselttik.
        actionOverflowThreshold: 0.5,
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
            nextFireByNotification: resolveNextFirePerNotification(
              settings: appState.notificationSettings,
              prayerTimes: appState.prayerTimes,
              now: DateTime.now(),
            ),
            skips: appState.skips,
            onSkipChanged: _toggleSkip,
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
            onAddFridayReminder: _addFridayReminder,
            onDelete: _deleteNotification,
          ),
          AlarmsSection(
            missionSession: appState.missionSession,
            onDisableBlocked: _onDisableBlocked,
            scheduleFailures: _scheduleFailures,
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
