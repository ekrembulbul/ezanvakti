import SwiftUI

/// Saatin üstündeki tek satır. Sistem tek renk ve tek satırla sınırlar.
struct InlineView: View {
    let entry: PrayerEntry

    var body: some View {
        switch entry.content {
        case .noData:
            Text("Ezan Vakti · uygulamayı aç")
        case .needsUpdate:
            Text("Ezan Vakti · güncelle")
        case let .ready(next, _, _, _, _):
            // Yer yetmezse geri sayım düşer, vakit ve saat kalır.
            ViewThatFits {
                HStack(spacing: 4) {
                    Text(next.name)
                    Text(next.date, format: .dateTime.hour().minute())
                    Text("·")
                    Text(next.date, style: .timer)
                }
                HStack(spacing: 4) {
                    Text(next.name)
                    Text(next.date, format: .dateTime.hour().minute())
                }
            }
        }
    }
}
