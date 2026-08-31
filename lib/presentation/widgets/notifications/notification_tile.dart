import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_extensions.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';
import '../../utils/alarm_labels.dart' show weekdaysLabel;
import '../common/grouped_list.dart';

/// Bildirim listesindeki tek satır.
///
/// Kendi kartını çizmez; grup içindeki bir [GroupedRow] olarak gelir. Silme,
/// satırı sola kaydırarak yapılır (bkz. `SwipeToDelete`), bu yüzden ayrı bir
/// çöp kutusu düğmesi yoktur.
class NotificationTile extends StatelessWidget {
  final NotificationSetting setting;
  final bool hasPermission;
  final VoidCallback? onToggle;
  final Future<void> Function()? onDelete;
  final VoidCallback? onTap;

  /// Bir sonraki tetiklenme anı. Tek seferlik atlama bu örneğe uygulanır;
  /// `null` ise atlama eylemi çizilmez.
  final DateTime? nextFireAt;

  /// Bu örnek şu an atlanmış mı?
  final bool isSkipped;

  /// Tek seferlik atlama değiştirildiğinde çağrılır.
  final VoidCallback? onSkipToggle;

  const NotificationTile({
    super.key,
    required this.setting,
    required this.hasPermission,
    this.nextFireAt,
    this.isSkipped = false,
    this.onSkipToggle,
    this.onToggle,
    this.onDelete,
    this.onTap,
  });

  String _offsetText(AppLocalizations l10n) => setting.minutesBefore == 0
      ? l10n.reminderOnTime
      : l10n.reminderMinutesBefore(setting.minutesBefore);

  /// Başlık: türetilmiş noktalarda noktanın adı, aksi halde vaktin adı.
  /// Kullanıcı etiket verdiyse etiket kazanır — bildirimde de o görünüyor.
  String _titleFor(AppLocalizations l10n) {
    final label = setting.label;
    if (label != null && label.trim().isNotEmpty) return label.trim();
    final derived = setting.derivedKind;
    if (derived != null) return l10n.derivedName(derived);
    return l10n.prayerName(setting.prayerType);
  }

  /// Atlanan bildirim de kapalı görünür: kullanıcı için ikisi de "bu sefer
  /// gelmeyecek" demek. Atlanan örnek geçince satır kendiliğinden açılır.
  bool get _isOn => setting.isActive && !_skipping;

  bool get _skipping => isSkipped && nextFireAt != null;

  /// Satırın alt metni. Tek seferlik atlama ayrı bir eylem değil: anahtar
  /// kapatılınca altta çıkan çubuktan seçiliyor.
  String _subtitleFor(AppLocalizations l10n) {
    if (_skipping) return l10n.reminderSkippedOnce;
    if (!setting.isActive) return l10n.reminderOff;
    final parts = [
      _offsetText(l10n),
      if (setting.isDayScoped) weekdaysLabel(setting.weekdays, l10n),
      if (setting.isDerived) l10n.derivedHint(setting.derivedKind!),
    ];
    return parts.join(' · ');
  }

  void _onSwitch(bool value) {
    if (!value) {
      onToggle?.call();
      return;
    }
    // Açılıyor: bekleyen tek seferlik atlama varsa önce o kalkar, yoksa
    // bildirim kalıcı olarak açılır.
    if (_skipping && onSkipToggle != null) {
      onSkipToggle!();
      return;
    }
    onToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GroupedRow(
      icon: setting.isDerived
          ? Icons.hourglass_bottom_rounded
          : PrayerUtils.getPrayerIcon(setting.prayerType),
      title: Text(_titleFor(AppLocalizations.of(context))),
      subtitle: Text(_subtitleFor(AppLocalizations.of(context))),
      onTap: onTap,
      dimmed: !_isOn || !hasPermission,
      trailing: Switch(
        value: _isOn,
        onChanged: hasPermission ? _onSwitch : null,
      ),
    );
  }
}
