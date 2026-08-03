import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';

/// Ana ekrandaki gezinme butonlarını (Takvim, Bildirimler, Ayarlar) toplayan
/// modern alt menü. GPS yenileme butonu ana ekranda kaldığı için buraya alınmaz.
Future<void> showHomeMenu(
  BuildContext context, {
  VoidCallback? onCalendar,
  VoidCallback? onNotifications,
  VoidCallback? onSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _HomeMenuSheet(
      onCalendar: onCalendar,
      onNotifications: onNotifications,
      onSettings: onSettings,
    ),
  );
}

class _HomeMenuSheet extends StatelessWidget {
  final VoidCallback? onCalendar;
  final VoidCallback? onNotifications;
  final VoidCallback? onSettings;

  const _HomeMenuSheet({
    this.onCalendar,
    this.onNotifications,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tokens.backgroundStops[1], tokens.backgroundStops.last],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            _MenuItem(
              icon: Icons.calendar_month_rounded,
              title: 'Takvim',
              subtitle: '30 günlük namaz vakitleri',
              onTap: onCalendar == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      onCalendar!();
                    },
            ),
            const SizedBox(height: 10),
            _MenuItem(
              icon: Icons.notifications_rounded,
              title: 'Bildirimler',
              subtitle: 'Vakit hatırlatmalarını yönet',
              onTap: onNotifications == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      onNotifications!();
                    },
            ),
            const SizedBox(height: 10),
            _MenuItem(
              icon: Icons.settings_rounded,
              title: 'Ayarlar',
              subtitle: 'Konum, hesaplama ve uygulama',
              onTap: onSettings == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      onSettings!();
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: tokens.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tokens.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.rowTitle.copyWith(
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.rowSubtitle.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: tokens.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
