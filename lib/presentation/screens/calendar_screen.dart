import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/tokens_context.dart';
import '../../core/models/prayer_time.dart';
import '../../core/models/location.dart';
import '../widgets/calendar/calendar_table.dart';
import '../widgets/common/app_surface.dart';
import '../widgets/common/state_widgets.dart';

class CalendarScreen extends StatefulWidget {
  final Location location;
  final List<PrayerTime> prayerTimes;
  final VoidCallback? onRefresh;
  final bool isLoading;
  final String? errorMessage;

  const CalendarScreen({
    super.key,
    required this.location,
    required this.prayerTimes,
    this.onRefresh,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _CalendarAppBar(
        location: widget.location,
        dayCount: widget.prayerTimes.length,
      ),
      body: AppSurface(
        child: Padding(
          // Takvim altı saat kolonu yan yana taşıyor; sayfa payı diğer
          // ekranlardan dar tutuluyor ki kolonlara nefes kalsın.
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (widget.isLoading) {
      return const LoadingState(message: 'Takvim yükleniyor...');
    }

    if (widget.errorMessage != null) {
      return ErrorState(
        message: widget.errorMessage!,
        onRetry: widget.onRefresh,
      );
    }

    if (widget.prayerTimes.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        message: 'Takvim verisi bulunamadı',
      );
    }

    // Liste en bastan gosterilir; bugune otomatik kaydirma yok. Veri zaten
    // bugunden basliyor ve kaydirma, acilista icerigin altindan kaymasi gibi
    // duruyordu.
    return CalendarTable(days: widget.prayerTimes, now: DateTime.now());
  }
}

class _CalendarAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Location location;
  final int dayCount;

  const _CalendarAppBar({required this.location, required this.dayCount});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Sekme olarak barindirildigi icin geri oku yok.
      automaticallyImplyLeading: false,
      title: Column(
        children: [
          Text(
            'Vakit Takvimi',
            style: AppTypography.screenTitle.copyWith(
              color: tokens.textPrimary,
            ),
          ),
          Text(
            '${location.displayName} · $dayCount gün',
            style: AppTypography.hint.copyWith(color: tokens.textTertiary),
          ),
        ],
      ),
      centerTitle: true,
    );
  }
}
