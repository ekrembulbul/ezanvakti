enum PrayerType { fajr, sunrise, dhuhr, asr, maghrib, isha }

class NotificationSetting {
  final PrayerType prayerType;
  final bool isActive;
  final int minutesBefore;

  const NotificationSetting({
    required this.prayerType,
    required this.isActive,
    this.minutesBefore = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'prayerType': prayerType.name,
      'isActive': isActive,
      'minutesBefore': minutesBefore,
    };
  }

  factory NotificationSetting.fromJson(Map<String, dynamic> json) {
    return NotificationSetting(
      prayerType: PrayerType.values.firstWhere(
        (e) => e.name == json['prayerType'],
      ),
      isActive: json['isActive'] as bool,
      minutesBefore: json['minutesBefore'] as int? ?? 0,
    );
  }

  NotificationSetting copyWith({
    PrayerType? prayerType,
    bool? isActive,
    int? minutesBefore,
  }) {
    return NotificationSetting(
      prayerType: prayerType ?? this.prayerType,
      isActive: isActive ?? this.isActive,
      minutesBefore: minutesBefore ?? this.minutesBefore,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSetting &&
          runtimeType == other.runtimeType &&
          prayerType == other.prayerType &&
          isActive == other.isActive &&
          minutesBefore == other.minutesBefore;

  @override
  int get hashCode => Object.hash(prayerType, isActive, minutesBefore);
}
