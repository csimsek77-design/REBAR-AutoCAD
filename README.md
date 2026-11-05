# REBAR - AutoCAD LISP Donatı Yerleştirme Sistemi

## 📋 Genel Bakış

**REBAR**, AutoCAD ortamında Türkiye standartlarına (TS 500) göre donatı yerleştirme işlemlerini otomatikleştiren bir LISP uygulamasıdır. 8mm'den 32mm'ye kadar tüm standart donatı çaplarını destekler.

## 🎯 Özellikler

### ✅ Temel Özellikler
- **Türkiye Standartları**: TS 500'e uygun minimum donatı oranları ve paspayı kontrolleri
- **Standart Çaplar**: 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32 mm
- **Donatı Sınıfları**: S220, S420, B420C, B500C
- **Otomatik Katman Yönetimi**: Farklı donatı tipleri için ayrı katmanlar
- **Renklendirme**: Farklı çaplar için farklı renkler

### ✅ Desteklenen Elemanlar
1. **Temel Donatı** (REBAR-Temel.lsp)
   - Tekil temel
   - Sürekli temel
   - Raft temel
   - Çift katmanlı donatı

2. **Kolon Donatı** (REBAR-Kolon.lsp)
   - Kare kolon
   - Dikdörtgen kolon
   - Dairesel kolon
   - Boyuna donatı
   - Etriye donatı

3. **Perde Donatı** (REBAR-Kolon.lsp)
   - Yatay ve dikey donatılar
   - Etriye donatı (opsiyonel)

4. **Kiriş Donatı** (REBAR-Kiris.lsp)
   - Dikdörtgen kiriş
   - T kiriş
   - L kiriş
   - Kutu kiriş
   - Alt ve üst donatı
   - Etriye donatı

5. **Döşeme Donatı** (REBAR-Doseme.lsp)
   - Tek doğrultulu döşeme
   - Çift doğrultulu döşeme
   - Nervürlü döşeme
   - Kirişsiz döşeme

### ✅ Ek Özellikler
- **Minimum Donatı Kontrolü**: TS 500'e göre otomatik kontrol
- **Paspayı Kontrolü**: Minimum 2.5cm ve çapın 1.5 katı
- **Aralık Kontrolü**: Maksimum 30cm ve 2x çap
- **Ağırlık Hesaplaması**: Toplam donatı ağırlığı
- **Donatı Listesi**: Otomatik tablo oluşturma
- **Boyut Çizgileri**: Otomatik boyutlandırma
- **Etiketleme**: Donatı bilgileri etiketleri

## 📁 Dosya Yapısı

```
REBAR/
├── REBAR-Ana.lsp          ; Ana yükleyici ve menü sistemi
├── REBAR-Temel.lsp        ; Temel donatı modülü
├── REBAR-Kolon.lsp        ; Kolon ve perde donatı modülü
├── REBAR-Kiris.lsp        ; Kiriş donatı modülü
├── REBAR-Doseme.lsp       ; Döşeme donatı modülü
└── README.md              ; Bu dosya
```

## 🚀 Kurulum

### Yöntem 1: Manuel Yükleme
1. Tüm LISP dosyalarını (`REBAR-*.lsp`) bir klasöre kopyalayın
2. AutoCAD'i açın
3. Komut satırına `APPLOAD` yazın
4. Dosyaları seçin ve yükleyin

### Yöntem 2: Otomatik Yükleme (Önerilen)
1. Dosyaları AutoCAD'in otomatik yüklediği bir klasöre yerleştirin:
   - `C:\Users\<Kullanıcı>\AppData\Roaming\Autodesk\AutoCAD <Sürüm>\Support\`
   - `C:\Program Files\Autodesk\AutoCAD <Sürüm>\Support\`
2. AutoCAD'i yeniden başlatın

### Yöntem 3: REBAR-Ana.lsp Yükleme
Sadece `REBAR-Ana.lsp` dosyasını yükleyin, diğer modülleri otomatik olarak yükleyecektir.

## 🎨 Kullanım

### Komut Listesi

| Komut | Açıklama | Kısaltma |
|-------|----------|----------|
| `REBAR` | Ana menü | `R` |
| `REBAR-FOOTING` | Temel donatı | `RT`, `TEMEL` |
| `REBAR-COLUMN` | Kolon donatı | `RK`, `KOLON` |
| `REBAR-WALL` | Perde donatı | `RP`, `PERDE` |
| `REBAR-BEAM` | Kiriş donatı | `RB`, `KIRIS` |
| `REBAR-SLAB` | Döşeme donatı | `RD`, `DOSME` |

### Temel Kullanım Adımları

1. **Komut Girin**: `REBAR` (ana menü) veya doğrudan bir modül komutu
2. **Eleman Tipi Seçin**: Temel, Kolon, Perde, Kiriş veya Döşeme
3. **Boyutları Girin**: Elemanın genişlik, uzunluk, yükseklik/kalınlık
4. **Donatı Parametreleri**: Çap, aralık, paspayı
5. **Onaylayın**: Donatı yerleştirilsin mi?
6. **Sonuç**: Donatılar çizilir ve etiketlenir

### Örnek: Temel Donatı Yerleştirme

```
Komut: REBAR-FOOTING

--- Temel Tipi ve Boyutları ---
Temel tipi [Tekil/Sürekli/Raft] <Tekil>: Tekil
Temel köşe noktasını seçiniz: (nokta seçin)
Temel genişliğini giriniz (cm): <100>: 120
Temel uzunluğunu giriniz (cm): <100>: 150
Temel yüksekliğini giriniz (cm): <50>: 60

--- X Doğrultusu Donatı (Boyuna) ---
X doğrultusu donatı çapı [8/10/12/14/16/18/20/22/24/26/28/30/32] <12>: 16
X doğrultusu donatı aralığı (cm): <20>: 15

--- Y Doğrultusu Donatı (Enine) ---
Y doğrultusu donatı çapı [8/10/12/14/16/18/20/22/24/26/28/30/32] <12>: 12
Y doğrultusu donatı aralığı (cm): <20>: 20

--- Diğer Parametreler ---
Paspayı mesafesi (cm): <4>: 4
Katman sayısı [1/2] <1>: 2

--- Parametre Kontrolü ---
Paspayı kontrolü: BAŞARILI (4.0 cm >= 2.5 cm)
X doğrultusu minimum donatı kontrolü: BAŞARILI
Y doğrultusu minimum donatı kontrolü: BAŞARILI

--- Ön İzleme ---
Temel Tipi: Tekil
Temel: 120.0×150.0×60.0 cm
X Donatı: Ø16 - 15.0 cm aralık
Y Donatı: Ø12 - 20.0 cm aralık
Paspayı: 4.0 cm
Katman: 2

Donatı yerleştirilsin mi? [Evet/Hayır] <Evet>:
```

## 🎨 Katmanlar ve Renkler

| Katman Adı | Renk | Açıklama |
|------------|------|----------|
| REBAR-FOOTING | Kırmızı (1) | Temel kalıpları |
| REBAR-FOOTING-TOP | Sarı (2) | Temel üst donatı |
| REBAR-FOOTING-BOT | Yeşil (3) | Temel alt donatı |
| REBAR-COLUMN | Cyan (4) | Kolon kalıpları |
| REBAR-COLUMN-ETRIYE | Magenta (6) | Kolon etriyeleri |
| REBAR-BEAM | Sarı (2) | Kiriş kalıpları |
| REBAR-BEAM-TOP | Sarı (2) | Kiriş üst donatı |
| REBAR-BEAM-BOT | Yeşil (3) | Kiriş alt donatı |
| REBAR-BEAM-ETRIYE | Magenta (6) | Kiriş etriyeleri |
| REBAR-SLAB | Mavi (5) | Döşeme kalıpları |
| REBAR-SLAB-TOP | Mavi (5) | Döşeme üst donatı |
| REBAR-SLAB-BOT | Yeşil (3) | Döşeme alt donatı |
| REBAR-TEXT | Mavi (5) | Etiketler |
| REBAR-TABLE | Beyaz (7) | Tablolar |
| REBAR-DIM | Gri (250) | Boyut çizgileri |

### Donatı Çap Renkleri

| Çap (mm) | Renk |
|----------|------|
| 8 | Kırmızı (1) |
| 10 | Sarı (2) |
| 12 | Yeşil (3) |
| 14 | Cyan (4) |
| 16 | Mavi (5) |
| 18 | Magenta (6) |
| 20 | Beyaz (7) |
| 22+ | Açık renkler (10-15) |

## 📊 TS 500 Minimum Donatı Oranları

| Eleman Tipi | Minimum Oran (%) |
|-------------|------------------|
| Temel | 0.8‰ (0.008) |
| Kolon | 1.0‰ (0.010) |
| Kiriş | 0.8‰ (0.008) |
| Döşeme | 0.2‰ (0.002) |
| Perde | 0.4‰ (0.004) |

## 🔧 Donatı Ağırlıkları (kg/m)

| Çap (mm) | Ağırlık (kg/m) | Alan (cm²) |
|----------|----------------|------------|
| 8 | 0.395 | 0.503 |
| 10 | 0.617 | 0.785 |
| 12 | 0.888 | 1.131 |
| 14 | 1.210 | 1.540 |
| 16 | 1.580 | 2.011 |
| 18 | 2.000 | 2.545 |
| 20 | 2.470 | 3.142 |
| 22 | 2.980 | 3.801 |
| 24 | 3.550 | 4.524 |
| 26 | 4.170 | 5.309 |
| 28 | 4.830 | 6.158 |
| 30 | 5.550 | 7.069 |
| 32 | 6.310 | 8.042 |

## 📝 Sürüm Geçmişi

### v1.0 (2024)
- İlk sürüm
- Temel, Kolon, Perde, Kiriş, Döşeme donatı desteği
- TS 500 standartlarına uygun kontrol
- Otomatik katman ve renklendirme
- Ağırlık hesaplaması
- Donatı listesi tablosu

## 🤝 Katkıda Bulunma

1. Hata bulduğunuzda lütfen bildirin
2. Önerilerinizi paylaşın
3. Yeni özellikler ekleyin

## 📜 Lisans

Bu yazılım **ücretsiz ve açık kaynaklıdır**. Ticari veya kişisel kullanım için serbestçe kullanabilirsiniz.

## 🙏 Teşekkürler

- Türkiye İnşaat Mühendisleri Odası (TMO)
- TS 500 Betonarme Yönetmeliği
- AutoCAD LISP Geliştiricileri Topluluğu

---

**Geliştirici Notu:** Bu LISP uygulaması, AutoCAD 2010 ve üzeri sürümlerde test edilmiştir. Daha eski sürümlerde bazı fonksiyonlar çalışmayabilir.
