import AppIntents

extension WidgetAlignment: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Hizalama" }

    static var caseDisplayRepresentations: [WidgetAlignment: DisplayRepresentation] {
        [
            .leading: "Sola yaslı",
            .center: "Ortalı",
            .trailing: "Sağa yaslı",
        ]
    }
}

/// Widget'a uzun basıp "Widget'ı Düzenle" dendiğinde çıkan ayar.
struct EzanVaktiWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Ezan Vakti" }
    static var description: IntentDescription { "Sıradaki vakit ve geri sayım." }

    @Parameter(title: "Hizalama", default: .leading)
    var alignment: WidgetAlignment

    init() {}
}
