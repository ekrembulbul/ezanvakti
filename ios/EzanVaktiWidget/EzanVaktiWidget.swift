import SwiftUI
import WidgetKit

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), content: .noData)
    }

    func snapshot(
        for configuration: EzanVaktiWidgetIntent, in context: Context
    ) async -> PrayerEntry {
        var entry = PrayerTimeline.entries(
            for: SnapshotStore.load(), now: Date(), calendar: .current
        ).first ?? placeholder(in: context)
        entry.alignment = configuration.alignment
        entry.timeFormat = SnapshotStore.timeFormat()
        return entry
    }

    func timeline(
        for configuration: EzanVaktiWidgetIntent, in context: Context
    ) async -> Timeline<PrayerEntry> {
        let now = Date()
        let timeFormat = SnapshotStore.timeFormat()
        let entries = PrayerTimeline.entries(
            for: SnapshotStore.load(), now: now, calendar: .current
        ).map { entry -> PrayerEntry in
            var copy = entry
            copy.alignment = configuration.alignment
            copy.timeFormat = timeFormat
            return copy
        }

        // Timeline tükendiğinde WidgetKit yeniden sorar. Veri yokken bir saat
        // sonra tekrar bakılır: uygulama bu arada açılmış olabilir.
        let refreshAt = entries.last.map {
            $0.date > now ? $0.date : now.addingTimeInterval(3600)
        } ?? now.addingTimeInterval(3600)

        return Timeline(entries: entries, policy: .after(refreshAt))
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
        // Bilerek widgetURL yok. URL verilmeyince dokunus uygulamayi zaten
        // aciyor. URL verildiginde ise Flutter'in yerlesik derin baglanti
        // islemi adresi MaterialApp'e "pushRouteInformation" olarak iletiyor;
        // yolu bos bir adres '/' rotasina cevriliyor ve home: uzerine ikinci
        // bir AppRoot sagdan kayarak push ediliyor (app.dart:1636-1644).
        // Belirli bir ekrana baglanti gerekirse once Dart tarafinda Router ya
        // da onGenerateRoute kurulmali.
        content
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
        case .systemSmall: SmallView(entry: entry, alignment: entry.alignment)
        case .systemMedium: MediumView(entry: entry, alignment: entry.alignment)
        case .accessoryRectangular: RectangularView(entry: entry, alignment: entry.alignment)
        case .accessoryCircular: CircularView(entry: entry)
        default: SmallView(entry: entry, alignment: entry.alignment)
        }
    }
}

struct EzanVaktiWidget: Widget {
    /// Dart tarafındaki `HomeWidgetPublisher.widgetKind` ile birebir aynı
    /// olmalı; aksi halde reload hiçbir widget'a ulaşmaz.
    let kind = "EzanVaktiWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: EzanVaktiWidgetIntent.self,
            provider: Provider()
        ) { entry in
            EzanVaktiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Ezan Vakti")
        .description("Sıradaki vakit ve geri sayım.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular,
        ])
    }
}
