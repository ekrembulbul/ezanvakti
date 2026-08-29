import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), content: .noData)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        let entries = PrayerTimeline.entries(
            for: SnapshotStore.load(), now: Date(), calendar: .current
        )
        completion(entries.first ?? placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now = Date()
        let entries = PrayerTimeline.entries(
            for: SnapshotStore.load(), now: now, calendar: .current
        )

        // Timeline tükendiğinde WidgetKit yeniden sorar; snapshot 7 gün
        // taşıdığı için uygulama hiç açılmasa bile taze 48 saat üretilir.
        // Veri yokken bir saat sonra tekrar bakılır: uygulama bu arada
        // açılmış olabilir.
        let refreshAt = entries.last.map { $0.date > now ? $0.date : now.addingTimeInterval(3600) }
            ?? now.addingTimeInterval(3600)

        completion(Timeline(entries: entries, policy: .after(refreshAt)))
    }
}

struct EzanVaktiWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    private var phase: DayPhase {
        if case let .ready(_, _, phase, _, _, _) = entry.content { return phase }
        return .fallback
    }

    var body: some View {
        content
            .widgetURL(URL(string: "ezanvakti://home"))
            .containerBackground(for: .widget) {
                switch family {
                case .systemSmall, .systemMedium:
                    PhaseBackground(phase: phase)
                default:
                    AccessoryWidgetBackground()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemSmall: SmallView(entry: entry)
        case .systemMedium: MediumView(entry: entry)
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryInline: InlineView(entry: entry)
        default: SmallView(entry: entry)
        }
    }
}

struct EzanVaktiWidget: Widget {
    /// Dart tarafındaki `HomeWidgetPublisher.widgetKind` ile birebir aynı
    /// olmalı; aksi halde reload hiçbir widget'a ulaşmaz.
    let kind = "EzanVaktiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            EzanVaktiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Ezan Vakti")
        .description("Sıradaki vakit ve geri sayım.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline,
        ])
    }
}
