import 'dart:async';
import '../../l10n/l10n_extensions.dart';

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
import '../../core/models/mission_session.dart';
import '../../core/models/notification_setting.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/exact_alarm_service.dart';
import '../../core/utils/app_logger.dart';
import '../../core/theme/tokens_context.dart';
import '../../features/alarms/domain/alarms_manager.dart';
import '../../features/notifications/domain/notification_settings_manager.dart';
import '../services/reminder_rescheduler.dart';
import '../services/reminder_list_preferences.dart';
import '../utils/alarm_labels.dart';
import '../utils/reminder_labels.dart';
import '../utils/prayer_name_helper.dart';
import '../widgets/common/app_bar_widgets.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/sliding_segment.dart';
import '../widgets/notifications/add_notification_bottom_sheet.dart';
import '../widgets/reminders/alarms_section.dart';
import '../widgets/reminders/notifications_section.dart';
import 'alarm_edit_screen.dart';

enum ReminderTab { notifications, alarms }

enum _OrderAction { custom, nextFire, name, reorder }

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
  late final ReminderListPreferencesStore _orderStore;
  final _orders = <ReminderListKind, ReminderListPreferences>{};
  final _savedOrders = <ReminderListKind, ReminderListPreferences>{};
  Future<void> _orderWrites = Future<void>.value();
  bool _ordersLoaded = false;
  bool _isReordering = false;
  Timer? _clockTimer;

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
    _orderStore = ReminderListPreferencesStore(
      storage: locator.get<LocalStorage>(),
    );
    _loadOrders();
    _clockTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_isReordering) setState(() {});
    });
    _hasPermission = context.read<AppState>().hasNotificationPermission;
    _refreshPermissions();
    _refreshScheduleFailures();
  }

  @override
  void dispose() {
    // Ekrandan çıkmak planlamayı iptal etmemeli: kullanıcı bir kaydı silmiş
    // olabilir ve onun eski OS kopyası hâlâ kurulu.
    _flushReschedule();
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kullanıcı sistem ayarlarından dönünce izin durumunu tazele.
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
      _refreshScheduleFailures();
      setState(() {});
    }
  }

  ReminderListPreferences _orderFor(ReminderListKind kind) =>
      _orders[kind] ?? const ReminderListPreferences();

  ReminderListKind get _selectedKind => _tab == ReminderTab.alarms
      ? ReminderListKind.alarms
      : ReminderListKind.notifications;

  Future<void> _loadOrders() async {
    try {
      final values = await Future.wait([
        for (final kind in ReminderListKind.values) _orderStore.load(kind),
      ]);
      if (!mounted) return;
      setState(() {
        for (final (index, kind) in ReminderListKind.values.indexed) {
          _orders[kind] = values[index];
          _savedOrders[kind] = values[index];
        }
        _ordersLoaded = true;
      });
    } catch (error, stackTrace) {
      AppLogger().error('Loading reminder order failed', error, stackTrace);
      if (mounted) _snack(context.l10n.reminderOrderLoadFailed, isError: true);
    }
  }

  Future<void> _saveOrder(ReminderListKind kind, ReminderListPreferences next) {
    if (mounted) {
      setState(() => _orders[kind] = next);
    } else {
      _orders[kind] = next;
    }
    // Hızlı ardışık sürüklemelerde son tercih en son kalıcılaştırılır.
    _orderWrites = _orderWrites.then((_) async {
      try {
        await _orderStore.save(kind, next);
        _savedOrders[kind] = next;
      } catch (error, stackTrace) {
        AppLogger().error(
          'Saving reminder order failed kind=${kind.name}',
          error,
          stackTrace,
        );
        if (!mounted) return;
        if (identical(_orders[kind], next)) {
          setState(
            () => _orders[kind] =
                _savedOrders[kind] ?? const ReminderListPreferences(),
          );
        }
        _snack(context.l10n.reminderOrderSaveFailed, isError: true);
      }
    });
    return _orderWrites;
  }

  void _changeOrder(_OrderAction action) {
    if (action == _OrderAction.reorder) {
      setState(() => _isReordering = true);
      return;
    }
    final mode = switch (action) {
      _OrderAction.custom => ReminderSortMode.custom,
      _OrderAction.nextFire => ReminderSortMode.nextFire,
      _OrderAction.name => ReminderSortMode.name,
      _OrderAction.reorder => throw StateError('Reorder is handled above'),
    };
    _saveOrder(
      _selectedKind,
      _orderFor(_selectedKind).copyWith(sortMode: mode),
    );
  }

  void _reorder(
    ReminderListKind kind,
    List<String> keys,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex == newIndex) return;
    final reordered = [...keys];
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    _saveOrder(
      kind,
      _orderFor(
        kind,
      ).copyWith(sortMode: ReminderSortMode.custom, customOrder: reordered),
    );
  }

  Widget _sortAction() {
    if (_isReordering) {
      return AppBarActionButton(
        key: const Key('reminder_reorder_done'),
        icon: Icons.check_rounded,
        tooltip: context.l10n.reminderReorderDone,
        onTap: () => setState(() => _isReordering = false),
      );
    }
    final mode = _orderFor(_selectedKind).sortMode;
    return PopupMenuButton<_OrderAction>(
      key: const Key('reminder_sort_menu'),
      enabled: _ordersLoaded,
      tooltip: context.l10n.reminderSort,
      icon: const Icon(Icons.sort_rounded),
      onSelected: _changeOrder,
      itemBuilder: (_) => [
        for (final (action, sortMode, label) in [
          (
            _OrderAction.custom,
            ReminderSortMode.custom,
            context.l10n.reminderSortCustom,
          ),
          (
            _OrderAction.nextFire,
            ReminderSortMode.nextFire,
            context.l10n.reminderSortNextFire,
          ),
          (
            _OrderAction.name,
            ReminderSortMode.name,
            context.l10n.reminderSortName,
          ),
        ])
          CheckedPopupMenuItem(
            key: ValueKey('reminder-sort-${sortMode.name}'),
            value: action,
            checked: mode == sortMode,
            child: Text(label),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _OrderAction.reorder,
          child: Text(context.l10n.reminderReorder),
        ),
      ],
    );
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
        .whenComplete(_refreshScheduleFailures)
        .catchError((Object error, StackTrace stackTrace) {
          AppLogger().error(
            // Log; kullanıcıya gösterilmiyor, çevrilmiyor.
            'Reminder scheduling failed',
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
  int _alarmListRevision = 0;

  Future<void> _refreshScheduleFailures() async {
    try {
      final failures = await ServiceLocator()
          .get<LocalStorage>()
          .getAlarmScheduleFailures();
      if (mounted) setState(() => _scheduleFailures = failures);
    } catch (error, stackTrace) {
      AppLogger().warning(
        'Loading alarm schedule status failed',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _syncAlarms(AppState appState) async {
    try {
      await _alarmsManager.scheduler.scheduleAlarms(
        prayerTimes: appState.prayerTimes,
        skips: appState.skips,
      );
    } catch (error) {
      AppLogger().warning('Alarm reconciliation failed', error.runtimeType);
      if (mounted) {
        _snack(
          context.l10n.alarmChangeFailed,
          isError: true,
          action: SnackBarAction(
            label: context.l10n.actionRetry,
            onPressed: () => unawaited(_syncAlarms(appState)),
          ),
        );
      }
    }
    await _reloadAlarms(appState);
  }

  Future<void> _reloadAlarms(AppState appState) async {
    try {
      appState.setAlarms(await _alarmsManager.getAlarms());
    } catch (error) {
      AppLogger().warning(
        'Alarm rows could not be refreshed',
        error.runtimeType,
      );
    }
    try {
      appState.setMissionSessions(await _alarmService.getMissionSessions());
    } catch (error) {
      AppLogger().warning(
        'Mission state could not be refreshed',
        error.runtimeType,
      );
    }
    await _refreshScheduleFailures();
  }

  Future<bool> _changeAlarm(
    AppState appState,
    Future<void> Function() change,
    Future<void> Function() retry,
  ) async {
    try {
      await change();
    } catch (error) {
      AppLogger().warning('Alarm change did not finish', error.runtimeType);
      await _reloadAlarms(appState);
      if (mounted) {
        // Recreate a swiped row if persistence failed before it was removed.
        setState(() => _alarmListRevision++);
        _snack(
          context.l10n.alarmChangeFailed,
          isError: true,
          action: SnackBarAction(
            label: context.l10n.actionRetry,
            onPressed: () => unawaited(retry()),
          ),
        );
      }
      return false;
    }
    await _syncAlarms(appState);
    return true;
  }

  // --- Bildirim mutasyonları ---

  Future<void> _addNotification(
    PrayerType type,
    int minutesBefore, [
    Set<int> weekdays = const {},
    String? label,
    DerivedTimeKind? derivedKind,
  ]) async {
    final l10n = context.l10n;
    final appState = context.read<AppState>();
    final setting = NotificationSetting(
      prayerType: type,
      derivedKind: derivedKind,
      isActive: true,
      minutesBefore: minutesBefore,
      weekdays: weekdays,
      label: label,
      soundId: appState.generalSettings.defaultSound,
    );
    final exists = appState.notificationSettings.any(
      (s) =>
          s.prayerType == type &&
          s.derivedKind == derivedKind &&
          s.minutesBefore == minutesBefore &&
          s.weekdaysCsv == setting.weekdaysCsv,
    );
    if (exists) {
      _snack(l10n.snackNotificationExists, isError: true);
      return;
    }

    await _settingsManager.addSetting(setting);
    await _syncNotifications(appState);
    _snack(l10n.snackNotificationAdded);
  }

  /// Hazır şablon: Cuma öğle vaktinden 45 dk önce, "Cuma namazı" etiketiyle.
  Future<void> _addFridayReminder() async {
    final l10n = context.l10n;
    await _addNotification(PrayerType.dhuhr, 45, const {
      5,
    }, l10n.reminderFridayLabel);
  }

  Future<void> _updateNotification(
    NotificationSetting original,
    PrayerType type,
    int minutesBefore, [
    Set<int> weekdays = const {},
    String? label,
    DerivedTimeKind? derivedKind,
  ]) async {
    final l10n = context.l10n;
    final appState = context.read<AppState>();
    final updated = NotificationSetting(
      prayerType: type,
      derivedKind: derivedKind,
      isActive: original.isActive,
      minutesBefore: minutesBefore,
      soundId: original.soundId,
      weekdays: weekdays,
      label: label,
    );
    final duplicate = appState.notificationSettings.any(
      (s) =>
          s.prayerType == type &&
          s.derivedKind == derivedKind &&
          s.minutesBefore == minutesBefore &&
          s.weekdaysCsv == updated.weekdaysCsv &&
          !(s.prayerType == original.prayerType &&
              s.derivedKind == original.derivedKind &&
              s.minutesBefore == original.minutesBefore &&
              s.weekdaysCsv == original.weekdaysCsv),
    );
    if (duplicate) {
      _snack(l10n.snackNotificationExists, isError: true);
      return;
    }

    final keyChanged =
        type != original.prayerType ||
        derivedKind != original.derivedKind ||
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
      final order = _orderFor(ReminderListKind.notifications);
      final moved = order.replaceKey(
        notificationKey(original),
        notificationKey(updated),
      );
      if (_ordersLoaded && !identical(order, moved)) {
        unawaited(_saveOrder(ReminderListKind.notifications, moved));
      }
    } else {
      await _settingsManager.updateSetting(updated);
    }

    await _syncNotifications(appState);
    _snack(l10n.snackNotificationUpdated);
  }

  /// Onay sorulmadan siler; geri alma "Geri al" ile verilir.
  Future<void> _deleteNotification(NotificationSetting setting) async {
    final l10n = context.l10n;
    final appState = context.read<AppState>();
    await _settingsManager.removeSetting(
      prayerType: setting.prayerType,
      minutesBefore: setting.minutesBefore,
      weekdays: setting.weekdaysCsv,
      derivedKind: setting.derivedKind?.storageValue ?? '',
    );
    await _syncNotifications(appState);
    _snack(
      l10n.snackNotificationDeleted,
      action: SnackBarAction(
        label: l10n.snackUndo,
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
    final l10n = context.l10n;
    final appState = context.read<AppState>();
    final turningOff = setting.isActive;
    // Sıradaki tetiklenme kapatmadan **önce** hesaplanmalı: kapalı kayıt
    // planlamada yer almıyor.
    final occurrence = turningOff ? _nextOccurrenceOf(appState, setting) : null;

    await _settingsManager.updateSetting(
      setting.copyWith(isActive: !setting.isActive),
    );
    await _syncNotifications(appState);
    if (!turningOff) return;

    _snack(
      l10n.reminderOff,
      action: occurrence == null
          ? null
          : SnackBarAction(
              label: l10n.snackSkipOnce,
              textColor: Colors.white,
              onPressed: () => _skipOnceNotification(setting, occurrence),
            ),
    );
  }

  UpcomingNotification? _nextOccurrenceOf(
    AppState appState,
    NotificationSetting setting,
  ) => resolveNextOccurrencePerNotification(
    settings: appState.notificationSettings,
    prayerTimes: appState.prayerTimes,
    now: DateTime.now(),
  )[notificationKey(setting)];

  /// Kapatılan bildirimi geri açar ve yalnızca sıradaki örneği atlar.
  Future<void> _skipOnceNotification(
    NotificationSetting setting,
    UpcomingNotification occurrence,
  ) async {
    final appState = context.read<AppState>();
    await _settingsManager.updateSetting(setting.copyWith(isActive: true));
    await _syncNotifications(appState);
    await _toggleSkip(notificationOccurrence(occurrence), true);
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
    await _saveAlarm(appState, result);
  }

  Future<void> _saveAlarm(AppState appState, Alarm alarm) async {
    await _changeAlarm(
      appState,
      () => _alarmsManager.save(alarm),
      () => _saveAlarm(appState, alarm),
    );
  }

  Future<void> _duplicateAlarm(Alarm source) => _addOrEditAlarm(
    duplicateOf(
      source,
      newId: DateTime.now().microsecondsSinceEpoch.toString(),
      copyLabel: context.l10n.alarmCopySuffix,
    ),
  );

  /// Her alarmın bir sonraki çalma anı. Atlama **uygulanmadan** hesaplanır:
  /// kullanıcı tam da bu örneği atlamak/geri almak istiyor.
  Map<String, DateTime> _nextFireByAlarm(AppState appState, {DateTime? now}) {
    final byDate = <DateTime, PrayerTime>{
      for (final pt in appState.prayerTimes)
        DateTime(pt.date.year, pt.date.month, pt.date.day): pt,
    };
    final referenceTime = now ?? DateTime.now();
    final result = <String, DateTime>{};
    for (final alarm in appState.alarms) {
      final snoozed = MissionSession.pendingForAlarm(
        appState.missionSessions,
        alarm.id,
      )?.snoozedUntil;
      final fire = snoozed?.isAfter(referenceTime) == true
          ? snoozed
          : AlarmScheduler.computeNextFire(
              alarm: alarm,
              now: referenceTime,
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
    _snack(context.l10n.alarmBlockedSnoozed);
  }

  /// Kapatma, "yalnızca bu sefer"in giriş kapısı: alarm kapatılır ve altta
  /// çıkan çubuk tek seferliğe çevirme seçeneğini sunar.
  Future<void> _toggleAlarm(Alarm alarm, bool isActive) async {
    final l10n = context.l10n;
    final appState = context.read<AppState>();
    // Sıradaki çalış kapatmadan **önce** hesaplanmalı: kapalı alarm
    // planlamada yer almıyor.
    final fireAt = isActive
        ? null
        : MissionSession.pendingForAlarm(
                appState.missionSessions,
                alarm.id,
              )?.firedAt ??
              _nextFireByAlarm(appState)[alarm.id];

    final changed = await _changeAlarm(
      appState,
      () => _alarmsManager.setActive(alarm, isActive),
      () => _toggleAlarm(alarm, isActive),
    );
    if (!changed) return;
    if (isActive) return;

    _snack(
      l10n.alarmTurnedOff,
      action: fireAt == null
          ? null
          : SnackBarAction(
              label: l10n.snackSkipOnce,
              textColor: Colors.white,
              onPressed: () => _skipOnceAlarm(alarm, fireAt),
            ),
    );
  }

  /// Kapatılan alarmı geri açar ve yalnızca sıradaki çalışı atlar.
  Future<void> _skipOnceAlarm(Alarm alarm, DateTime fireAt) async {
    final appState = context.read<AppState>();
    final next = await ServiceLocator().get<SkipManager>().skip(
      SkippedOccurrence(
        kind: SkipKind.alarm,
        reference: alarm.id,
        fireAt: fireAt,
      ),
    );
    appState.setSkips(next);
    await _changeAlarm(
      appState,
      () => _alarmsManager.setActive(alarm, true),
      () => _skipOnceAlarm(alarm, fireAt),
    );
  }

  /// Kaydırınca onay sorulmadan siler; geri alma "Geri al" ile veriliyor.
  ///
  /// Silinen alarm bellekte tutuluyor ve geri alınırsa aynı id ile yeniden
  /// kaydediliyor, böylece atlama kayıtları ve görev geçmişi eşleşmeye devam
  /// ediyor.
  Future<void> _deleteAlarm(Alarm alarm) async {
    final l10n = context.l10n;
    final appState = context.read<AppState>();
    final deleted = await _changeAlarm(
      appState,
      () => _alarmsManager.delete(alarm.id),
      () => _deleteAlarm(alarm),
    );
    if (!deleted) return;
    _snack(
      l10n.alarmDeleted(alarmTimeLabel(alarm, l10n: l10n)),
      action: SnackBarAction(
        label: l10n.snackUndo,
        textColor: Colors.white,
        onPressed: () => _restoreAlarm(alarm),
      ),
    );
  }

  Future<void> _restoreAlarm(Alarm alarm) async {
    final appState = context.read<AppState>();
    await _saveAlarm(appState, alarm);
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
        submitLabel: initial == null ? null : context.l10n.remindersUpdate,
        title: initial == null ? null : context.l10n.remindersUpdateTitle,
        onAdd: (type, minutes, weekdays, label, derivedKind) => initial == null
            ? _addNotification(type, minutes, weekdays, label, derivedKind)
            : _updateNotification(
                initial,
                type,
                minutes,
                weekdays,
                label,
                derivedKind,
              ),
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
        title: context.l10n.remindersTitle,
        showBack: false,
        // Tasarimda ekleme eylemi app bar'in saginda; FAB son satiri ortuyordu.
        actions: [
          _sortAction(),
          if (!_isReordering)
            AppBarActionButton(
              key: const Key('add_reminder_button'),
              icon: Icons.add_rounded,
              onTap: _add,
              tooltip: _tab == ReminderTab.alarms
                  ? context.l10n.alarmAdd
                  : context.l10n.remindersAddButton,
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
                items: [
                  SegmentItem(
                    value: ReminderTab.notifications,
                    label: context.l10n.remindersNotifications,
                    icon: Icons.notifications_rounded,
                  ),
                  SegmentItem(
                    value: ReminderTab.alarms,
                    label: context.l10n.remindersAlarms,
                    icon: Icons.alarm_rounded,
                  ),
                ],
                selected: _tab,
                onChanged: (value) => setState(() {
                  _tab = value;
                  _isReordering = false;
                }),
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
      builder: (context, appState, _) {
        final now = DateTime.now();
        final occurrences = resolveNextOccurrencePerNotification(
          settings: appState.notificationSettings,
          prayerTimes: appState.prayerTimes,
          now: now,
        );
        final nextAlarmTimes = _nextFireByAlarm(appState, now: now);
        final alarms = sortReminderItems(
          items: appState.alarms,
          preferences: _orderFor(ReminderListKind.alarms),
          idOf: (alarm) => alarm.id,
          nameOf: (alarm) => alarm.label.trim().isEmpty
              ? alarmTimeLabel(alarm, l10n: context.l10n)
              : alarm.label.trim(),
          nextFireOf: (alarm) =>
              alarm.isActive ? nextAlarmTimes[alarm.id] : null,
        );
        final defaultNotifications = [...appState.notificationSettings]
          ..sort((a, b) {
            final point = PrayerNameHelper.getPrayerOrder(
              a.prayerType,
            ).compareTo(PrayerNameHelper.getPrayerOrder(b.prayerType));
            return point != 0
                ? point
                : a.minutesBefore.compareTo(b.minutesBefore);
          });
        final notifications = sortReminderItems(
          items: defaultNotifications,
          preferences: _orderFor(ReminderListKind.notifications),
          idOf: notificationKey,
          nameOf: (setting) => notificationTitle(setting, context.l10n),
          nextFireOf: (setting) => occurrences[notificationKey(setting)]?.time,
        );
        return IndexedStack(
          index: _tab.index,
          children: [
            NotificationsSection(
              now: now,
              preserveOrder: true,
              isReordering: _isReordering && _tab == ReminderTab.notifications,
              onReorder: (oldIndex, newIndex) => _reorder(
                ReminderListKind.notifications,
                notifications.map(notificationKey).toList(),
                oldIndex,
                newIndex,
              ),
              nextOccurrenceByNotification: occurrences,
              nextFireByNotification: occurrences.map(
                (key, item) => MapEntry(key, item.time),
              ),
              skips: appState.skips,
              onSkipChanged: _toggleSkip,
              settings: notifications,
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
              key: ValueKey(_alarmListRevision),
              now: now,
              isReordering: _isReordering && _tab == ReminderTab.alarms,
              onReorder: (oldIndex, newIndex) => _reorder(
                ReminderListKind.alarms,
                alarms.map((alarm) => alarm.id).toList(),
                oldIndex,
                newIndex,
              ),
              missionSessions: appState.missionSessions,
              onDisableBlocked: _onDisableBlocked,
              scheduleFailures: _scheduleFailures,
              nextFireByAlarm: nextAlarmTimes,
              skips: appState.skips,
              onSkipChanged: _toggleSkip,
              alarms: alarms,
              isSupported: _alarmSupported,
              isPermissionGranted: _alarmGranted,
              onRequestPermission: () async {
                await _alarmService.requestPermission();
                await _refreshPermissions();
              },
              onToggle: _toggleAlarm,
              onEdit: _addOrEditAlarm,
              onDuplicate: _duplicateAlarm,
              onDelete: _deleteAlarm,
            ),
          ],
        );
      },
    );
  }
}
