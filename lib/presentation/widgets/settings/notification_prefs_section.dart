import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/notification_sounds.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/interfaces/local_storage.dart';
import '../../../core/models/general_settings.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/tokens_context.dart';
import '../common/option_picker.dart';

/// Ayarlar → Bildirim ve ses: yeni bildirimlerin varsayılan sesi ve Odak
/// modu davranışı.
///
/// Değişiklik hem [AppState]'e hem depoya yazılır; planlama [onChanged] ile
/// çağıran tarafta tazelenir.
class NotificationPrefsSection extends StatelessWidget {
  final Future<void> Function()? onChanged;

  const NotificationPrefsSection({super.key, this.onChanged});

  Future<void> _update(BuildContext context, GeneralSettings next) async {
    context.read<AppState>().setGeneralSettings(next);
    await ServiceLocator().get<LocalStorage>().saveGeneralSettings(next);
    await onChanged?.call();
  }

  /// Başlık + açıklama + anahtar üçlüsü; bu bölümde birkaç kez tekrarlanıyor.
  Widget _switchRow(
    BuildContext context, {
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final tokens = context.tokens;

    return Row(
      children: [
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
                description,
                style: AppTypography.hint.copyWith(
                  color: tokens.textTertiary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: tokens.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final settings = context.watch<AppState>().generalSettings;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OptionRow<String>(
            label: 'Yeni bildirim sesi',
            selected: settings.defaultSound,
            valueLabel: NotificationSounds.labelFor,
            items: const [
              OptionItem(
                value: NotificationSounds.system,
                label: 'Sistem sesi',
                description: 'Cihazın varsayılan bildirim sesi',
                icon: Icons.volume_up_rounded,
              ),
              OptionItem(
                value: NotificationSounds.beep,
                label: 'Kısa uyarı',
                description: 'Uygulamanın kendi kısa tonu',
                icon: Icons.notifications_active_rounded,
              ),
              OptionItem(
                value: NotificationSounds.silent,
                label: 'Sessiz',
                description: 'Bildirim görünür, ses çalmaz',
                icon: Icons.notifications_off_rounded,
              ),
            ],
            onChanged: (value) =>
                _update(context, settings.copyWith(defaultSound: value)),
          ),
          Divider(height: 1, thickness: 1, color: tokens.divider),
          const SizedBox(height: 8),
          _switchRow(
            context,
            title: 'Dini günler',
            description:
                'Kandil, bayram ve mübarek günlerde akşam vakti hatırlatır. '
                'Tarihler hicri takvimden hesaplanır; Diyanet takvimiyle bir '
                'gün farklı olabilir.',
            value: settings.religiousDayNotifications,
            onChanged: (value) => _update(
              context,
              settings.copyWith(religiousDayNotifications: value),
            ),
          ),
          if (settings.religiousDayNotifications)
            _switchRow(
              context,
              title: 'Bir gün önce de hatırlat',
              description: 'Öğle vaktinde "yarın" bildirimi gönderir.',
              value: settings.religiousDayEve,
              onChanged: (value) =>
                  _update(context, settings.copyWith(religiousDayEve: value)),
            ),
          Divider(height: 1, thickness: 1, color: tokens.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Odak modunda göster',
                      style: AppTypography.rowTitle.copyWith(
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bildirimler Odak açıkken özete düşmez. Telefonun '
                      'sessiz anahtarını delmez.',
                      style: AppTypography.hint.copyWith(
                        color: tokens.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.showInFocusMode,
                activeThumbColor: tokens.accent,
                onChanged: (value) =>
                    _update(context, settings.copyWith(showInFocusMode: value)),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
