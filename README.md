# REBAR - AutoCAD LISP Donatı Yerleştirme Sistemi

## 📋 Genel Bakış

**REBAR**, AutoCAD ortamında TS 500 ve TBDY 2018'e göre temel, kolon, perde, kiriş ve döşeme
donatısını çizen, kontrol eden ve metrajını çıkaran bir AutoLISP uygulamasıdır.

- Çizim birimi: **1 birim = 1 cm**
- Çaplar: 8–32 mm (boyuna), 6–16 mm (etriye/çiroz)
- Çelik: S220, S420, B420C, B500C — Beton: C20…C50 (`REBAR-AYAR` komutu)

## 📁 Dosya Yapısı

```
REBAR-Ana.lsp      ; Ana yükleyici + REBAR menüsü (diğer dosyaları yükler)
REBAR-Ortak.lsp    ; Ortak kütüphane: veri, giriş, çizim, kontroller, metraj tablosu
REBAR-Temel.lsp    ; Tekil / sürekli / radye temel (plan)
REBAR-Kolon.lsp    ; Kolon (kesit) ve perde (kesit)
REBAR-Kiris.lsp    ; Kiriş (boyuna görünüş + enine kesit)
REBAR-Doseme.lsp   ; Tek / çift doğrultulu döşeme (plan)
ACAD.LSP           ; acaddoc.lsp'ye eklenecek otomatik yükleme örneği
tests/             ; AutoCAD olmadan çalışan AutoLISP simülatörü ve testler
```

Her modül tek başına da yüklenebilir; `REBAR-Ortak.lsp` yüklü değilse onu kendisi yükler.

## 🚀 Kurulum

1. Tüm `.lsp` dosyalarını bir klasöre kopyalayın.
2. AutoCAD: `OPTIONS` → `Files` → `Support File Search Path` → bu klasörü ekleyin.
3. `APPLOAD` ile **sadece `REBAR-Ana.lsp`** dosyasını yükleyin (diğerlerini o yükler).
4. Her çizimde otomatik yüklemek için `ACAD.LSP` içindeki satırları kendi `acaddoc.lsp`
   dosyanıza ekleyin (mevcut dosyanızın üzerine yazmayın).

> **Türkçe karakterler:** Dosyalar UTF-8 kaydedilmiştir. AutoCAD 2021+ sürümlerinde
> `LISPSYS` = 1 ile sorunsuz çalışır. Eski sürümlerde komut satırı mesajlarında
> Türkçe karakterler bozuk görünürse dosyaları Windows-1254 (ANSI) olarak kaydedin.
> Çizimdeki çap işareti için AutoCAD'in standart `%%c` kodu kullanılır.

## 🎨 Komutlar

| Komut | Kısaltmalar | Açıklama |
|-------|-------------|----------|
| `REBAR` | `REBAR-MENU` | Ana menü |
| `REBAR-FOOTING` | `RT`, `TEMEL`, `RFT` | Temel donatısı |
| `REBAR-COLUMN` | `RK`, `RC`, `KOLON` | Kolon donatısı |
| `REBAR-WALL` | `RP`, `RW`, `PERDE` | Perde donatısı |
| `REBAR-BEAM` | `RB`, `KIRIS` | Kiriş donatısı |
| `REBAR-SLAB` | `RD`, `RS`, `DOSEME`, `DOSME` | Döşeme donatısı |
| `REBAR-AYAR` | – | Beton/çelik sınıfı ve yazı yüksekliği |

Tüm sorularda **Enter** varsayılan değeri kabul eder. Her komut tek bir `U` (geri al)
ile tamamen geri alınabilir; `Esc` ile iptal güvenlidir.

### Örnek: Temel

```
Komut: RT
Temel tipi [Tekil/Surekli/Radye] <Tekil>:
Temel sol-alt köşe noktasını seçiniz: (nokta)
Temel genişliği - X yönü (cm) <150>:
Temel uzunluğu - Y yönü (cm) <150>:
Temel yüksekliği (cm) <60>:
Paspayı (cm) <5>:
--- Alt Donatı ---
Alt X donatısı çapı (mm) [8/10/12/.../32] <14>:
Alt X donatısı aralığı (cm) <15>:
Alt Y donatısı çapı (mm) [8/10/12/.../32] <14>:
Alt Y donatısı aralığı (cm) <15>:
Üst donatı ağı (çift kat) eklensin mi? [Evet/Hayir] <Hayir>:
--- TS 500 Kontrolleri ---
  [OK]    Paspayı 5 cm >= 5 cm (TS 500 7.3)
  [OK]    Alt X donatı oranı %0.17 >= %0.15
  ...
Donatı çizilsin mi? [Evet/Hayir] <Evet>:
--- Donatı Metrajı ---
  Poz 1.1  Alt X  Ø14  10 ad.  L=1.40 m  16.94 kg
  Poz 1.2  Alt Y  Ø14  10 ad.  L=1.40 m  16.94 kg
  TOPLAM: 33.88 kg
Donatı metraj tablosu çizilsin mi? [Evet/Hayir] <Evet>:
```

## 📐 Ne Çizilir?

| Eleman | Görünüş | İçerik |
|--------|---------|--------|
| Temel | Plan | Kalıp, alt ağ (düz), üst ağ (kesikli), etiketler, ölçüler, metraj |
| Kolon | Kesit | Kalıp, etriye, boyuna çubuklar (gerçek çapta), çirozlar; dikdörtgen/kare/dairesel |
| Perde | Kesit | İki yüzde yatay çubuklar ve düşey çubuklar |
| Kiriş | Görünüş + kesit | Alt/üst donatı, uçlarda sıklaştırılmış etriyeler (2h), enine kesit; herhangi bir açıyla |
| Döşeme | Plan | Alt ağ, opsiyonel üst ağ; tek doğrultuluda ana + dağıtma donatısı |

## ✅ Kontroller (uyarı niteliğinde)

| Kontrol | Değer |
|---------|-------|
| Min. paspayı (cm) | Temel 5.0, Kolon 2.5, Kiriş 2.5, Perde 2.0, Döşeme 1.5; ayrıca ≥ Ø |
| Plak/temel ρmin (her doğrultu) | 0.002 (S220), 0.0015 (diğer) |
| Kiriş ρmin / ρmax | 0.8·fctd/fyd / %2 |
| Kolon ρ | %1 – %4, net aralık ≥ max(1.5Ø, 4 cm), kısa kenar ≥ 30 cm |
| Kolon etriye | Sarılma bölgesi max(bmax, Hn/6, 50 cm); s ≤ min(bmin/3, 15, 6Ø); orta s ≤ min(12Ø, bmin, 20) |
| Kiriş etriye | Sarılma bölgesi 2h; s ≤ min(h/4, 8Ø, 15); orta s ≤ d/2 |
| Perde | ρ ≥ 0.0025 her doğrultu, s ≤ 25 cm, t ≥ 20 cm ve ≥ H/20 |
| Döşeme | h ≥ 8 cm, s ≤ min(1.5h, 20/25), dağıtma ≥ ana/5, ly/lx oranına göre tip uyarısı |

Değerler `REBAR-Ortak.lsp` içindeki tablolarda toplanmıştır; projenize ve yönetmeliğin
güncel metnine göre doğrulayın. Program bir tasarım aracı değil, çizim/metraj yardımcısıdır.

## 🎨 Katmanlar

| Katman | Renk | Açıklama |
|--------|------|----------|
| REBAR-FOOTING / -BOT / -TOP | 1 / 3 / 2 (kesikli) | Temel kalıp / alt / üst donatı |
| REBAR-COLUMN / -BOYUNA / -ETRIYE | 4 / 1 / 6 | Kolon kalıp / boyuna / etriye-çiroz |
| REBAR-WALL / -DIKEY / -YATAY | 4 / 3 / 2 | Perde |
| REBAR-BEAM / -BOT / -TOP / -ETRIYE | 2 / 3 / 2 / 6 | Kiriş |
| REBAR-SLAB / -BOT / -TOP | 5 / 3 / 5 (kesikli) | Döşeme |
| REBAR-TEXT, REBAR-TABLE, REBAR-DIM | 7, 7, 8 | Yazı, tablo, ölçü |

Donatı çizgileri çapa göre renklendirilir (Ø8 kırmızı, Ø10 sarı, Ø12 yeşil, Ø14 cyan, Ø16 mavi, ...).

## 🔧 Donatı Ağırlıkları

| Çap (mm) | 6 | 8 | 10 | 12 | 14 | 16 | 18 | 20 | 22 | 24 | 26 | 28 | 30 | 32 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| kg/m | 0.222 | 0.395 | 0.617 | 0.888 | 1.210 | 1.580 | 2.000 | 2.470 | 2.980 | 3.550 | 4.170 | 4.830 | 5.550 | 6.310 |

## 🧪 Testler

AutoCAD olmadan, Python 3 ile:

```bash
python3 tests/autolisp_sim.py      # sözdizimi / statik kontrol
python3 tests/test_rebar.py        # komut senaryoları
```

`tests/autolisp_sim.py` küçük bir AutoLISP yorumlayıcısıdır (dinamik kapsam, tamsayı bölmesi,
büyük/küçük harf duyarsız semboller) ve `entmake`, `getXXX`, `vla-*` gibi AutoCAD
fonksiyonlarını taklit eder. Gerçek AutoCAD testinin yerini tutmaz.

## 📝 Sürüm Geçmişi

### v2.0
- Tüm modüller geçerli AutoLISP ile yeniden yazıldı (önceki sürümde AutoLISP'te olmayan
  `let`, `let*`, `dotimes`, `int`, `:anahtar` listeleri kullanılıyordu; dosyalar yüklenemiyordu).
- Parantez hataları giderildi; ortak kod `REBAR-Ortak.lsp`'ye toplandı, komut çakışmaları
  (`RK`, `TEMEL`) ve yerleşik fonksiyonların (`angle`, `length`, `type`) ezilmesi düzeltildi.
- Çizimler `entmake` ile (OSNAP'tan bağımsız); kolon ve kiriş artık kesit/görünüş olarak doğru çiziliyor.
- Hatalı kontroller düzeltildi (ör. aralık sınırı Ø'nin 2 katı = 2.4 cm idi, oranlar plan alanına göre hesaplanıyordu).
- Etriye sıklaştırma, çiroz, kanca boyları, metraj tablosu, geri alma ve `Esc` güvenliği eklendi.
- `R` kısaltması kaldırıldı (AutoCAD'in REDRAW kısaltmasıyla çakışıyordu).

### v1.0 (2024)
- İlk sürüm

## 📜 Lisans

Ücretsiz ve açık kaynaklıdır.
