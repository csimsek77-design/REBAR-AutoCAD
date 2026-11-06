;;
;; REBAR-Kolon.lsp
;; ============================================
;; AutoCAD LISP - Kolon/Perde Donatı Yerleştirme
;; Türkiye Standartlarına Göre (TS 500)
;; ============================================
;; Oluşturma: 2024
;; Sürüm: 1.0
;;

;; ============================================
;; 1. ORTAK VERİ YAPILARI (REBAR-Temel.lsp'den al)
;; ============================================

;; Eğer REBAR-Temel.lsp yüklenmediyse, veri yapılarını tekrar tanımla
(if (not (boundp '*rebar-data*))
  (progn
    ;; Donatı Çapları ve Ağırlıkları
    (setq *rebar-data* '(
        (8   0.395  0.503)
        (10  0.617  0.785)
        (12  0.888  1.131)
        (14  1.210  1.540)
        (16  1.580  2.011)
        (18  2.000  2.545)
        (20  2.470  3.142)
        (22  2.980  3.801)
        (24  3.550  4.524)
        (26  4.170  5.309)
        (28  4.830  6.158)
        (30  5.550  7.069)
        (32  6.310  8.042)
    ))
    
    ;; Donatı Sınıfları
    (setq *rebar-grades* '(
        ("S220"   . 2200)
        ("S420"   . 4200)
        ("B420C"  . 4200)
        ("B500C"  . 5000)
    ))
    
    ;; Minimum Donatı Oranları
    (setq *min-rebar-ratios* '(
        ("Temel"      . 0.008)
        ("Kolon"      . 0.010)
        ("Kiriş"      . 0.008)
        ("Döşeme"     . 0.002)
        ("Perde"      . 0.004)
    ))
    
    ;; Minimum Paspayı
    (setq *min-cover* 2.5)
    
    ;; Katman Renkleri
    (setq *layer-colors* '(
        ("REBAR-FOOTING"     . 1)
        ("REBAR-FOOTING-TOP" . 2)
        ("REBAR-FOOTING-BOT" . 3)
        ("REBAR-COLUMN"      . 4)
        ("REBAR-COLUMN-ETRIYE" . 6)
        ("REBAR-TEXT"        . 5)
        ("REBAR-TABLE"       . 7)
        ("REBAR-DIM"         . 250)
    ))
    
    ;; Donatı Çap Renkleri
    (setq *diameter-colors* '(
        (8  . 1)   (10 . 2)   (12 . 3)   (14 . 4)
        (16 . 5)   (18 . 6)   (20 . 7)   (22 . 10)
        (24 . 11)  (26 . 12)  (28 . 13)  (30 . 14)
        (32 . 15)
    ))
    
    ;; Çizgi Tipleri
    (setq *linetype-continuous* "CONTINUOUS")
    (setq *linetype-dashed* "DASHED")
  )
)

;; ============================================
;; 2. KOLON/PERDE VERİ YAPILARI
;; ============================================

;; --- Etriye Boyutları (mm) ---
(setq *stirrup-sizes* '(6 8 10 12 14 16))

;; --- Kolon Tipi Tanımları ---
(setq *column-types* '(
    ("Kare" . "SQUARE")
    ("Dikdörtgen" . "RECTANGULAR")
    ("Dairesel" . "CIRCULAR")
    ("L" . "L-SHAPED")
    ("T" . "T-SHAPED")
))

;; ============================================
;; 3. YARDIMCI FONKSİYONLAR
;; ============================================

;; Fonksiyonları sadece tanımlanmadılarsa tanımlayalım

(if (not (boundp 'pt+))
  (defun pt+ (p1 p2)
    (if (and (= (length p1) 3) (= (length p2) 3))
      (list (+ (car p1) (car p2)) (+ (cadr p1) (cadr p2)) (+ (caddr p1) (caddr p2)))
      (list (+ (car p1) (car p2)) (+ (cadr p1) (cadr p2)))
    )
  )
)

(if (not (boundp 'pt-))
  (defun pt- (p1 p2)
    (if (and (= (length p1) 3) (= (length p2) 3))
      (list (- (car p1) (car p2)) (- (cadr p1) (cadr p2)) (- (caddr p1) (caddr p2)))
      (list (- (car p1) (car p2)) (- (cadr p1) (cadr p2)))
    )
  )
)

(if (not (boundp 'get-rebar-weight))
  (defun get-rebar-weight (diameter)
    (let ((data (assoc diameter *rebar-data*)))
      (if data (cadr data) 0.0)
    )
  )
)

(if (not (boundp 'get-rebar-area))
  (defun get-rebar-area (diameter)
    (let ((data (assoc diameter *rebar-data*)))
      (if data (caddr data) 0.0)
    )
  )
)

(if (not (boundp 'get-diameter-color))
  (defun get-diameter-color (diameter)
    (cdr (assoc diameter *diameter-colors*))
  )
)

(if (not (boundp 'create-layer))
  (defun create-layer (layer-name color linetype)
    (if (not (tblsearch "LAYER" layer-name))
      (command "_.-LAYER" "_N" layer-name "_C" color "" "_L" linetype "" "")
    )
  )
)

(if (not (boundp 'set-current-layer))
  (defun set-current-layer (layer-name)
    (if (tblsearch "LAYER" layer-name)
      (command "_.-LAYER" "_S" layer-name "")
      (create-layer layer-name 7 *linetype-continuous*)
    )
  )
)

(if (not (boundp 'confirm))
  (defun confirm (prompt)
    (initget 1 "Evet Hayır E H")
    (cond
      ((= (getkword (strcat prompt " [Evet/Hayır] <Evet>: ")) "Evet") T)
      (T nil)
    )
  )
)

(if (not (boundp 'get-positive-number))
  (defun get-positive-number (prompt default)
    (let ((value (getreal (strcat prompt " <" (rtos default) ">: "))))
      (if (or (not value) (<= value 0)) default value)
    )
  )
)

(if (not (boundp 'select-diameter))
  (defun select-diameter (prompt)
    (let ((diameter 16))
      (initget 1 "8 10 12 14 16 18 20 22 24 26 28 30 32")
      (setq diameter (getint (strcat prompt " [8/10/12/14/16/18/20/22/24/26/28/30/32] <16>: ")))
      (if (and diameter (not (member diameter '(8 10 12 14 16 18 20 22 24 26 28 30 32))))
        (progn (alert "Geçersiz çap! 16 olarak ayarlandı.") 16)
        (if (not diameter) 16 diameter)
      )
    )
  )
)

;; ============================================
;; 4. KOLON/PERDE KATMANLARI
;; ============================================

(defun create-column-layers ()
  "Kolon/Perde donatı için katmanları oluştur"
  (foreach layer-info *layer-colors*
    (create-layer (car layer-info) (cdr layer-info) *linetype-continuous*)
  )
  (create-layer "REBAR-COLUMN" 4 *linetype-continuous*)
  (create-layer "REBAR-COLUMN-ETRIYE" 6 *linetype-continuous*)
  (create-layer "REBAR-COLUMN-TOP" 2 *linetype-continuous*)
  (create-layer "REBAR-COLUMN-BOT" 3 *linetype-continuous*)
  (princ "\nKolon katmanları oluşturuldu.")
)

;; ============================================
;; 5. KOLON DONATI HESAPLAMA FONKSİYONLARI
;; ============================================

;; --- Boyuna Donatı Sayısını Hesapla ---
(defun calculate-longitudinal-count (width height spacing cover)
  "Kolon genişliği ve yüksekliğine göre boyuna donatı sayısını hesapla"
  (let* (
    (effective-width (- width (* 2 cover)))
    (effective-height (- height (* 2 cover)))
    (count-width (fix (/ effective-width spacing)))
    (count-height (fix (/ effective-height spacing)))
    )
    (max 1 (* (1+ count-width) (1+ count-height)))
  )
)

;; --- Etriye Sayısını Hesapla ---
(defun calculate-stirrup-count (height spacing cover)
  "Kolon yüksekliğine göre etriye sayısını hesapla"
  (let* (
    (effective-height (- height (* 2 cover)))
    (count (fix (/ effective-height spacing)))
    )
    (max 1 (1+ count))  ; +1 çünkü başlangıç ve bitişte de etriye var
  )
)

;; --- Boyuna Donatı Ağırlığını Hesapla ---
(defun calculate-longitudinal-weight (count length diameter)
  "Boyuna donatı toplam ağırlığını hesapla"
  (* count length (get-rebar-weight diameter) 0.01)  ; cm -> m
)

;; --- Etriye Ağırlığını Hesapla ---
(defun calculate-stirrup-weight (count perimeter diameter)
  "Etriye donatı toplam ağırlığını hesapla"
  (* count perimeter (get-rebar-weight diameter) 0.01)  ; cm -> m
)

;; ============================================
;; 6. KOLON ÇİZİM FONKSİYONLARI
;; ============================================

;; --- Kolon Kalıbını Çiz ---
(defun draw-column-outline (base-point width length height)
  "Kolon kalıbını çiz"
  (set-current-layer "REBAR-COLUMN")
  (let ((pts (list
    base-point
    (pt+ base-point (list width 0))
    (pt+ base-point (list width length))
    (pt+ base-point (list 0 length))
    base-point
  )))
    (command "_.PLINE" pts "")
    (vla-put-closed (vlax-ename->vla-object (entlast)) :vlax-true)
    (vla-put-color (vlax-ename->vla-object (entlast)) 4)  ; Cyan
  )
)

;; --- Boyuna Donatı Çiz ---
(defun draw-longitudinal-rebar (center-point radius height diameter count)
  "Dairesel kolonda boyuna donatı çiz"
  (set-current-layer "REBAR-COLUMN")
  (let ((angle-step (/ (* 2 pi) count)))
    (dotimes (i count)
      (let* (
        (angle (* i angle-step))
        (x (+ (car center-point) (* radius (sin angle))))
        (y (+ (cadr center-point) (* radius (cos angle))))
        (start-pt (list x y (caddr center-point)))
        (end-pt (list x y (+ (caddr center-point) height)))
        )
        (command "_.LINE" start-pt end-pt "")
        (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter))
      )
    )
  )
)

;; --- Dikdörtgen Kolon Boyuna Donatı Çiz ---
(defun draw-rectangular-longitudinal (base-point width length height 
                                      diameter-x diameter-y spacing cover layers)
  "Dikdörtgen kolonda boyuna donatı çiz"
  (set-current-layer "REBAR-COLUMN")
  
  ;; X doğrultusu donatılar
  (let* (
    (count-x (calculate-rebar-count width spacing cover))
    (z-bottom (+ (caddr base-point) cover))
    (z-top (+ (caddr base-point) height cover))
    )
    (dotimes (i count-x)
      (let* (
        (y-pos (+ (cadr base-point) cover (* i spacing)))
        (start-pt (list (car base-point) y-pos z-bottom))
        (end-pt (list (car base-point) y-pos z-top))
        )
        (command "_.LINE" start-pt end-pt "")
        (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter-x))
      )
    )
    
    ;; Y doğrultusu donatılar
    (let* (
      (count-y (calculate-rebar-count length spacing cover))
    )
      (dotimes (i count-y)
        (let* (
          (x-pos (+ (car base-point) cover (* i spacing)))
          (start-pt (list x-pos (cadr base-point) z-bottom))
          (end-pt (list x-pos (cadr base-point) z-top))
          )
          (command "_.LINE" start-pt end-pt "")
          (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter-y))
        )
      )
    )
  )
)

;; --- Etriye Çiz ---
(defun draw-stirrup (base-point width length height stirrup-diameter spacing cover)
  "Kolon etriyelerini çiz"
  (set-current-layer "REBAR-COLUMN-ETRIYE")
  
  (let* (
    (count (calculate-stirrup-count height spacing cover))
    (z-bottom (+ (caddr base-point) cover))
    (z-step spacing)
    )
    (dotimes (i count)
      (let* (
        (z-pos (+ z-bottom (* i z-step)))
        (pts (list
          (list (+ (car base-point) cover) (+ (cadr base-point) cover) z-pos)
          (list (- (car base-point) cover (+ (cadr base-point) length) z-pos)
          (list (- (car base-point) cover - (cadr base-point) cover) z-pos)
          (list (+ (car base-point) cover - (cadr base-point) cover) z-pos)
          (list (+ (car base-point) cover (+ (cadr base-point) cover) z-pos)
        ))
        )
        (command "_.PLINE" pts "")
        (vla-put-closed (vlax-ename->vla-object (entlast)) :vlax-true)
        (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color stirrup-diameter))
      )
    )
  )
)

;; --- Etriye Boyut Çizgilerini Çiz ---
(defun draw-stirrup-dimensions (base-point width length height stirrup-diameter spacing cover)
  "Etriye boyut çizgilerini çiz"
  (set-current-layer "REBAR-DIM")
  
  ;; Etriye aralığı boyutu
  (let* (
    (count (calculate-stirrup-count height spacing cover))
    (z-bottom (+ (caddr base-point) cover))
    (z-top (+ z-bottom (* (1- count) spacing)))
    (mid-x (+ (car base-point) (/ width 2)))
    (mid-y (+ (cadr base-point) (/ length 2)))
    )
    (command "_.DIM" "_VER"
      (list mid-x mid-y z-bottom)
      (list mid-x mid-y z-top)
      (list (+ mid-x 5) mid-y (/ (+ z-bottom z-top) 2)) "")
  )
)

;; ============================================
;; 7. KOLON DONATI ANA FONKSİYONU
;; ============================================

(defun place-column-rebar (base-point width length height
                          long-diameter-x long-diameter-y stirrup-diameter
                          long-spacing stirrup-spacing cover / 
                          long-count-x long-count-y stirrup-count
                          long-weight stirrup-weight total-weight
                          perimeter)
  "Kolon üzerinde donatı yerleştir"
  
  ;; Kolon kalıbını çiz
  (draw-column-outline base-point width length height)
  
  ;; Boyuna donatı sayısını hesapla
  (setq long-count-x (calculate-rebar-count width long-spacing cover))
  (setq long-count-y (calculate-rebar-count length long-spacing cover))
  
  ;; Boyuna donatı çiz
  (draw-rectangular-longitudinal base-point width length height
                                long-diameter-x long-diameter-y long-spacing cover 1)
  
  ;; Etriye sayısını hesapla
  (setq stirrup-count (calculate-stirrup-count height stirrup-spacing cover))
  
  ;; Etriye çiz
  (draw-stirrup base-point width length height stirrup-diameter stirrup-spacing cover)
  
  ;; Etriye çevresini hesapla (cm)
  (setq perimeter (* 2 (+ width length)))
  
  ;; Ağırlıkları hesapla
  (setq long-weight
    (+ 
      (calculate-longitudinal-weight long-count-x height long-diameter-x)
      (calculate-longitudinal-weight long-count-y height long-diameter-y)
    )
  )
  
  (setq stirrup-weight
    (calculate-stirrup-weight stirrup-count perimeter stirrup-diameter)
  )
  
  (setq total-weight (+ long-weight stirrup-weight))
  
  ;; Etiketleri yerleştir
  (set-current-layer "REBAR-TEXT")
  
  ;; Boyuna donatı etiketi
  (command "_.TEXT" "_MC"
    (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 5) (/ height 2)))
    2.5 "0"
    (strcat "Boyuna: " (itoa long-count-x) "×Ø" (itoa long-diameter-x) 
            " + " (itoa long-count-y) "×Ø" (itoa long-diameter-y))
  )
  
  ;; Etriye etiketi
  (command "_.TEXT" "_MC"
    (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 8) (/ height 2)))
    2.5 "0"
    (strcat "Etriye: Ø" (itoa stirrup-diameter) "-" (itoa (int stirrup-spacing)) "/" (itoa (int stirrup-spacing)))
  )
  
  ;; Toplam ağırlık etiketi
  (command "_.TEXT" "_MC"
    (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 11) (/ height 2)))
    2.5 "0"
    (strcat "Toplam Ağırlık: " (rtos total-weight 2 2) " kg")
  )
  
  ;; Boyut çizgilerini çiz
  (draw-stirrup-dimensions base-point width length height stirrup-diameter stirrup-spacing cover)
  
  ;; Sonuçları döndür
  (list
    :width width
    :length length
    :height height
    :long-diameter-x long-diameter-x
    :long-diameter-y long-diameter-y
    :stirrup-diameter stirrup-diameter
    :long-spacing long-spacing
    :stirrup-spacing stirrup-spacing
    :cover cover
    :long-count-x long-count-x
    :long-count-y long-count-y
    :stirrup-count stirrup-count
    :perimeter perimeter
    :long-weight long-weight
    :stirrup-weight stirrup-weight
    :total-weight total-weight
  )
)

;; ============================================
;; 8. PERDE DONATI FONKSİYONU
;; ============================================

(defun place-wall-rebar (base-point width length height
                        horizontal-diameter vertical-diameter stirrup-diameter
                        h-spacing v-spacing stirrup-spacing cover / 
                        h-count v-count stirrup-count
                        h-weight v-weight stirrup-weight total-weight)
  "Perde üzerinde donatı yerleştir"
  
  ;; Perde kalıbını çiz
  (draw-column-outline base-point width length height)
  
  ;; Yatay donatı sayısını hesapla
  (setq h-count (calculate-rebar-count length h-spacing cover))
  
  ;; Dikey donatı sayısını hesapla
  (setq v-count (calculate-rebar-count width v-spacing cover))
  
  ;; Yatay donatı çiz (her katman)
  (set-current-layer "REBAR-COLUMN")
  (dotimes (i h-count)
    (let* (
      (y-pos (+ (cadr base-point) cover (* i h-spacing)))
      (start-pt (list (car base-point) y-pos (+ (caddr base-point) cover)))
      (end-pt (list (+ (car base-point) width) y-pos (+ (caddr base-point) cover)))
      )
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color horizontal-diameter))
    )
  )
  
  ;; Dikey donatı çiz
  (dotimes (i v-count)
    (let* (
      (x-pos (+ (car base-point) cover (* i v-spacing)))
      (start-pt (list x-pos (cadr base-point) (+ (caddr base-point) cover)))
      (end-pt (list x-pos (+ (cadr base-point) length) (+ (caddr base-point) cover)))
      )
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color vertical-diameter))
    )
  )
  
  ;; Etriye (perde için yatay ve dikey)
  (if stirrup-diameter
    (progn
      (setq stirrup-count (calculate-stirrup-count height stirrup-spacing cover))
      (draw-stirrup base-point width length height stirrup-diameter stirrup-spacing cover)
      (setq stirrup-weight (calculate-stirrup-weight stirrup-count (* 2 (+ width length)) stirrup-diameter))
    )
    (setq stirrup-weight 0.0)
  )
  
  ;; Ağırlıkları hesapla
  (setq h-weight (calculate-longitudinal-weight h-count width horizontal-diameter))
  (setq v-weight (calculate-longitudinal-weight v-count length vertical-diameter))
  (setq total-weight (+ h-weight v-weight stirrup-weight))
  
  ;; Etiketleri yerleştir
  (set-current-layer "REBAR-TEXT")
  (command "_.TEXT" "_MC"
    (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 5) (/ height 2)))
    2.5 "0"
    (strcat "Yatay: " (itoa h-count) "×Ø" (itoa horizontal-diameter) 
            " | Dikey: " (itoa v-count) "×Ø" (itoa vertical-diameter))
  )
  
  (if stirrup-diameter
    (command "_.TEXT" "_MC"
      (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 8) (/ height 2)))
      2.5 "0"
      (strcat "Etriye: Ø" (itoa stirrup-diameter) "-" (itoa (int stirrup-spacing)))
    )
  )
  
  (command "_.TEXT" "_MC"
    (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 11) (/ height 2)))
    2.5 "0"
    (strcat "Toplam Ağırlık: " (rtos total-weight 2 2) " kg")
  )
  
  ;; Sonuçları döndür
  (list
    :width width
    :length length
    :height height
    :h-diameter horizontal-diameter
    :v-diameter vertical-diameter
    :stirrup-diameter stirrup-diameter
    :h-spacing h-spacing
    :v-spacing v-spacing
    :stirrup-spacing stirrup-spacing
    :cover cover
    :h-count h-count
    :v-count v-count
    :stirrup-count (if stirrup-diameter stirrup-count 0)
    :h-weight h-weight
    :v-weight v-weight
    :stirrup-weight stirrup-weight
    :total-weight total-weight
  )
)

;; ============================================
;; 9. KULLANICI ARAYÜZÜ FONKSİYONLARI
;; ============================================

;; --- Kolon Tipini Seç ---
(defun select-column-type (prompt / type)
  "Kolon tipini seç"
  (initget 1 "Kare Dikdörtgen Dairesel K D")
  (setq type (getkword (strcat prompt " [Kare/Dikdörtgen/Dairesel] <Dikdörtgen>: ")))
  (cond
    ((or (not type) (= type "Dikdörtgen") (= type "D")) "Dikdörtgen")
    ((or (= type "Kare") (= type "K")) "Kare")
    ((= type "Dairesel") "Dairesel")
    (T "Dikdörtgen")
  )
)

;; --- Etriye Çapını Seç ---
(defun select-stirrup-diameter (prompt / diameter)
  "Etriye çapını seç"
  (setq diameter 8)  ; Varsayılan
  (initget 1 "6 8 10 12 14 16")
  (setq diameter (getint (strcat prompt " [6/8/10/12/14/16] <8>: ")))
  (if (and diameter (not (member diameter '(6 8 10 12 14 16))))
    (progn (alert "Geçersiz etriye çapı! 8 olarak ayarlandı.") 8)
    (if (not diameter) 8 diameter)
  )
)

;; ============================================
;; 10. ANA KOMUTLAR
;; ============================================

(defun C:REBAR-COLUMN ( / 
  base-point width length height
  long-diameter-x long-diameter-y stirrup-diameter
  long-spacing stirrup-spacing cover
  column-type result table-pos
)
  "Ana fonksiyon: Kolon donatı yerleştirme"
  
  (vl-load-com)
  (vla-startundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== REBAR-Kolon: Kolon Donatı Yerleştirme ===")
  (princ "\nTürkiye Standartlarına Göre (TS 500)")
  
  ;; Katmanları oluştur
  (create-column-layers)
  
  ;; 1. Kolon tipini ve boyutlarını al
  (princ "\n--- Kolon Tipi ve Boyutları ---")
  (setq column-type (select-column-type "Kolon tipi"))
  
  (setq base-point (getpoint "\nKolon taban noktasını seçiniz: "))
  
  (if (= column-type "Kare")
    (progn
      (setq width (get-positive-number "\nKolon genişliğini giriniz (cm): " 50.0))
      (setq length width)
    )
    (progn
      (setq width (get-positive-number "\nKolon genişliğini giriniz (cm): " 50.0))
      (setq length (get-positive-number "Kolon uzunluğunu giriniz (cm): " 50.0))
    )
  )
  
  (setq height (get-positive-number "Kolon yüksekliğini giriniz (cm): " 300.0))
  
  ;; 2. Donatı parametrelerini al
  (princ "\n--- Boyuna Donatı ---")
  (setq long-diameter-x (select-diameter "X doğrultusu boyuna donatı çapı"))
  (setq long-diameter-y (select-diameter "Y doğrultusu boyuna donatı çapı"))
  (setq long-spacing (get-positive-number "Boyuna donatı aralığı (cm): " 20.0))
  
  (princ "\n--- Etriye Donatı ---")
  (setq stirrup-diameter (select-stirrup-diameter "Etriye çapı"))
  (setq stirrup-spacing (get-positive-number "Etriye aralığı (cm): " 15.0))
  
  (princ "\n--- Diğer Parametreler ---")
  (setq cover (get-positive-number "Paspayı mesafesi (cm): " 3.0))
  
  ;; 3. Ön izleme ve onay
  (princ "\n--- Ön İzleme ---")
  (princ (strcat "\nKolon Tipi: " column-type))
  (princ (strcat "\nBoyutlar: " (rtos width 2 1) "×" (rtos length 2 1) "×" (rtos height 2 1) " cm"))
  (princ (strcat "\nBoyuna X: Ø" (itoa long-diameter-x) " - " (rtos long-spacing 2 1) " cm"))
  (princ (strcat "\nBoyuna Y: Ø" (itoa long-diameter-y) " - " (rtos long-spacing 2 1) " cm"))
  (princ (strcat "\nEtriye: Ø" (itoa stirrup-diameter) " - " (rtos stirrup-spacing 2 1) " cm"))
  (princ (strcat "\nPaspayı: " (rtos cover 2 1) " cm"))
  
  (if (not (confirm "\nDonatı yerleştirilsin mi?"))
    (progn
      (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
      (princ)
      (exit)
    )
  )
  
  ;; 4. Donatı yerleştir
  (setq result
    (place-column-rebar 
      base-point width length height
      long-diameter-x long-diameter-y stirrup-diameter
      long-spacing stirrup-spacing cover
    )
  )
  
  (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== İşlem Tamamlandı ===")
  (princ (strcat "\nToplam Donatı Ağırlığı: " (rtos (nth 17 result) 2 2) " kg"))
  (princ (strcat "\nBoyuna Donatı: " (itoa (nth 8 result)) "×Ø" (itoa (nth 4 result)) 
                 " + " (itoa (nth 9 result)) "×Ø" (itoa (nth 5 result))))
  (princ (strcat "\nEtriye: " (itoa (nth 10 result)) " adet Ø" (itoa (nth 6 result))))
  (princ)
)

;; --- Perde Donatı Komutu ---
(defun C:REBAR-WALL ( / 
  base-point width length height
  h-diameter v-diameter stirrup-diameter
  h-spacing v-spacing stirrup-spacing cover
  result
)
  "Ana fonksiyon: Perde donatı yerleştirme"
  
  (vl-load-com)
  (vla-startundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== REBAR-Kolon: Perde Donatı Yerleştirme ===")
  (princ "\nTürkiye Standartlarına Göre (TS 500)")
  
  ;; Katmanları oluştur
  (create-column-layers)
  
  ;; 1. Perde boyutlarını al
  (princ "\n--- Perde Boyutları ---")
  (setq base-point (getpoint "\nPerde köşe noktasını seçiniz: "))
  (setq width (get-positive-number "\nPerde kalınlığını giriniz (cm): " 20.0))
  (setq length (get-positive-number "Perde uzunluğunu giriniz (cm): " 300.0))
  (setq height (get-positive-number "Perde yüksekliğini giriniz (cm): " 300.0))
  
  ;; 2. Donatı parametrelerini al
  (princ "\n--- Yatay Donatı ---")
  (setq h-diameter (select-diameter "Yatay donatı çapı"))
  (setq h-spacing (get-positive-number "Yatay donatı aralığı (cm): " 20.0))
  
  (princ "\n--- Dikey Donatı ---")
  (setq v-diameter (select-diameter "Dikey donatı çapı"))
  (setq v-spacing (get-positive-number "Dikey donatı aralığı (cm): " 20.0))
  
  (princ "\n--- Etriye Donatı (opsiyonel) ---")
  (setq stirrup-diameter (select-stirrup-diameter "Etriye çapı (0 için yok)"))
  (if (= stirrup-diameter 0) (setq stirrup-diameter nil))
  (if stirrup-diameter
    (setq stirrup-spacing (get-positive-number "Etriye aralığı (cm): " 20.0))
    (setq stirrup-spacing 0)
  )
  
  (princ "\n--- Diğer Parametreler ---")
  (setq cover (get-positive-number "Paspayı mesafesi (cm): " 3.0))
  
  ;; 3. Ön izleme ve onay
  (princ "\n--- Ön İzleme ---")
  (princ (strcat "\nPerde: " (rtos width 2 1) "×" (rtos length 2 1) "×" (rtos height 2 1) " cm"))
  (princ (strcat "\nYatay: Ø" (itoa h-diameter) " - " (rtos h-spacing 2 1) " cm"))
  (princ (strcat "\nDikey: Ø" (itoa v-diameter) " - " (rtos v-spacing 2 1) " cm"))
  (if stirrup-diameter
    (princ (strcat "\nEtriye: Ø" (itoa stirrup-diameter) " - " (rtos stirrup-spacing 2 1) " cm")))
  (princ (strcat "\nPaspayı: " (rtos cover 2 1) " cm"))
  
  (if (not (confirm "\nDonatı yerleştirilsin mi?"))
    (progn
      (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
      (princ)
      (exit)
    )
  )
  
  ;; 4. Donatı yerleştir
  (setq result
    (place-wall-rebar 
      base-point width length height
      h-diameter v-diameter stirrup-diameter
      h-spacing v-spacing stirrup-spacing cover
    )
  )
  
  (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== İşlem Tamamlandı ===")
  (princ (strcat "\nToplam Donatı Ağırlığı: " (rtos (nth 13 result) 2 2) " kg"))
  (princ)
)

;; ============================================
;; 11. OTOMATİK YÜKLEME VE KOMUTLAR
;; ============================================

(princ "\nREBAR-Kolon v1.0 LISP dosyası yüklendi.")
(princ "\nKullanılabilir komutlar:")
(princ "\n  - REBAR-COLUMN: Kolon donatı yerleştir")
(princ "\n  - RK: Kolon donatı (kısaltma)")
(princ "\n  - REBAR-WALL: Perde donatı yerleştir")
(princ "\n  - RP: Perde donatı (kısaltma)")
(princ)

;; Komutları tanımla
(defun C:RK () (C:REBAR-COLUMN))
(defun C:RC () (C:REBAR-COLUMN))
(defun C:RP () (C:REBAR-WALL))
(defun C:RW () (C:REBAR-WALL))

(princ "\nREBAR-Kolon.lsp yüklendi.\n")
(princ)
