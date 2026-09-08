# Alarm motoru düzeltme planı

**Hedef:** [tasarımdaki](../specs/2026-09-08-alarm-engine-design.md) görev, silme, plan yenileme ve tanı kontratlarını uygulamak.

**Çalışma:** Kullanıcı tasarım ve implementasyonu birlikte istedi. Inline; ayrı agent/worktree yok. `dev` üzerinde atomik yerel commit'ler; release/push yok.

## 1. Native görev ve tanı temeli

- [x] RED: süresi geçmiş snooze, cold fallback kimliği, yinelenen/eski callback, native snapshot ve journal sınırı testleri.
- [x] Store'a geriye uyumlu çalış/timer takibi ve snapshot ekle; snooze tarihini doğru temizle.
- [x] iOS Stop / Open intent'lerini ayır; TR/EN/AR native aksiyon metinleri.
- [x] OS adaptörü olan native motor ve yeni nöbetçiyi önce kuran güvenli değişim.
- [x] Release logger filtresi ve kalıcı, sınırlı native journal.

## 2. Plan ve explicit silme

- [x] RED: değişmeyen plan korunur, replacement hatası eski planı bırakır, tüm köklerin yakın alarmı önceliklidir, active/delete ve cache yokluğu.
- [x] Tipli Dart planı; planner/CRUD/iptal kuyruğu; native diff uzlaştırması.
- [x] Android plan kontratı ve native durum koruması.
- [x] Kısmi cache için eksik kaynak günlerini koru; bilinen günleri güncelle ve explicit skip/delete önceliğini doğrula.
- [x] Silme/pasifleştirme hatalarında doğru UI/Retry; debounce yalnız normal plan yenilemesine uygulanır.

## 3. Snapshot tabanlı görev ekranları

- [x] RED: iki ertelenen alarm ayrı kalır, olay tüketilmez, native son tarih kullanılır, eski çalış komutu yeni güne dokunmaz.
- [x] Coordinator native snapshot'ı esas alır; AppState tüm bekleyen görevleri taşır.
- [x] Launcher ve satırların kendi çalışını seçmesi; Android/iOS action kontratı.
- [x] Cold start, resume ve foreground event akışını tek ekran korumasıyla doğrula.

## 4. Bütünlük ve teslim

- [x] Inline code review: arıza/iptal yarışı, eski veri migration'ı, logger'da hassas veri, API doğrulaması.
- [x] `dart format`, l10n üretimi, `flutter analyze`, ilgili ve tüm Flutter suite'i.
- [x] iOS native testleri, Android native testleri; iki platform debug build'i.
- [x] Simulator aksiyon testini dene; görüntü servisi zaman aşımı ve gerçek cihaz doğrulaması sınırını kaydet.
- [x] Tasarım/plan ve doğrulama kaydını güncelle.

## Fiziksel cihaz kabulü

- [ ] Yeni build ile kilitli/kapalı uygulama, QR, erteleme ve silme senaryolarını iPhone'da doğrula. Bu adım simulator/unit sonuçlarıyla tamamlanmış sayılmaz.

Sonuçlar: [doğrulama kaydı](../../investigations/2026-09-08-alarm-engine-verification.md).
