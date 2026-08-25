import 'package:flutter/material.dart';

import '../../../core/models/notification_setting.dart';
import '../../../core/utils/prayer_utils.dart';
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

  String get _offsetText => setting.minutesBefore == 0
      ? 'Tam vaktinde'
      : '${setting.minutesBefore} dk önce';

  /// Atlanan bildirim de kapalı görünür: kullanıcı için ikisi de "bu sefer
  /// gelmeyecek" demek. Atlanan örnek geçince satır kendiliğinden açılır.
  bool get _isOn => setting.isActive && !_skipping;

  bool get _skipping => isSkipped && nextFireAt != null;

  /// Satırın alt metni. Tek seferlik atlama ayrı bir eylem değil: anahtar
  /// kapatılınca altta çıkan çubuktan seçiliyor.
  String get _subtitle {
    if (_skipping) return 'Yalnızca bu sefer atlanacak';
    if (!setting.isActive) return 'Kapalı';
    return _offsetText;
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
      icon: PrayerUtils.getPrayerIcon(setting.prayerType),
      title: Text(PrayerUtils.getPrayerName(setting.prayerType)),
      subtitle: Text(_subtitle),
      onTap: onTap,
      dimmed: !_isOn || !hasPermission,
      trailing: Switch(
        value: _isOn,
        onChanged: hasPermission ? _onSwitch : null,
      ),
    );
  }
}
