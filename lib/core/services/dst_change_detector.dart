import 'timezone_service.dart';

class DSTChangeInfo {
  final DateTime changeDate;
  final bool enteringDST;
  final Duration oldOffset;
  final Duration newOffset;

  const DSTChangeInfo({
    required this.changeDate,
    required this.enteringDST,
    required this.oldOffset,
    required this.newOffset,
  });

  Duration get offsetChange => newOffset - oldOffset;
}

class DSTChangeDetector {
  final TimezoneService timezoneService;

  DSTChangeDetector({required this.timezoneService});

  bool shouldCheckDST() {
    return timezoneService.hasDSTSupport();
  }

  List<DSTChangeInfo> detectDSTChanges({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final changes = <DSTChangeInfo>[];

    DateTime currentDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    Duration? previousOffset;

    while (currentDate.isBefore(end) || currentDate.isAtSameMomentAs(end)) {
      final offset = timezoneService.getTimezoneOffset(currentDate);

      if (previousOffset != null && offset != previousOffset) {
        changes.add(
          DSTChangeInfo(
            changeDate: currentDate,
            enteringDST: offset > previousOffset,
            oldOffset: previousOffset,
            newOffset: offset,
          ),
        );
      }

      previousOffset = offset;
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return changes;
  }

  DSTChangeInfo? getNextDSTChange({
    DateTime? afterDate,
    int daysToCheck = 365,
  }) {
    final start = afterDate ?? DateTime.now();
    final end = start.add(Duration(days: daysToCheck));

    final changes = detectDSTChanges(startDate: start, endDate: end);
    return changes.isEmpty ? null : changes.first;
  }

  bool willDSTChangeOccur({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final changes = detectDSTChanges(startDate: startDate, endDate: endDate);
    return changes.isNotEmpty;
  }

  bool isDSTActive(DateTime dateTime) {
    return timezoneService.isDST(dateTime);
  }

  Duration getCurrentOffset() {
    return timezoneService.getTimezoneOffset(DateTime.now());
  }

  String getDSTStatusMessage(DateTime dateTime) {
    final isDst = timezoneService.isDST(dateTime);
    final offset = timezoneService.getTimezoneOffset(dateTime);

    if (isDst) {
      return 'Yaz saati uygulanıyor (${_formatOffset(offset)})';
    } else {
      return 'Kış saati uygulanıyor (${_formatOffset(offset)})';
    }
  }

  String _formatOffset(Duration offset) {
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60).abs();
    final sign = hours >= 0 ? '+' : '-';
    return 'UTC$sign${hours.abs()}:${minutes.toString().padLeft(2, '0')}';
  }

  bool shouldRescheduleNotifications({
    DateTime? lastCheck,
    DateTime? currentTime,
  }) {
    if (!shouldCheckDST()) {
      return false;
    }

    final now = currentTime ?? DateTime.now();
    final lastCheckTime = lastCheck ?? now.subtract(const Duration(days: 1));

    final changes = detectDSTChanges(startDate: lastCheckTime, endDate: now);

    return changes.isNotEmpty;
  }
}
