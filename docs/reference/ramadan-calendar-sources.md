# Ramazan dönemlerinin kaynakları

Doğrulama: 6 Eylül 2026. Ay sınırları Diyanet İşleri Başkanlığı Vakit Hesaplama sayfalarından alınmıştır. Bayramın ilk günü aralığa dahil değildir.

| Hicri yıl | İlk oruç günü | Bayramın ilk günü | Gün | Kaynak |
|---|---|---|---:|---|
| 1445 | 2024-03-11 | 2024-04-10 | 30 | [2024](https://vakithesaplama.diyanet.gov.tr/dinigunler.php?yil=2024) |
| 1446 | 2025-03-01 | 2025-03-30 | 29 | [2025](https://vakithesaplama.diyanet.gov.tr/dinigunler.php?yil=2025) |
| 1447 | 2026-02-19 | 2026-03-20 | 29 | [2026](https://vakithesaplama.diyanet.gov.tr/dinigunler.php?yil=2026) |
| 1448 | 2027-02-08 | 2027-03-09 | 29 | [2027](https://vakithesaplama.diyanet.gov.tr/icerik.php?icerik=154) |
| 1449 | 2028-01-28 | 2028-02-26 | 29 | [2028](https://vakithesaplama.diyanet.gov.tr/icerik.php?icerik=185) |
| 1450 | 2029-01-16 | 2029-02-14 | 29 | [2029](https://vakithesaplama.diyanet.gov.tr/icerik.php?icerik=186) |
| 1451 | 2030-01-05 | 2030-02-04 | 30 | [2030](https://vakithesaplama.diyanet.gov.tr/icerik.php?icerik=187) |
| 1452 | 2030-12-26 | 2031-01-24 | 29 | [Başlangıç](https://vakithesaplama.diyanet.gov.tr/icerik.php?icerik=187), [bayram](https://vakithesaplama.diyanet.gov.tr/icerik.php?icerik=188) |

Katalog bu sekiz dönemi kapsar; Aralık 2031'de başlayan 1453 dönemi dahil değildir. Yeni dönem eklerken başlangıç ve bayramı doğrudan kaynakta doğrula; başlangıç ve bitiş farklı miladi yıllardaysa iki sayfayı da kaydet. Aynı miladi yılda iki Ramazan başlayabilir (2030 örneği), bu nedenle dönem kimliği hicri yıldır. Gün sayısı 29 veya 30 olmalı ve takvim günü üzerinden hesaplanmalıdır.

Uygulamadaki saat kaynağı **Aladhan API**'dir; konum, hesaplama yöntemi ve kullanıcının vakit düzeltmeleri geçerlidir. “Diyanet yöntemi” seçmek bu saatleri Diyanet'in yayımladığı resmî saat verisine dönüştürmez. UI ve paylaşım bu ayrımı korumalıdır.

[Diyanet Awqat Salah API](https://awqatsalah.diyanet.gov.tr/index.html) başvuruyla erişim sağlar; bu değişiklik yeni erişim hesabı veya provider değişimi içermez. Mevcut `hijri` paketinin hesabı, bu kaynaklı katalog yerine resmî ay sınırı diye sunulmamalıdır.
