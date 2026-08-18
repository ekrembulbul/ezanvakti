import '../../../core/theme/tokens_context.dart';
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

  /// Alt metin ve yanındaki tek seferlik atlama eylemi.
  ///
  /// Satırdaki anahtar **kalıcı** aç/kapa; atlama ayrı bir eylem olarak
  /// duruyor ki hangisinin ne yaptığı okunabilsin. Alarmlar listesiyle aynı
  /// desen.
  Widget _subtitle(BuildContext context) {
    final tokens = context.tokens;
    final canSkip =
        setting.isActive && nextFireAt != null && onSkipToggle != null;
    if (!canSkip) return Text(_offsetText);

    return Row(
      children: [
        Flexible(
          child: Text(
            isSkipped ? 'Yalnızca bu sefer atlanacak' : _offsetText,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Text(' · '),
        GestureDetector(
          onTap: onSkipToggle,
          child: Text(
            isSkipped ? 'Geri al' : 'Bu seferi atla',
            style: TextStyle(color: tokens.accent),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GroupedRow(
      icon: PrayerUtils.getPrayerIcon(setting.prayerType),
      title: Text(PrayerUtils.getPrayerName(setting.prayerType)),
      subtitle: _subtitle(context),
      onTap: onTap,
      dimmed: !setting.isActive || !hasPermission,
      trailing: Switch(
        value: setting.isActive,
        onChanged: hasPermission ? (_) => onToggle?.call() : null,
      ),
    );
  }
}
