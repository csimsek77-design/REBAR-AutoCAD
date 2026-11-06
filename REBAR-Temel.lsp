;;
;; REBAR-Temel.lsp
;; ============================================
;; AutoCAD LISP - Temel Donatı Yerleştirme
;; Türkiye Standartlarına Göre (TS 500)
;; Çaplar: 8,10,12,14,16,18,20,22,24,26,28,30,32 mm
;; ============================================
;; Oluşturma: 2024
;; Sürüm: 1.1 - Geliştirilmiş
;;

;; ============================================
;; 1. VERİ YAPILARI VE SABİTLER
;; ============================================

;; --- Donatı Çapları ve Ağırlıkları (Türkiye Standartları) ---
;; Format: (çap_mm ağırlık_kg/m alan_cm2)
(setq *rebar-data* '(
    (8   0.395  0.503)   ; Ø8
    (10  0.617  0.785)   ; Ø10
    (12  0.888  1.131)   ; Ø12
    (14  1.210  1.540)   ; Ø14
    (16  1.580  2.011)   ; Ø16
    (18  2.000  2.545)   ; Ø18
    (20  2.470  3.142)   ; Ø20
    (22  2.980  3.801)   ; Ø22
    (24  3.550  4.524)   ; Ø24
    (26  4.170  5.309)   ; Ø26
    (28  4.830  6.158)   ; Ø28
    (30  5.550  7.069)   ; Ø30
    (32  6.310  8.042)   ; Ø32
))

;; --- Donatı Sınıfları ve Akma Dayanımları ---
(setq *rebar-grades* '(
    ("S220"   . 2200)    ; kg/cm²
    ("S420"   . 4200)
    ("B420C"  . 4200)
    ("B500C"  . 5000)
))

;; --- TS 500 Minimum Donatı Oranları (%) ---
(setq *min-rebar-ratios* '(
    ("Temel"      . 0.008)   ; 0.8‰
    ("Kolon"      . 0.010)   ; 1.0‰
    ("Kiriş"      . 0.008)   ; 0.8‰
    ("Döşeme"     . 0.002)   ; 0.2‰
    ("Perde"      . 0.004)   ; 0.4‰
))

;; --- Minimum Paspayı (cm) ---
(setq *min-cover* 2.5)  ; TS 500 minimum paspayı

;; --- Katman Renkleri ---
(setq *layer-colors* '(
    ("REBAR-FOOTING"     . 1)    ; Kırmızı
    ("REBAR-FOOTING-TOP" . 2)    ; Sarı
    ("REBAR-FOOTING-BOT" . 3)    ; Yeşil
    ("REBAR-TEXT"        . 5)    ; Mavi
    ("REBAR-TABLE"       . 7)    ; Beyaz
    ("REBAR-DIM"         . 250)  ; Gri (boyut çizgileri)
))

;; --- Donatı Çap Renkleri (farklı çaplar = farklı renkler) ---
(setq *diameter-colors* '(
    (8  . 1)    ; Kırmızı
    (10 . 2)    ; Sarı
    (12 . 3)    ; Yeşil
    (14 . 4)    ; Cyan
    (16 . 5)    ; Mavi
    (18 . 6)    ; Magenta
    (20 . 7)    ; Beyaz
    (22 . 10)   ; Açık kırmızı
    (24 . 11)   ; Açık sarı
    (26 . 12)   ; Açık yeşil
    (28 . 13)   ; Açık cyan
    (30 . 14)   ; Açık mavi
    (32 . 15)   ; Gri
))

;; --- Çizgi Tipleri ---
(setq *linetype-continuous* "CONTINUOUS")
(setq *linetype-dashed*    "DASHED")
(setq *linetype-center*    "CENTER2")

;; ============================================
;; 2. YARDIMCI FONKSİYONLAR
;; ============================================

;; --- Nokta İşlemleri ---
(defun pt+ (p1 p2)
  "Noktaları topla: (x1 y1 z1) + (x2 y2 z2)"
  (if (and (= (length p1) 3) (= (length p2) 3))
    (list (+ (car p1) (car p2)) (+ (cadr p1) (cadr p2)) (+ (caddr p1) (caddr p2)))
    (list (+ (car p1) (car p2)) (+ (cadr p1) (cadr p2)))
  )
)

(defun pt- (p1 p2)
  "Noktaları çıkart: (x1 y1 z1) - (x2 y2 z2)"
  (if (and (= (length p1) 3) (= (length p2) 3))
    (list (- (car p1) (car p2)) (- (cadr p1) (cadr p2)) (- (caddr p1) (caddr p2)))
    (list (- (car p1) (car p2)) (- (cadr p1) (cadr p2)))
  )
)

(defun pt* (p scalar)
  "Noktayı skalar ile çarp: (x y z) * n"
  (if (= (length p) 3)
    (list (* (car p) scalar) (* (cadr p) scalar) (* (caddr p) scalar))
    (list (* (car p) scalar) (* (cadr p) scalar))
  )
)

(defun pt/ (p scalar)
  "Noktayı skalar ile böl: (x y z) / n"
  (if (= (length p) 3)
    (list (/ (car p) scalar) (/ (cadr p) scalar) (/ (caddr p) scalar))
    (list (/ (car p) scalar) (/ (cadr p) scalar))
  )
)

;; --- Mesafe Hesaplama ---
(defun dist (p1 p2)
  "İki nokta arasındaki mesafe (cm)"
  (sqrt (+ (expt (- (car p2) (car p1)) 2)
           (expt (- (cadr p2) (cadr p1)) 2))))

;; --- Donatı Verisini Al ---
(defun get-rebar-weight (diameter)
  "Donatı ağırlığını kg/m cinsinden döndür"
  (let ((data (assoc diameter *rebar-data*)))
    (if data (cadr data) 0.0)
  )
)

(defun get-rebar-area (diameter)
  "Donatı alanını cm² cinsinden döndür"
  (let ((data (assoc diameter *rebar-data*)))
    (if data (caddr data) 0.0)
  )
)

;; --- Donatı Sınıfı Dayanımını Al ---
(defun get-rebar-strength (grade)
  "Donatı sınıfının akma dayanımını kg/cm² cinsinden döndür"
  (cdr (assoc grade *rebar-grades*))
)

;; --- Minimum Donatı Oranını Al ---
(defun get-min-rebar-ratio (element-type)
  "Eleman tipine göre minimum donatı oranını döndür"
  (cdr (assoc element-type *min-rebar-ratios*))
)

;; --- Renk Kodu Al ---
(defun get-diameter-color (diameter)
  "Donatı çapına göre renk kodu döndür"
  (cdr (assoc diameter *diameter-colors*))
)

;; --- Katman Rengini Al ---
(defun get-layer-color (layer-name)
  "Katman adına göre renk kodu döndür"
  (cdr (assoc layer-name *layer-colors*))
)

;; --- 2D Noktayı 3D'ye Dönüştür ---
(defun pt2d->3d (pt z)
  "2D noktayı Z koordinatı ile 3D'ye dönüştür"
  (list (car pt) (cadr pt) z)
)

;; ============================================
;; 3. KATMAN YÖNETİMİ FONKSİYONLARI
;; ============================================

;; --- Katman Oluştur ---
(defun create-layer (layer-name color linetype / layer-exists)
  "Katman oluştur veya varolanı kontrol et"
  (if (tblsearch "LAYER" layer-name)
    (progn
      (setq layer-exists T)
    )
    (progn
      (command "_.-LAYER" "_N" layer-name "_C" color "" "_L" linetype "" "")
      (setq layer-exists nil)
    )
  )
  layer-exists
)

;; --- Temel Donatı Katmanlarını Oluştur ---
(defun create-footing-layers ()
  "Temel donatı için gerekli katmanları oluştur"
  (foreach layer-info *layer-colors*
    (create-layer (car layer-info) (cdr layer-info) *linetype-continuous*)
  )
  (create-layer "REBAR-FOOTING-TOP" 2 *linetype-continuous*)
  (create-layer "REBAR-FOOTING-BOT" 3 *linetype-continuous*)
  (princ "\nKatmanlar oluşturuldu: REBAR-FOOTING, REBAR-FOOTING-TOP, REBAR-FOOTING-BOT, REBAR-TEXT, REBAR-TABLE, REBAR-DIM")
  (princ)
)

;; --- Katmanı Aktif Yap ---
(defun set-current-layer (layer-name)
  "Aktif katmanı değiştir"
  (if (tblsearch "LAYER" layer-name)
    (command "_.-LAYER" "_S" layer-name "")
    (create-layer layer-name 7 *linetype-continuous*)
  )
)

;; --- Katmanı Dondur (Freeze/Thaw) ---
(defun freeze-layer (layer-name)
  "Katmanı dondur"
  (command "_.-LAYER" "_F" layer-name "")
)

(defun thaw-layer (layer-name)
  "Katmanı çöz"
  (command "_.-LAYER" "_T" layer-name "")
)

;; ============================================
;; 4. KONTROL FONKSİYONLARI (TS 500)
;; ============================================

;; --- Minimum Donatı Kontrolü ---
(defun check-min-rebar (element-type width length rebar-area spacing layers direction)
  "TS 500 minimum donatı oranı kontrolü"
  (let* (
    (min-ratio (get-min-rebar-ratio element-type))
    (concrete-area (* width length))
    (effective-dim (if (= direction "X") length width))
    (effective-length (- effective-dim (* 2 *min-cover*)))
    (count (calculate-rebar-count effective-dim spacing *min-cover*))
    (total-rebar-area (* rebar-area count layers))
    (actual-ratio (/ total-rebar-area concrete-area))
    (min-required (* min-ratio concrete-area))
    )
    (if (< total-rebar-area min-required)
      (progn
        (alert (strcat "UYARI: " direction " doğrultusu minimum donatı oranı sağlanmıyor!\n"
                      "Gerekli: " (rtos min-required 2 2) " cm²\n"
                      "Mevcut: " (rtos total-rebar-area 2 2) " cm²\n"
                      "Oran: %" (rtos (* 100 actual-ratio) 2 2) " < %" (rtos (* 100 min-ratio) 2 2)))
        nil
      )
      (progn
        (princ (strcat "\n" direction " doğrultusu minimum donatı kontrolü: BAŞARILI (Oran: %" (rtos (* 100 actual-ratio) 2 2) ")"))
        T
      )
    )
  )
)

;; --- Paspayı Kontrolü ---
(defun check-cover (cover diameter)
  "Paspayı kontrolü: minimum 2.5cm ve çapın 1.5 katı"
  (let (
    (min-cover-calc (max *min-cover* (* 1.5 (/ diameter 10.0))))  ; diameter mm -> cm
    )
    (if (< cover min-cover-calc)
      (progn
        (alert (strcat "UYARI: Paspayı yetersiz!\n"
                      "Mevcut: " (rtos cover 2 1) " cm\n"
                      "Gerekli: " (rtos min-cover-calc 2 1) " cm"))
        nil
      )
      (progn
        (princ (strcat "\nPaspayı kontrolü: BAŞARILI (" (rtos cover 2 1) " cm >= " (rtos min-cover-calc 2 1) " cm)"))
        T
      )
    )
  )
)

;; --- Donatı Aralık Kontrolü ---
(defun check-spacing (spacing diameter)
  "Donatı aralığı kontrolü: maksimum 30cm ve 2x çap"
  (let (
    (max-spacing (min 30.0 (* 2 (/ diameter 10.0))))  ; diameter mm -> cm
    )
    (if (> spacing max-spacing)
      (progn
        (alert (strcat "UYARI: Donatı aralığı fazla!\n"
                      "Mevcut: " (rtos spacing 2 1) " cm\n"
                      "Maksimum: " (rtos max-spacing 2 1) " cm"))
        nil
      )
      T
    )
  )
)

;; --- Tüm Kontrolleri Yap ---
(defun check-all-parameters (diameter-x spacing-x diameter-y spacing-y cover)
  "Tüm parametreleri kontrol et"
  (and
    (check-cover cover diameter-x)
    (check-cover cover diameter-y)
    (check-spacing spacing-x diameter-x)
    (check-spacing spacing-y diameter-y)
  )
)

;; ============================================
;; 5. ÇİZİM FONKSİYONLARI
;; ============================================

;; --- Donatı Çizgisi Çiz ---
(defun draw-rebar-line (start-point end-point diameter / line-obj)
  "Donatı çizgisi çiz ve renklendir"
  (set-current-layer (if (= (getvar "CLAYER") "REBAR-FOOTING-TOP")
                      "REBAR-FOOTING-TOP"
                      (if (= (getvar "CLAYER") "REBAR-FOOTING-BOT")
                        "REBAR-FOOTING-BOT"
                        "REBAR-FOOTING")))
  
  (command "_.LINE" start-point end-point "")
  (setq line-obj (entlast))
  
  ;; Renk ayarla
  (vla-put-color (vlax-ename->vla-object line-obj) (get-diameter-color diameter))
  
  ;; Çizgi kalınlığını ayarla (çapla orantılı)
  (vla-put-linetype (vlax-ename->vla-object line-obj) *linetype-continuous*)
  
  line-obj
)

;; --- Donatı Etiketi Yerleştir ---
(defun place-rebar-label (position text height / text-obj)
  "Donatı etiketi yerleştir"
  (set-current-layer "REBAR-TEXT")
  (command "_.TEXT" "_MC" position height "0" text)
  (setq text-obj (entlast))
  (vla-put-color (vlax-ename->vla-object text-obj) 5)  ; Mavi
  text-obj
)

;; --- Temel Kare Çiz ---
(defun draw-footing-outline (base-point width length height / pts)
  "Temel kalıpını çiz (2D)"
  (set-current-layer "REBAR-FOOTING")
  (setq pts (list
    base-point
    (pt+ base-point (list width 0))
    (pt+ base-point (list width length))
    (pt+ base-point (list 0 length))
    base-point
  ))
  (command "_.PLINE" pts "")
  (vla-put-closed (vlax-ename->vla-object (entlast)) :vlax-true)
  (vla-put-color (vlax-ename->vla-object (entlast)) 1)  ; Kırmızı
)

;; --- Temel Boyut Çizgilerini Çiz ---
(defun draw-footing-dimensions (base-point width length height)
  "Temel boyut çizgilerini çiz"
  (set-current-layer "REBAR-DIM")
  
  ;; Genişlik boyutu
  (command "_.DIM" "_HOR" 
    (pt+ base-point (list 0 -5)) 
    (pt+ base-point (list width -5)) 
    (pt+ base-point (list (/ width 2) -10)) "")
  
  ;; Uzunluk boyutu
  (command "_.DIM" "_VER" 
    (pt+ base-point (list width -5)) 
    (pt+ base-point (list width length)) 
    (pt+ base-point (list (+ width 5) (/ length 2))) "")
)

;; --- Etriye/Donatı Sembolü Çiz ---
(defun draw-rebar-symbol (center-point diameter)
  "Donatı sembolünü çiz (daire + çap yazısı)"
  (set-current-layer "REBAR-TEXT")
  (let ((radius (/ diameter 20.0)))  ; mm -> cm ve yarıçap
    (command "_.CIRCLE" center-point radius)
    (place-rebar-label center-point (strcat "Ø" (itoa diameter)) 1.5)
  )
)

;; ============================================
;; 6. TEMEL DONATI HESAPLAMA FONKSİYONLARI
;; ============================================

;; --- Donatı Sayısını Hesapla ---
(defun calculate-rebar-count (dimension spacing cover)
  "Boyut, aralık ve paspayıya göre donatı sayısını hesapla"
  (let (
    (effective-length (- dimension (* 2 cover)))
    (count (fix (/ effective-length spacing)))
    )
    ;; Eğer aralık boyuttan büyükse, minimum 1 donatı
    (if (<= effective-length spacing)
      1
      (max 1 (1+ count))  ; +1 çünkü 0'dan başlıyoruz
    )
  )
)

;; --- Toplam Donatı Uzunluğunu Hesapla ---
(defun calculate-total-length (count spacing dimension)
  "Toplam donatı uzunluğunu hesapla"
  (* count dimension)
)

;; --- Toplam Ağırlığı Hesapla ---
(defun calculate-total-weight (total-length diameter)
  "Toplam donatı ağırlığını kg cinsinden hesapla"
  (* total-length (get-rebar-weight diameter) 0.01)  ; cm -> m
)

;; --- Donatı Adedini Hesapla (Detaylı) ---
(defun calculate-rebar-details (dimension spacing cover diameter layers)
  "Detaylı donatı hesaplaması"
  (let* (
    (effective-length (- dimension (* 2 cover)))
    (count (calculate-rebar-count dimension spacing cover))
    (total-length (* count dimension))
    (total-weight (calculate-total-weight total-length diameter))
    (rebar-area (get-rebar-area diameter))
    (total-area (* rebar-area count layers))
    )
    (list
      :count count
      :total-length total-length
      :total-weight total-weight
      :total-area total-area
      :diameter diameter
      :spacing spacing
    )
  )
)

;; ============================================
;; 7. TEMEL DONATI ANA FONKSİYONLARI
;; ============================================

;; --- X Doğrultusu Donatı Yerleştir ---
(defun place-x-rebar (base-point width length height diameter spacing cover layers z-offset)
  "X doğrultusunda (boyuna) donatı yerleştir"
  (let* (
    (count (calculate-rebar-count length spacing cover))
    (z-pos (+ (caddr base-point) z-offset))
    (rebar-details (calculate-rebar-details length spacing cover diameter layers))
    )
    
    (dotimes (i count)
      (let* (
        (y-pos (+ (cadr base-point) cover (* i spacing)))
        (start-pt (list (car base-point) y-pos z-pos))
        (end-pt   (list (+ (car base-point) width) y-pos z-pos))
        )
        (draw-rebar-line start-pt end-pt diameter)
      )
    )
    
    rebar-details
  )
)

;; --- Y Doğrultusu Donatı Yerleştir ---
(defun place-y-rebar (base-point width length height diameter spacing cover layers z-offset)
  "Y doğrultusunda (enine) donatı yerleştir"
  (let* (
    (count (calculate-rebar-count width spacing cover))
    (z-pos (+ (caddr base-point) z-offset))
    (rebar-details (calculate-rebar-details width spacing cover diameter layers))
    )
    
    (dotimes (i count)
      (let* (
        (x-pos (+ (car base-point) cover (* i spacing)))
        (start-pt (list x-pos (cadr base-point) z-pos))
        (end-pt   (list x-pos (+ (cadr base-point) length) z-pos))
        )
        (draw-rebar-line start-pt end-pt diameter)
      )
    )
    
    rebar-details
  )
)

;; --- Tekil Temel Donatı Yerleştir ---
(defun place-footing-rebar (base-point width length height 
                           diameter-x spacing-x diameter-y spacing-y 
                           cover layers / 
                           result-x result-y
                           total-weight z-bottom z-top)
  "Tekil temel üzerinde donatı yerleştir"
  
  ;; Z koordinatlarını hesapla
  (setq z-bottom (+ (caddr base-point) cover))  ; Alt donatı Z
  (setq z-top (+ (caddr base-point) height cover))  ; Üst donatı Z
  
  ;; Temel kalıbını çiz
  (draw-footing-outline base-point width length height)
  
  ;; Alt katman donatıları
  (set-current-layer "REBAR-FOOTING-BOT")
  (setq result-x (place-x-rebar base-point width length height 
                                diameter-x spacing-x cover 1 z-bottom))
  (setq result-y (place-y-rebar base-point width length height 
                                diameter-y spacing-y cover 1 z-bottom))
  
  ;; Üst katman donatıları (eğer layers > 1)
  (if (> layers 1)
    (progn
      (set-current-layer "REBAR-FOOTING-TOP")
      (setq result-x (place-x-rebar base-point width length height 
                                    diameter-x spacing-x cover layers z-top))
      (setq result-y (place-y-rebar base-point width length height 
                                    diameter-y spacing-y cover layers z-top))
    )
  )
  
  ;; Toplam ağırlığı hesapla
  (setq total-weight 
    (+ 
      (* (nth 2 result-x) layers)  ; X donatı ağırlığı * katman sayısı
      (* (nth 2 result-y) layers)   ; Y donatı ağırlığı * katman sayısı
    )
  )
  
  ;; Etiketleri yerleştir
  (place-rebar-label 
    (pt+ base-point (list (/ width 2) (/ length 2) (+ height 5)))
    (strcat "Ø" (itoa diameter-x) "-" (itoa (int spacing-x)) "/" (itoa (int spacing-y)) 
            (if (> layers 1) " - 2KAT" " - 1KAT"))
    3.0
  )
  
  (place-rebar-label 
    (pt+ base-point (list (/ width 2) (- (cadr base-point) 10) (/ height 2)))
    (strcat "X: " (itoa (nth 0 result-x)) "×Ø" (itoa diameter-x) 
            " | Y: " (itoa (nth 0 result-y)) "×Ø" (itoa diameter-y))
    2.5
  )
  
  (place-rebar-label 
    (pt+ base-point (list (/ width 2) (- (cadr base-point) 15) (/ height 2)))
    (strcat "Toplam Ağırlık: " (rtos total-weight 2 2) " kg")
    2.5
  )
  
  ;; Boyut çizgilerini çiz
  (draw-footing-dimensions base-point width length height)
  
  ;; Sonuçları döndür
  (list
    :width width
    :length length
    :height height
    :diameter-x diameter-x
    :diameter-y diameter-y
    :spacing-x spacing-x
    :spacing-y spacing-y
    :cover cover
    :layers layers
    :count-x (nth 0 result-x)
    :count-y (nth 0 result-y)
    :total-length-x (nth 1 result-x)
    :total-length-y (nth 1 result-y)
    :total-weight total-weight
    :rebar-area-x (get-rebar-area diameter-x)
    :rebar-area-y (get-rebar-area diameter-y)
  )
)

;; ============================================
;; 8. DONATI LİSTESİ TABLOSU OLUŞTURMA
;; ============================================

;; --- Donatı Listesi Tablosunu Oluştur (Geliştirilmiş) ---
(defun create-rebar-table (data insertion-point / 
  table-obj row-height col-widths total-rows)
  "Donatı listesini profesyonel tablo formatında oluştur"
  
  (set-current-layer "REBAR-TABLE")
  
  ;; Tablo boyutlarını hesapla
  (setq row-height 0.5)  ; Satır yüksekliği (cm)
  (setq col-widths '(2.0 4.0 2.0 3.0))  ; Sütun genişlikleri (cm)
  (setq total-rows 5)  ; Başlık + 2 satır + boş + toplam
  
  ;; Tablo oluştur
  (setq table-obj
    (vla-addtable
      (vla-get-modelspace
        (vla-get-activedocument
          (vlax-get-acad-object)))
      (vlax-3d-point insertion-point)
      4  ; Sütun sayısı
      total-rows  ; Satır sayısı
      (* (apply '+ col-widths) 10)  ; Tablo genişliği (mm)
      (* total-rows row-height 10)  ; Tablo yüksekliği (mm)
    )
  )
  
  ;; Tablo stili ayarla
  (vla-put-style table-obj "STANDARD")
  
  ;; Başlık satırını ayarla
  (vla-settext table-obj 0 0 "Poz No")
  (vla-settext table-obj 0 1 "Tanımlama")
  (vla-settext table-obj 0 2 "Adet")
  (vla-settext table-obj 0 3 "Ağırlık (kg)")
  
  ;; Veri satırlarını ayarla
  (vla-settext table-obj 1 0 "1.1")
  (vla-settext table-obj 1 1 
    (strcat "Ø" (itoa (nth 4 data)) "-" 
            (itoa (int (nth 6 data))) "/" 
            (itoa (int (nth 7 data)))
    )
  )
  (vla-settext table-obj 1 2 
    (itoa (* (nth 10 data) (nth 11 data)))
  )
  (vla-settext table-obj 1 3 
    (rtos (nth 14 data) 2 2)
  )
  
  ;; İkinci donatı satırı (eğer farklı çap varsa)
  (if (/= (nth 4 data) (nth 5 data))
    (progn
      (vla-settext table-obj 2 0 "1.2")
      (vla-settext table-obj 2 1 
        (strcat "Ø" (itoa (nth 5 data)) "-" 
                (itoa (int (nth 7 data))) "/" 
                (itoa (int (nth 6 data)))
        )
      )
      (vla-settext table-obj 2 2 
        (itoa (* (nth 10 data) (nth 11 data)))
      )
      (vla-settext table-obj 2 3 "")
    )
  )
  
  ;; Toplam satırı
  (vla-settext table-obj 3 0 "TOPLAM")
  (vla-settext table-obj 3 2 
    (itoa (+ (* (nth 10 data) (nth 11 data)) 
             (if (/= (nth 4 data) (nth 5 data)) 
               (* (nth 10 data) (nth 11 data)) 0)))
  )
  (vla-settext table-obj 3 3 (rtos (nth 14 data) 2 2))
  
  ;; Sütun genişliklerini ayarla
  (vla-put-width table-obj 0 (* (nth 0 col-widths) 10))
  (vla-put-width table-obj 1 (* (nth 1 col-widths) 10))
  (vla-put-width table-obj 2 (* (nth 2 col-widths) 10))
  (vla-put-width table-obj 3 (* (nth 3 col-widths) 10))
  
  ;; Satır yüksekliklerini ayarla
  (dotimes (i total-rows)
    (vla-put-height table-obj i (* row-height 10))
  )
  
  ;; Başlık satırını kalın yap
  (vla-put-bold table-obj 0 :vlax-true)
  (vla-put-bold table-obj 3 :vlax-true)
  
  table-obj
)

;; --- Basit Metin Tablosu (AutoCAD TABLE yoksa) ---
(defun create-simple-rebar-table (data insertion-point)
  "Basit metin tablosu oluştur"
  (set-current-layer "REBAR-TABLE")
  
  (let* (
    (x (car insertion-point))
    (y (cadr insertion-point))
    (line-height 0.5)
    (col1-x x)
    (col2-x (+ x 2.0))
    (col3-x (+ x 6.0))
    (col4-x (+ x 8.0))
    )
    
    ;; Başlık satırı
    (place-rebar-label (list col1-x y) "Poz No" 0.4)
    (place-rebar-label (list col2-x y) "Tanımlama" 0.4)
    (place-rebar-label (list col3-x y) "Adet" 0.4)
    (place-rebar-label (list col4-x y) "Ağırlık (kg)" 0.4)
    
    ;; Veri satırı
    (setq y (- y line-height))
    (place-rebar-label (list col1-x y) "1.1" 0.4)
    (place-rebar-label (list col2-x y) 
      (strcat "Ø" (itoa (nth 4 data)) "-" 
              (itoa (int (nth 6 data))) "/" 
              (itoa (int (nth 7 data)))) 0.4)
    (place-rebar-label (list col3-x y) 
      (itoa (* (nth 10 data) (nth 11 data))) 0.4)
    (place-rebar-label (list col4-x y) 
      (rtos (nth 14 data) 2 2) 0.4)
    
    ;; Toplam satırı
    (setq y (- y line-height))
    (place-rebar-label (list col1-x y) "TOPLAM" 0.4)
    (place-rebar-label (list col3-x y) 
      (itoa (+ (* (nth 10 data) (nth 11 data)) 
               (if (/= (nth 4 data) (nth 5 data)) 
                 (* (nth 10 data) (nth 11 data)) 0))) 0.4)
    (place-rebar-label (list col4-x y) 
      (rtos (nth 14 data) 2 2) 0.4)
  )
)

;; ============================================
;; 9. KULLANICI ARAYÜZÜ FONKSİYONLARI
;; ============================================

;; --- Donatı Çapını Seç ---
(defun select-diameter (prompt / diameter)
  "Kullanıcıdan donatı çapını seçmesini iste"
  (setq diameter 12)  ; Varsayılan
  (initget 1 "8 10 12 14 16 18 20 22 24 26 28 30 32")
  (setq diameter (getint (strcat prompt " [8/10/12/14/16/18/20/22/24/26/28/30/32] <12>: ")))
  (if (and diameter (not (member diameter '(8 10 12 14 16 18 20 22 24 26 28 30 32))))
    (progn (alert "Geçersiz çap! 12 olarak ayarlandı.") 12)
    (if (not diameter) 12 diameter)
  )
)

;; --- Donatı Sınıfını Seç ---
(defun select-grade (prompt / grade)
  "Kullanıcıdan donatı sınıfını seçmesini iste"
  (setq grade "B500C")  ; Varsayılan
  (setq grade
    (getstring (strcat prompt " [S220/S420/B420C/B500C] <B500C>: "))
  )
  (if (not grade) "B500C" grade)
)

;; --- Onayla ---
(defun confirm (prompt)
  "Kullanıcıdan onay iste"
  (initget 1 "Evet Hayır E H")
  (cond
    ((= (getkword (strcat prompt " [Evet/Hayır] <Evet>: ")) "Evet") T)
    (T nil)
  )
)

;; --- Sayısal Girdi Al ---
(defun get-positive-number (prompt default / value)
  "Pozitif sayı girdisi al"
  (setq value (getreal (strcat prompt " <" (rtos default) ">: ")))
  (if (or (not value) (<= value 0))
    default
    value
  )
)

;; --- Temel Tipini Seç ---
(defun select-footing-type (prompt / type)
  "Temel tipini seç"
  (initget 1 "Tekil Sürekli Raft")
  (setq type (getkword (strcat prompt " [Tekil/Sürekli/Raft] <Tekil>: ")))
  (cond
    ((or (not type) (= type "Tekil")) "Tekil")
    ((= type "Sürekli") "Sürekli")
    ((= type "Raft") "Raft")
    (T "Tekil")
  )
)

;; ============================================
;; 10. ANA FONKSİYON - TEMEL DONATI
;; ============================================

(defun C:REBAR-FOOTING ( / 
  base-point width length height
  diameter-x diameter-y spacing-x spacing-y
  cover layers footing-type
  result table-pos
)
  "Ana fonksiyon: Temel donatı yerleştirme"
  
  (vl-load-com)
  (vla-startundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== REBAR-Temel v1.1: Temel Donatı Yerleştirme ===")
  (princ "\nTürkiye Standartlarına Göre (TS 500)")
  (princ "\nÇaplar: 8,10,12,14,16,18,20,22,24,26,28,30,32 mm")
  
  ;; Katmanları oluştur
  (create-footing-layers)
  
  ;; 1. Temel tipini ve boyutlarını al
  (princ "\n--- Temel Tipi ve Boyutları ---")
  (setq footing-type (select-footing-type "Temel tipi"))
  
  (cond
    ((= footing-type "Tekil")
      (setq base-point (getpoint "\nTemel köşe noktasını seçiniz: "))
      (setq width (get-positive-number "\nTemel genişliğini giriniz (cm): " 100.0))
      (setq length (get-positive-number "Temel uzunluğunu giriniz (cm): " 100.0))
      (setq height (get-positive-number "Temel yüksekliğini giriniz (cm): " 50.0))
    )
    ((= footing-type "Sürekli")
      (setq base-point (getpoint "\nSürekli temel başlangıç noktasını seçiniz: "))
      (setq width (get-positive-number "\nTemel genişliğini giriniz (cm): " 60.0))
      (setq length (get-positive-number "Temel uzunluğunu giriniz (cm): " 500.0))
      (setq height (get-positive-number "Temel yüksekliğini giriniz (cm): " 50.0))
    )
    ((= footing-type "Raft")
      (setq base-point (getpoint "\nRaft temel köşe noktasını seçiniz: "))
      (setq width (get-positive-number "\nBina genişliğini giriniz (cm): " 1000.0))
      (setq length (get-positive-number "Bina uzunluğunu giriniz (cm): " 1500.0))
      (setq height (get-positive-number "Temel yüksekliğini giriniz (cm): " 80.0))
    )
  )
  
  ;; 2. Donatı parametrelerini al
  (princ "\n--- X Doğrultusu Donatı (Boyuna) ---")
  (setq diameter-x (select-diameter "X doğrultusu donatı çapı"))
  (setq spacing-x (get-positive-number "X doğrultusu donatı aralığı (cm): " 20.0))
  
  (princ "\n--- Y Doğrultusu Donatı (Enine) ---")
  (setq diameter-y (select-diameter "Y doğrultusu donatı çapı"))
  (setq spacing-y (get-positive-number "Y doğrultusu donatı aralığı (cm): " 20.0))
  
  (princ "\n--- Diğer Parametreler ---")
  (setq cover (get-positive-number "Paspayı mesafesi (cm): " 4.0))
  (setq layers (getint "\nKatman sayısı [1/2]: <1>: "))
  (if (not layers) (setq layers 1))
  
  ;; 3. Kontrolleri yap
  (princ "\n--- Parametre Kontrolü ---")
  (check-all-parameters diameter-x spacing-x diameter-y spacing-y cover)
  (check-min-rebar "Temel" width length (get-rebar-area diameter-x) spacing-x layers "X")
  (check-min-rebar "Temel" width length (get-rebar-area diameter-y) spacing-y layers "Y")
  
  ;; 4. Ön izleme ve onay
  (princ "\n--- Ön İzleme ---")
  (princ (strcat "\nTemel Tipi: " footing-type))
  (princ (strcat "\nTemel: " (rtos width 2 1) "×" (rtos length 2 1) "×" (rtos height 2 1) " cm"))
  (princ (strcat "\nX Donatı: Ø" (itoa diameter-x) " - " (rtos spacing-x 2 1) " cm aralık"))
  (princ (strcat "\nY Donatı: Ø" (itoa diameter-y) " - " (rtos spacing-y 2 1) " cm aralık"))
  (princ (strcat "\nPaspayı: " (rtos cover 2 1) " cm"))
  (princ (strcat "\nKatman: " (itoa layers)))
  
  (if (not (confirm "\nDonatı yerleştirilsin mi?"))
    (progn
      (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
      (princ)
      (exit)
    )
  )
  
  ;; 5. Donatı yerleştir
  (setq result
    (place-footing-rebar 
      base-point width length height
      diameter-x spacing-x diameter-y spacing-y
      cover layers
    )
  )
  
  ;; 6. Donatı listesini oluştur
  (setq table-pos (pt+ base-point (list (+ width 10) 0)))
  (if (confirm "\nDonatı listesi tablosu oluşturulsun mu?")
    (progn
      (if (vl-catch-all-error-p
            (vl-catch-all-apply 'vla-addtable (list nil nil 0 0 0 0))))
        (create-simple-rebar-table result table-pos)
        (create-rebar-table result table-pos)
      )
    )
  )
  
  (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== İşlem Tamamlandı ===")
  (princ (strcat "\nToplam Donatı Ağırlığı: " (rtos (nth 14 result) 2 2) " kg"))
  (princ (strcat "\nX Doğrultusu: " (itoa (nth 10 result)) " adet Ø" (itoa (nth 4 result))))
  (princ (strcat "\nY Doğrultusu: " (itoa (nth 11 result)) " adet Ø" (itoa (nth 5 result))))
  (princ)
)

;; ============================================
;; 11. SÜREKLİ TEMEL FONKSİYONU
;; ============================================

(defun C:REBAR-STRIP ( / 
  base-point width length height
  diameter-x spacing-x diameter-y spacing-y
  cover layers
  result
)
  "Sürekli temel donatı yerleştirme"
  (C:REBAR-FOOTING)
)

;; ============================================
;; 12. OTOMATİK YÜKLEME VE KOMUTLAR
;; ============================================

;; Dosya yüklendiğinde mesaj göster
(princ "\nREBAR-Temel v1.1 LISP dosyası yüklendi.")
(princ "\nKullanılabilir komutlar:")
(princ "\n  - REBAR-FOOTING: Temel donatı yerleştir")
(princ "\n  - RFT: Temel donatı (kısaltma)")
(princ "\n  - TEMEL: Temel donatı (Türkçe)")
(princ)

;; Komutları tanımla
(defun C:RFT () (C:REBAR-FOOTING))
(defun C:TEMEL () (C:REBAR-FOOTING))
(defun C:FOOTING () (C:REBAR-FOOTING))

;; AutoCAD'e komut ekle
(if (and (not (vl-catch-all-error-p
          (vl-catch-all-apply 'vla-get-menubar 
            (list (vla-get-activedocument (vlax-get-acad-object))))))
        (= (getvar "CVPORT") 1))
  (progn
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Temel Donatı" "REBAR-FOOTING" "Temel donatı yerleştir" 1))
    (princ "\n'REBAR' menüsüne eklendi.")
  )
)

;; APPDATA klasörüne kaydetme fonksiyonu
(defun save-to-appdata ()
  "LISP dosyasını APPDATA klasörüne kopyala"
  (if (setq appdata (getenv "APPDATA"))
    (progn
      (setq dest (strcat appdata "\\Autodesk\\AutoCAD\\LISP\\REBAR-Temel.lsp"))
      (vl-file-copy (findfile "REBAR-Temel.lsp") dest)
      (princ (strcat "\nDosya kopyalandı: " dest))
    )
    (princ "\nAPPDATA değişkeni bulunamadı.")
  )

(princ "\nREBAR-Temel.lsp v1.1 yüklendi.\n")
(princ)
