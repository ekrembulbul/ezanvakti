import UIKit

/// Bir metnin satır kutusunu büyük harf/rakam yüksekliğine indiren paylar.
///
/// Widget'ın alt bloğunda boşluklar göze eşit görünsün diye kutudan değil
/// mürekkepten ölçülür: üstte rakamın tepesine kadar boş kalan çıkıntı payı,
/// altta taban çizgisinin altındaki iniş payı. Görünüm bu payları negatif
/// `padding` ile düşer; eşit `Spacer`'lar kalan yüksekliği paylaşınca çizgi,
/// vakit satırı, sayaç ve alt sınır arası göze aynı gelir (2026-09-21).
struct InkInsets: Equatable {
    let top: CGFloat
    let bottom: CGFloat

    /// Sistem yazı tipinin (SF) ölçüleriyle; SwiftUI `Text` aynı ölçüleri kullanır.
    static func system(size: CGFloat, weight: UIFont.Weight) -> InkInsets {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        return InkInsets(top: font.ascender - font.capHeight, bottom: -font.descender)
    }
}
