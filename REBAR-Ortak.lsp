;;
;; REBAR-Ortak.lsp
;; ============================================
;; REBAR serisi ORTAK KÜTÜPHANE
;; Tüm modüller (Temel, Kolon/Perde, Kiriş, Döşeme) bu dosyayı kullanır.
;; ============================================
;; Sürüm: 2.0
;;
;; Notlar:
;; - Çizim birimi: 1 birim = 1 cm
;; - Tüm fonksiyonlar "rb:" ön ekiyle adlandırılmıştır; böylece başka
;;   LISP programlarıyla isim çakışması olmaz.
;; - Çizimler (entmake) ile yapılır; OSNAP ayarlarından etkilenmez.
;; - TS 500 / TBDY 2018 kontrolleri UYARI niteliğindedir. Değerler
;;   aşağıdaki tablolarda toplanmıştır; projenize göre doğrulayın.
;;

(vl-load-com)
(setq *rb:ortak-yuklendi* T)

;; ============================================
;; 1. VERİ TABLOLARI
;; ============================================

;; (çap_mm  ağırlık_kg/m  alan_cm2)
(setq *rb:donati-tablosu*
  '((6  0.222 0.283)
    (8  0.395 0.503)
    (10 0.617 0.785)
    (12 0.888 1.131)
    (14 1.210 1.539)
    (16 1.580 2.011)
    (18 2.000 2.545)
    (20 2.470 3.142)
    (22 2.980 3.801)
    (24 3.550 4.524)
    (26 4.170 5.309)
    (28 4.830 6.158)
    (30 5.550 7.069)
    (32 6.310 8.042)))

;; Boyuna donatı için izin verilen çaplar
(setq *rb:caplar* '(8 10 12 14 16 18 20 22 24 26 28 30 32))
;; Etriye / çiroz çapları
(setq *rb:etriye-caplari* '(6 8 10 12 14 16))

;; Çelik sınıfları: karakteristik akma dayanımı fyk (MPa)
(setq *rb:celikler* '(("S220" . 220.0) ("S420" . 420.0) ("B420C" . 420.0) ("B500C" . 500.0)))
;; Beton sınıfları (fck = "C" den sonraki sayı, MPa)
(setq *rb:betonlar* '("C20" "C25" "C30" "C35" "C40" "C45" "C50"))

;; Kullanıcı ayarları (REBAR-AYAR komutuyla değiştirilir).
;; Dosya yeniden yüklenince mevcut ayarlar korunur.
(if (not *rb:beton*) (setq *rb:beton* "C25"))
(if (not *rb:celik*) (setq *rb:celik* "B420C"))
(if (not *rb:yazi-h*) (setq *rb:yazi-h* 0.0))   ; 0 = otomatik

;; Minimum net beton örtüsü (paspayı, cm) - TS 500 Madde 7.3 (tipik değerler)
(setq *rb:min-paspayi*
  '(("TEMEL" . 5.0) ("KOLON" . 2.5) ("KIRIS" . 2.5) ("PERDE" . 2.0) ("DOSEME" . 1.5)))

;; Çap renkleri (çizimde farklı çaplar farklı renkte görünür)
(setq *rb:cap-renkleri*
  '((6 . 8) (8 . 1) (10 . 2) (12 . 3) (14 . 4) (16 . 5) (18 . 6) (20 . 7)
    (22 . 10) (24 . 11) (26 . 12) (28 . 13) (30 . 14) (32 . 15)))

;; Katman tanımları: (ad renk çizgi_tipi)
(setq *rb:katman-tanimlari*
  '(("REBAR-FOOTING"        1 "Continuous")
    ("REBAR-FOOTING-BOT"    3 "Continuous")
    ("REBAR-FOOTING-TOP"    2 "DASHED")
    ("REBAR-COLUMN"         4 "Continuous")
    ("REBAR-COLUMN-BOYUNA"  1 "Continuous")
    ("REBAR-COLUMN-ETRIYE"  6 "Continuous")
    ("REBAR-WALL"           4 "Continuous")
    ("REBAR-WALL-DIKEY"     3 "Continuous")
    ("REBAR-WALL-YATAY"     2 "Continuous")
    ("REBAR-BEAM"           2 "Continuous")
    ("REBAR-BEAM-TOP"       2 "Continuous")
    ("REBAR-BEAM-BOT"       3 "Continuous")
    ("REBAR-BEAM-ETRIYE"    6 "Continuous")
    ("REBAR-SLAB"           5 "Continuous")
    ("REBAR-SLAB-BOT"       3 "Continuous")
    ("REBAR-SLAB-TOP"       5 "DASHED")
    ("REBAR-TEXT"           7 "Continuous")
    ("REBAR-TABLE"          7 "Continuous")
    ("REBAR-DIM"            8 "Continuous")))

;; ============================================
;; 2. TEMEL YARDIMCILAR
;; ============================================

(defun rb:doc () (vla-get-ActiveDocument (vlax-get-acad-object)))

(defun rb:veri (cap) (assoc cap *rb:donati-tablosu*))
(defun rb:kg/m (cap / v) (if (setq v (rb:veri cap)) (cadr v) 0.0))
(defun rb:alan (cap / v) (if (setq v (rb:veri cap)) (caddr v) 0.0))
(defun rb:cm (mm) (/ mm 10.0))                     ; mm -> cm
(defun rb:renk (cap / r) (if (setq r (cdr (assoc cap *rb:cap-renkleri*))) r 7))
(defun rb:min-paspayi (eleman) (cdr (assoc eleman *rb:min-paspayi*)))

;; Malzeme
(defun rb:fck () (atof (substr *rb:beton* 2)))                       ; MPa
(defun rb:fyk () (cdr (assoc *rb:celik* *rb:celikler*)))              ; MPa
(defun rb:fctd () (/ (* 0.35 (sqrt (rb:fck))) 1.5))                   ; TS 500
(defun rb:fyd () (/ (rb:fyk) 1.15))
;; TS 500: kiriş çekme donatısı ρmin = 0.8 fctd / fyd
(defun rb:rho-min-kiris () (/ (* 0.8 (rb:fctd)) (rb:fyd)))
;; TS 500: plak/temel her doğrultuda ρmin (S220: 0.002, diğerleri: 0.0015)
(defun rb:rho-min-plak () (if (= *rb:celik* "S220") 0.002 0.0015))

;; Sayı biçimleme: tam sayıysa ondalıksız yazar
(defun rb:s (x / )
  (if (equal x (fix x) 1e-6) (itoa (fix x)) (rtos x 2 1)))
(defun rb:s2 (x) (rtos x 2 2))
(defun rb:yuzde (x) (strcat "%" (rtos (* 100.0 x) 2 2)))

;; Yukarı yuvarlama (pozitif sayılar)
(defun rb:tavan (x) (if (equal x (fix x) 1e-9) (fix x) (1+ (fix x))))

;; Belirli aralıkla sığan çubuk sayısı (uç çubuklar dahil)
(defun rb:adet (boy aralik)
  (if (< boy 0.0) 0 (1+ (fix (/ (+ boy 1e-6) aralik)))))

;; "bas" noktasından başlayan "boy" uzunluğundaki bölgeye "aralik" ile çubuk dizer.
;; Kalan pay iki uca eşit dağıtılır (çubuklar ortalanır). Konum listesi döndürür.
(defun rb:diz (bas boy aralik / n ofs i lst)
  (setq n (rb:adet boy aralik))
  (cond
    ((<= n 0) nil)
    ((= n 1) (list (+ bas (/ boy 2.0))))
    (T
     (setq ofs (+ bas (/ (- boy (* (1- n) aralik)) 2.0)) i 0)
     (repeat n (setq lst (cons (+ ofs (* i aralik)) lst) i (1+ i)))
     (reverse lst))))

;; bas ile son arasında (uçlar dahil) n adet eşit aralıklı konum
(defun rb:esit (bas son n / i lst)
  (if (< n 2)
    (list (/ (+ bas son) 2.0))
    (progn
      (setq i 0)
      (repeat n
        (setq lst (cons (+ bas (* i (/ (- son bas) (float (1- n))))) lst) i (1+ i)))
      (reverse lst))))

;; Otomatik yazı yüksekliği (eleman boyutuna göre)
(defun rb:yh (boyut)
  (if (> *rb:yazi-h* 0.0) *rb:yazi-h* (max 2.0 (/ (fix (* (/ boyut 50.0) 2.0)) 2.0))))

;; ============================================
;; 3. KOORDİNAT SİSTEMİ (yerel -> dünya)
;; ============================================
;; Modüller çizimi yerel (x y) koordinatlarda yapar; rb:lp bunu dünya
;; koordinatına çevirir. Böylece kiriş gibi elemanlar herhangi bir açıyla
;; çizilebilir.

(setq *rb:baz* '(0.0 0.0 0.0) *rb:aci* 0.0)

;; UCS X ekseninin dünya düzlemindeki açısı
(defun rb:ucs-aci () (angle '(0.0 0.0 0.0) (getvar "UCSXDIR")))

;; Kullanıcı (UCS) noktası -> dünya (WCS)
(defun rb:wcs (p) (trans p 1 0))

;; Yerel sistemi kur: baz = dünya noktası, aci = dünya açısı (radyan)
(defun rb:koord (baz aci)
  (setq *rb:baz* (list (car baz) (cadr baz) (if (caddr baz) (caddr baz) 0.0))
        *rb:aci* aci))

(defun rb:lp (x y / c s)
  (setq c (cos *rb:aci*) s (sin *rb:aci*))
  (list (+ (car *rb:baz*) (- (* x c) (* y s)))
        (+ (cadr *rb:baz*) (+ (* x s) (* y c)))
        (caddr *rb:baz*)))

(defun rb:2d (p) (list (car p) (cadr p)))

;; ============================================
;; 4. KATMAN VE ÇİZGİ TİPİ
;; ============================================

;; Çizgi tipini yükle; yüklenemezse "Continuous" döndür
(defun rb:cizgi-tipi (ad / lts)
  (if (and (/= (strcase ad) "CONTINUOUS") (not (tblsearch "LTYPE" ad)))
    (progn
      (setq lts (vla-get-Linetypes (rb:doc)))
      (foreach f '("acadiso.lin" "acad.lin")
        (if (not (tblsearch "LTYPE" ad))
          (vl-catch-all-apply 'vla-Load (list lts ad f))))))
  (if (or (= (strcase ad) "CONTINUOUS") (tblsearch "LTYPE" ad)) ad "Continuous"))

(defun rb:katman (ad renk lt)
  (if (not (tblsearch "LAYER" ad))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 ad) '(70 . 0) (cons 62 renk) (cons 6 (rb:cizgi-tipi lt)))))
  ad)

;; Tanım tablosundaki katmanları oluştur
(defun rb:katmanlari-hazirla (adlar / k)
  (foreach ad adlar
    (if (setq k (assoc ad *rb:katman-tanimlari*))
      (rb:katman (car k) (cadr k) (caddr k))
      (rb:katman ad 7 "Continuous"))))

;; ============================================
;; 5. ÇİZİM FONKSİYONLARI (yerel koordinat)
;; ============================================

(defun rb:ek-ozellik (renk)
  (if renk (list (cons 62 renk))))

;; Çizgi: p1, p2 yerel (x y)
(defun rb:cizgi (p1 p2 katman renk)
  (entmake (append (list '(0 . "LINE") (cons 8 katman))
                   (rb:ek-ozellik renk)
                   (list (cons 10 (rb:lp (car p1) (cadr p1)))
                         (cons 11 (rb:lp (car p2) (cadr p2)))))))

;; Polyline: noktalar yerel (x y)
(defun rb:pline (pts kapali katman renk / w)
  (entmake
    (append
      (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") (cons 8 katman))
      (rb:ek-ozellik renk)
      (list '(100 . "AcDbPolyline")
            (cons 90 (length pts))
            (cons 70 (if kapali 1 0))
            (cons 38 (caddr *rb:baz*)))
      (mapcar '(lambda (p) (cons 10 (rb:2d (rb:lp (car p) (cadr p))))) pts))))

;; Dikdörtgen: sol-alt (x y), genişlik g, yükseklik y
(defun rb:dikdortgen (x y g yuk katman renk)
  (rb:pline (list (list x y) (list (+ x g) y) (list (+ x g) (+ y yuk)) (list x (+ y yuk)))
            T katman renk))

;; Daire (boş)
(defun rb:daire (cx cy r katman renk)
  (entmake (append (list '(0 . "CIRCLE") (cons 8 katman))
                   (rb:ek-ozellik renk)
                   (list (cons 10 (rb:lp cx cy)) (cons 40 r)))))

;; Kesitte donatı çubuğu: gerçek çapta dolu daire
(defun rb:cubuk (cx cy cap katman / r p1 p2)
  (setq r  (/ cap 20.0)                       ; yarıçap (cm)
        p1 (rb:2d (rb:lp (- cx (/ r 2.0)) cy))
        p2 (rb:2d (rb:lp (+ cx (/ r 2.0)) cy)))
  (entmake (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") (cons 8 katman)
                 (cons 62 (rb:renk cap))
                 '(100 . "AcDbPolyline") '(90 . 2) '(70 . 1)
                 (cons 38 (caddr *rb:baz*)) (cons 43 r)
                 (cons 10 p1) '(42 . 1.0)
                 (cons 10 p2) '(42 . 1.0))))

;; Yazı (orta-merkez hizalı). aci: yerel açı (radyan)
(defun rb:yazi (x y metin h aci katman / p)
  (setq p (rb:lp x y))
  (entmake (list '(0 . "TEXT") (cons 8 katman)
                 (cons 10 p) (cons 11 p) (cons 40 h) (cons 1 metin)
                 (cons 50 (+ *rb:aci* aci))
                 '(72 . 1) '(73 . 2))))

;; Sol hizalı yazı (metraj listesi için)
(defun rb:yazi-sol (x y metin h katman / p)
  (setq p (rb:lp x y))
  (entmake (list '(0 . "TEXT") (cons 8 katman)
                 (cons 10 p) (cons 11 p) (cons 40 h) (cons 1 metin)
                 (cons 50 *rb:aci*) '(72 . 0) '(73 . 2))))

;; Aktif çizim alanı (model / kağıt)
(defun rb:aktif-alan (/ doc)
  (setq doc (rb:doc))
  (if (and (= (getvar "TILEMODE") 0) (= (getvar "CVPORT") 1))
    (vla-get-PaperSpace doc)
    (vla-get-ModelSpace doc)))

;; Hizalı ölçü. p1 p2 yerel; ofs < 0 -> ölçü çizgisi p1->p2 yönünün SAĞINA
(defun rb:olcu (p1 p2 ofs h / dx dy l nx ny w1 w2 wm sonuc)
  (setq dx (- (car p2) (car p1)) dy (- (cadr p2) (cadr p1))
        l  (sqrt (+ (* dx dx) (* dy dy))))
  (if (> l 1e-6)
    (progn
      (setq nx (/ (- dy) l) ny (/ dx l)
            w1 (rb:lp (car p1) (cadr p1))
            w2 (rb:lp (car p2) (cadr p2))
            wm (rb:lp (+ (/ (+ (car p1) (car p2)) 2.0) (* nx ofs))
                      (+ (/ (+ (cadr p1) (cadr p2)) 2.0) (* ny ofs))))
      (setq sonuc
        (vl-catch-all-apply 'vla-AddDimAligned
          (list (rb:aktif-alan) (vlax-3d-point w1) (vlax-3d-point w2) (vlax-3d-point wm))))
      (if (not (vl-catch-all-error-p sonuc))
        (progn
          (vl-catch-all-apply 'vla-put-Layer (list sonuc "REBAR-DIM"))
          ;; ölçü yazısını çizimdeki yazı yüksekliğine ölçekle (ISO DIMTXT=2.5)
          (vl-catch-all-apply 'vla-put-ScaleFactor (list sonuc (/ h 2.5)))))))
  (princ))

;; ============================================
;; 6. KULLANICI GİRİŞİ
;; ============================================

;; Pozitif ondalık sayı; Enter -> varsayılan
(defun rb:sayi-al (mesaj vars / v)
  (initget 6)
  (setq v (getreal (strcat "\n" mesaj " <" (rb:s vars) ">: ")))
  (if v (float v) (float vars)))

;; Pozitif tam sayı (en az enaz); Enter -> varsayılan
(defun rb:tamsayi-al (mesaj vars enaz / v tamam)
  (while (not tamam)
    (initget 6)
    (setq v (getint (strcat "\n" mesaj " <" (itoa vars) ">: ")))
    (if (null v) (setq v vars))
    (if (< v enaz)
      (princ (strcat "\nEn az " (itoa enaz) " olmalıdır."))
      (setq tamam T)))
  v)

;; Listeden çap seçimi; Enter -> varsayılan
(defun rb:cap-al (mesaj vars izinli / v tamam liste)
  (setq liste "")
  (foreach c izinli
    (setq liste (strcat liste (if (= liste "") "" "/") (itoa c))))
  (while (not tamam)
    (initget 6)
    (setq v (getint (strcat "\n" mesaj " [" liste "] <" (itoa vars) ">: ")))
    (if (null v) (setq v vars))
    (if (member v izinli)
      (setq tamam T)
      (princ (strcat "\nGeçersiz çap: " (itoa v) ". Listeden seçiniz."))))
  v)

;; Anahtar kelime seçimi. kelimeler: "Tekil Surekli Radye"
(defun rb:secenek-al (mesaj kelimeler vars / v)
  (initget kelimeler)
  (setq v (getkword (strcat "\n" mesaj " [" (rb:bosluk->egik kelimeler) "] <" vars ">: ")))
  (if v v vars))

(defun rb:bosluk->egik (s / i c sonuc)
  (setq sonuc "" i 1)
  (while (<= i (strlen s))
    (setq c (substr s i 1)
          sonuc (strcat sonuc (if (= c " ") "/" c))
          i (1+ i)))
  sonuc)

;; Evet/Hayır; Enter -> varsayılan (vars-evet T ise Evet)
(defun rb:evet-mi (mesaj vars-evet / v)
  (initget "Evet Hayir")
  (setq v (getkword (strcat "\n" mesaj " [Evet/Hayir] <" (if vars-evet "Evet" "Hayir") ">: ")))
  (cond ((null v) vars-evet)
        ((= v "Evet") T)
        (T nil)))

;; Çap + aralık birlikte
(defun rb:cap-aralik-al (baslik vcap varalik)
  (list (rb:cap-al (strcat baslik " çapı (mm)") vcap *rb:caplar*)
        (rb:sayi-al (strcat baslik " aralığı (cm)") varalik)))

;; ============================================
;; 7. KONTROLLER VE UYARILAR
;; ============================================

(setq *rb:uyarilar* nil)

;; sart T ise [OK], değilse [UYARI] yazar ve uyarı listesine ekler
(defun rb:kontrol (sart mesaj)
  (if sart
    (princ (strcat "\n  [OK]    " mesaj))
    (progn
      (princ (strcat "\n  [UYARI] " mesaj))
      (setq *rb:uyarilar* (cons mesaj *rb:uyarilar*))))
  sart)

;; Paspayı kontrolü: eleman minimumu ve en büyük çap
(defun rb:paspayi-kontrol (eleman c enbuyuk-cap / m)
  (setq m (max (rb:min-paspayi eleman) (rb:cm enbuyuk-cap)))
  (rb:kontrol (>= c m)
              (strcat "Paspayı " (rb:s c) " cm >= " (rb:s m) " cm (TS 500 7.3)")))

;; Çubuklar arası net aralık: s - Ø >= max(Ø, enaz)
(defun rb:net-aralik-kontrol (ad s cap enaz / net m)
  (setq net (- s (rb:cm cap))
        m   (max (rb:cm cap) enaz))
  (rb:kontrol (>= net (- m 1e-6))
              (strcat ad " net aralık " (rb:s2 net) " cm >= " (rb:s2 m) " cm")))

;; Azami aralık
(defun rb:max-aralik-kontrol (ad s smax)
  (rb:kontrol (<= s (+ smax 1e-6))
              (strcat ad " aralığı " (rb:s s) " cm <= " (rb:s2 smax) " cm")))

;; Minimum donatı oranı
(defun rb:oran-kontrol (ad rho rmin)
  (rb:kontrol (>= rho (- rmin 1e-9))
              (strcat ad " donatı oranı " (rb:yuzde rho) " >= " (rb:yuzde rmin))))

(defun rb:uyari-ozeti ()
  (if *rb:uyarilar*
    (alert (strcat (itoa (length *rb:uyarilar*))
                   " adet yönetmelik uyarısı var.\nAyrıntılar komut satırındadır."))))

;; ============================================
;; 8. METRAJ (DONATI LİSTESİ)
;; ============================================
;; Satır: (poz tanim cap adet boy_cm)

(defun rb:satir (poz tanim cap adet boy) (list poz tanim cap adet boy))

(defun rb:satir-kg (s)
  (* (nth 3 s) (/ (nth 4 s) 100.0) (rb:kg/m (nth 2 s))))

(defun rb:toplam-kg (satirlar / top)
  (setq top 0.0)
  (foreach s satirlar (setq top (+ top (rb:satir-kg s))))
  top)

;; Komut satırına metraj listesi yaz
(defun rb:metraj-yaz (satirlar)
  (princ "\n--- Donatı Metrajı ---")
  (foreach s satirlar
    (princ (strcat "\n  Poz " (car s) "  " (cadr s)
                   "  Ø" (itoa (nth 2 s))
                   "  " (itoa (nth 3 s)) " ad."
                   "  L=" (rb:s2 (/ (nth 4 s) 100.0)) " m"
                   "  " (rb:s2 (rb:satir-kg s)) " kg")))
  (princ (strcat "\n  TOPLAM: " (rb:s2 (rb:toplam-kg satirlar)) " kg")))

;; Çizime metraj tablosu çiz. p: dünya noktası (tablonun sol-üst köşesi)
(defun rb:tablo (p satirlar h / eski-baz eski-aci genis basliklar x y sh toplam-g
                 satir-ciz hucre i)
  (setq eski-baz *rb:baz* eski-aci *rb:aci*)
  (rb:koord p (rb:ucs-aci))
  (setq sh (* 2.0 h)                                   ; satır yüksekliği
        genis (mapcar '(lambda (k) (* k h)) '(4.0 9.0 5.0 5.0 7.0 8.0 9.0))
        basliklar '("Poz" "Tanım" "Çap" "Adet" "Boy(m)" "T.Boy(m)" "Ağırlık(kg)")
        toplam-g (apply '+ genis)
        y 0.0)
  ;; Bir satırdaki hücre yazıları
  (defun hucre (degerler / x i)
    (setq x 0.0 i 0)
    (foreach d degerler
      (rb:yazi (+ x (/ (nth i genis) 2.0)) (- y (/ sh 2.0)) d (* 0.8 h) 0.0 "REBAR-TABLE")
      (setq x (+ x (nth i genis)) i (1+ i))))
  ;; Başlık
  (rb:yazi (/ toplam-g 2.0) (- y (/ sh 2.0))
           (strcat "DONATI METRAJI  (" *rb:beton* " / " *rb:celik* ")") h 0.0 "REBAR-TABLE")
  (rb:cizgi (list 0.0 y) (list toplam-g y) "REBAR-TABLE" nil)
  (setq y (- y sh))
  (rb:cizgi (list 0.0 y) (list toplam-g y) "REBAR-TABLE" nil)
  (hucre basliklar)
  (setq y (- y sh))
  (rb:cizgi (list 0.0 y) (list toplam-g y) "REBAR-TABLE" nil)
  (foreach s satirlar
    (hucre (list (car s) (cadr s) (strcat "%%c" (itoa (nth 2 s))) (itoa (nth 3 s))
                 (rb:s2 (/ (nth 4 s) 100.0))
                 (rb:s2 (/ (* (nth 3 s) (nth 4 s)) 100.0))
                 (rb:s2 (rb:satir-kg s))))
    (setq y (- y sh))
    (rb:cizgi (list 0.0 y) (list toplam-g y) "REBAR-TABLE" nil))
  (hucre (list "" "TOPLAM" "" "" "" "" (rb:s2 (rb:toplam-kg satirlar))))
  (setq y (- y sh))
  (rb:cizgi (list 0.0 y) (list toplam-g y) "REBAR-TABLE" nil)
  ;; Dikey çizgiler
  (rb:cizgi (list 0.0 0.0) (list 0.0 y) "REBAR-TABLE" nil)
  (setq x 0.0)
  (foreach g genis
    (setq x (+ x g))
    (rb:cizgi (list x (if (< x (- toplam-g 1e-6)) (- sh) 0.0)) (list x y) "REBAR-TABLE" nil))
  (setq *rb:baz* eski-baz *rb:aci* eski-aci)
  (princ))

;; Metrajı yaz ve isterse tablo çiz
(defun rb:metraj-sonu (satirlar tablo-noktasi h)
  (rb:metraj-yaz satirlar)
  (if (rb:evet-mi "Donatı metraj tablosu çizilsin mi?" T)
    (rb:tablo tablo-noktasi satirlar h)))

;; ============================================
;; 9. KOMUT ÇERÇEVESİ (geri al + hata yönetimi)
;; ============================================

(defun rb:hata (msj)
  (if (and msj (not (wcmatch (strcase msj) "*CANCEL*,*QUIT*,*EXIT*,*BREAK*")))
    (princ (strcat "\nREBAR hata: " msj))
    (princ "\nİptal edildi."))
  (rb:bitir))

(defun rb:basla (baslik)
  (setq *rb:eski-hata* *error*
        *error* rb:hata
        *rb:uyarilar* nil
        *rb:eski-cmdecho* (getvar "CMDECHO")
        *rb:acik* T)
  (setvar "CMDECHO" 0)
  (vla-StartUndoMark (rb:doc))
  (princ (strcat "\n=== " baslik " ==="))
  (princ (strcat "\nBeton: " *rb:beton* "   Çelik: " *rb:celik*
                 "   (değiştirmek için REBAR-AYAR)")))

(defun rb:bitir ()
  (if *rb:acik*
    (progn
      (setq *rb:acik* nil)
      (vla-EndUndoMark (rb:doc))
      (if *rb:eski-cmdecho* (setvar "CMDECHO" *rb:eski-cmdecho*))
      (setq *error* *rb:eski-hata*)))
  (princ))

;; Bir komut gövdesini (argümansız fonksiyon sembolü) çerçeve içinde çalıştır
(defun rb:komut (baslik govde)
  (rb:basla baslik)
  (apply govde nil)
  (rb:bitir)
  (princ))

;; Ayarlar
(defun c:REBAR-AYAR ( / k v)
  (princ (strcat "\nMevcut ayarlar -> Beton: " *rb:beton* "  Çelik: " *rb:celik*
                 "  Yazı yüksekliği: " (if (> *rb:yazi-h* 0.0) (rb:s *rb:yazi-h*) "otomatik")))
  (setq *rb:beton* (rb:secenek-al "Beton sınıfı" "C20 C25 C30 C35 C40 C45 C50" *rb:beton*))
  (setq *rb:celik* (rb:secenek-al "Çelik sınıfı" "S220 S420 B420C B500C" *rb:celik*))
  (initget 4)
  (setq v (getreal (strcat "\nYazı yüksekliği cm (0 = otomatik) <" (rb:s *rb:yazi-h*) ">: ")))
  (if v (setq *rb:yazi-h* (float v)))
  (princ (strcat "\nYeni ayarlar -> Beton: " *rb:beton* "  Çelik: " *rb:celik*
                 "  ρmin(kiriş)=" (rb:yuzde (rb:rho-min-kiris))
                 "  ρmin(plak)=" (rb:yuzde (rb:rho-min-plak))))
  (princ))

(princ "\nREBAR-Ortak.lsp v2.0 yüklendi.")
(princ)
