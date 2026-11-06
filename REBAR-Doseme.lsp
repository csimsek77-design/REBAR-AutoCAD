;;
;; REBAR-Doseme.lsp
;; ============================================
;; AutoCAD LISP - Döşeme Donatı Yerleştirme
;; Türkiye Standartlarına Göre (TS 500)
;; ============================================
;; Oluşturma: 2024
;; Sürüm: 1.0
;;

;; ============================================
;; 1. ORTAK VERİ YAPILARI
;; ============================================

(if (not (boundp '*rebar-data*))
  (progn
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
    
    (setq *rebar-grades* '(
        ("S220"   . 2200)
        ("S420"   . 4200)
        ("B420C"  . 4200)
        ("B500C"  . 5000)
    ))
    
    (setq *min-rebar-ratios* '(
        ("Temel"      . 0.008)
        ("Kolon"      . 0.010)
        ("Kiriş"      . 0.008)
        ("Döşeme"     . 0.002)
        ("Perde"      . 0.004)
    ))
    
    (setq *min-cover* 2.0)  ; Döşeme için minimum paspayı
    
    (setq *layer-colors* '(
        ("REBAR-FOOTING"     . 1)
        ("REBAR-COLUMN"      . 4)
        ("REBAR-BEAM"        . 2)
        ("REBAR-SLAB"        . 5)
        ("REBAR-SLAB-TOP"    . 5)
        ("REBAR-SLAB-BOT"    . 3)
        ("REBAR-TEXT"        . 5)
        ("REBAR-TABLE"       . 7)
        ("REBAR-DIM"         . 250)
    ))
    
    (setq *diameter-colors* '(
        (8  . 1)   (10 . 2)   (12 . 3)   (14 . 4)
        (16 . 5)   (18 . 6)   (20 . 7)   (22 . 10)
        (24 . 11)  (26 . 12)  (28 . 13)  (30 . 14)
        (32 . 15)
    ))
    
    (setq *linetype-continuous* "CONTINUOUS")
  )
)

;; ============================================
;; 2. DÖŞEME VERİ YAPILARI
;; ============================================

;; --- Döşeme Tipi Tanımları ---
(setq *slab-types* '(
    ("Tek Doğrultulu" . "ONE-WAY")
    ("Çift Doğrultulu" . "TWO-WAY")
    ("Nervürlü" . "RIBBED")
    ("Kirişsiz" . "FLAT")
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
    (let ((diameter 12))
      (initget 1 "8 10 12 14 16 18 20 22 24 26 28 30 32")
      (setq diameter (getint (strcat prompt " [8/10/12/14/16/18/20/22/24/26/28/30/32] <12>: ")))
      (if (and diameter (not (member diameter '(8 10 12 14 16 18 20 22 24 26 28 30 32))))
        (progn (alert "Geçersiz çap! 12 olarak ayarlandı.") 12)
        (if (not diameter) 12 diameter)
      )
    )
  )
)

;; ============================================
;; 4. DÖŞEME KATMANLARI
;; ============================================

(defun create-slab-layers ()
  "Döşeme donatı için katmanları oluştur"
  (foreach layer-info *layer-colors*
    (create-layer (car layer-info) (cdr layer-info) *linetype-continuous*)
  )
  (create-layer "REBAR-SLAB" 5 *linetype-continuous*)
  (create-layer "REBAR-SLAB-TOP" 5 *linetype-continuous*)
  (create-layer "REBAR-SLAB-BOT" 3 *linetype-continuous*)
  (princ "\nDöşeme katmanları oluşturuldu.")
)

;; ============================================
;; 5. DÖŞEME DONATI HESAPLAMA FONKSİYONLARI
;; ============================================

;; --- Donatı Sayısını Hesapla (Döşeme) ---
(defun calculate-slab-rebar-count (dimension spacing cover)
  "Döşeme boyutuna göre donatı sayısını hesapla"
  (let* (
    (effective-length (- dimension (* 2 cover)))
    (count (fix (/ effective-length spacing)))
    )
    (max 1 (1+ count))  ; +1 çünkü 0'dan başlıyoruz
  )
)

;; --- Toplam Donatı Ağırlığını Hesapla (Döşeme) ---
(defun calculate-slab-rebar-weight (count-x count-y length-x length-y diameter)
  "Döşeme donatı toplam ağırlığını hesapla"
  (let* (
    (total-length-x (* count-y length-x))
    (total-length-y (* count-x length-y))
    (total-length (+ total-length-x total-length-y))
    (weight-per-meter (get-rebar-weight diameter))
    )
    (* total-length weight-per-meter 0.01)  ; cm -> m
  )
)

;; ============================================
;; 6. DÖŞEME ÇİZİM FONKSİYONLARI
;; ============================================

;; --- Döşeme Kalıbını Çiz ---
(defun draw-slab-outline (base-point width length / pts)
  "Döşeme kalıbını çiz"
  (set-current-layer "REBAR-SLAB")
  (setq pts (list
    base-point
    (pt+ base-point (list width 0))
    (pt+ base-point (list width length))
    (pt+ base-point (list 0 length))
    base-point
  ))
  (command "_.PLINE" pts "")
  (vla-put-closed (vlax-ename->vla-object (entlast)) :vlax-true)
  (vla-put-color (vlax-ename->vla-object (entlast)) 5)  ; Mavi
)

;; --- Alt Donatı Ağı Çiz ---
(defun draw-slab-bottom-rebar (base-point width length 
                              diameter-x spacing-x diameter-y spacing-y cover / 
                              count-x count-y)
  "Döşeme alt donatı ağını çiz"
  (set-current-layer "REBAR-SLAB-BOT")
  
  ;; X doğrultusu donatılar
  (setq count-x (calculate-slab-rebar-count width spacing-x cover))
  (dotimes (i count-x)
    (let* (
      (x-pos (+ (car base-point) cover (* i spacing-x)))
      (start-pt (list x-pos (cadr base-point) (caddr base-point)))
      (end-pt (list x-pos (+ (cadr base-point) length) (caddr base-point)))
      )
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter-x))
    )
  )
  
  ;; Y doğrultusu donatılar
  (setq count-y (calculate-slab-rebar-count length spacing-y cover))
  (dotimes (i count-y)
    (let* (
      (y-pos (+ (cadr base-point) cover (* i spacing-y)))
      (start-pt (list (car base-point) y-pos (caddr base-point)))
      (end-pt (list (+ (car base-point) width) y-pos (caddr base-point)))
      )
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter-y))
    )
  )
  
  (list :count-x count-x :count-y count-y)
)

;; --- Üst Donatı Ağı Çiz ---
(defun draw-slab-top-rebar (base-point width length 
                           diameter-x spacing-x diameter-y spacing-y cover thickness / 
                           count-x count-y z-pos)
  "Döşeme üst donatı ağını çiz"
  (set-current-layer "REBAR-SLAB-TOP")
  
  (setq z-pos (+ (caddr base-point) thickness))
  
  ;; X doğrultusu donatılar
  (setq count-x (calculate-slab-rebar-count width spacing-x cover))
  (dotimes (i count-x)
    (let* (
      (x-pos (+ (car base-point) cover (* i spacing-x)))
      (start-pt (list x-pos (cadr base-point) z-pos))
      (end-pt (list x-pos (+ (cadr base-point) length) z-pos))
      )
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter-x))
    )
  )
  
  ;; Y doğrultusu donatılar
  (setq count-y (calculate-slab-rebar-count length spacing-y cover))
  (dotimes (i count-y)
    (let* (
      (y-pos (+ (cadr base-point) cover (* i spacing-y)))
      (start-pt (list (car base-point) y-pos z-pos))
      (end-pt (list (+ (car base-point) width) y-pos z-pos))
      )
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter-y))
    )
  )
  
  (list :count-x count-x :count-y count-y)
)

;; ============================================
;; 7. DÖŞEME DONATI ANA FONKSİYONU
;; ============================================

(defun place-slab-rebar (base-point width length thickness
                        bottom-diameter-x bottom-diameter-y
                        top-diameter-x top-diameter-y
                        spacing-x spacing-y cover layers / 
                        bottom-count top-count
                        bottom-weight top-weight total-weight
                        result-bottom result-top)
  "Döşeme üzerinde donatı yerleştir"
  
  ;; Döşeme kalıbını çiz
  (draw-slab-outline base-point width length)
  
  ;; Alt donatı ağı
  (setq result-bottom
    (draw-slab-bottom-rebar base-point width length 
                            bottom-diameter-x spacing-x bottom-diameter-y spacing-y cover))
  (setq bottom-count (list (nth 0 result-bottom) (nth 1 result-bottom)))
  
  ;; Üst donatı ağı (eğer layers > 1)
  (if (> layers 1)
    (progn
      (setq result-top
        (draw-slab-top-rebar base-point width length 
                            top-diameter-x spacing-x top-diameter-y spacing-y cover thickness))
      (setq top-count (list (nth 0 result-top) (nth 1 result-top)))
    )
    (progn
      (setq top-count '(0 0))
      (setq result-top nil)
    )
  )
  
  ;; Ağırlıkları hesapla
  (setq bottom-weight
    (calculate-slab-rebar-weight 
      (nth 0 bottom-count) (nth 1 bottom-count) 
      width length bottom-diameter-x
    )
  )
  
  (if (> layers 1)
    (setq top-weight
      (calculate-slab-rebar-weight 
        (nth 0 top-count) (nth 1 top-count) 
        width length top-diameter-x
      )
    )
    (setq top-weight 0.0)
  )
  
  (setq total-weight (+ bottom-weight top-weight))
  
  ;; Etiketleri yerleştir
  (set-current-layer "REBAR-TEXT")
  
  (let ((label-pos (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 5) 0))))
    
    ;; Alt donatı etiketi
    (command "_.TEXT" "_MC" label-pos 2.5 "0"
      (strcat "Alt: Ø" (itoa bottom-diameter-x) "-" (itoa (int spacing-x)) "/" (itoa (int spacing-y))))
    
    ;; Üst donatı etiketi (eğer varsa)
    (if (> layers 1)
      (command "_.TEXT" "_MC" (pt+ label-pos (list 0 -3 0)) 2.5 "0"
        (strcat "Üst: Ø" (itoa top-diameter-x) "-" (itoa (int spacing-x)) "/" (itoa (int spacing-y))))
    )
    
    ;; Toplam ağırlık etiketi
    (command "_.TEXT" "_MC" (pt+ label-pos (list 0 -6 0)) 2.5 "0"
      (strcat "Ağırlık: " (rtos total-weight 2 2) " kg"))
    
    ;; Donatı sayısı etiketi
    (command "_.TEXT" "_MC" (pt+ label-pos (list 0 -9 0)) 2.0 "0"
      (strcat "Alt: " (itoa (nth 0 bottom-count)) "×" (itoa (nth 1 bottom-count)) 
              (if (> layers 1) (strcat " | Üst: " (itoa (nth 0 top-count)) "×" (itoa (nth 1 top-count))) "")))
  )
  
  ;; Sonuçları döndür
  (list
    :width width
    :length length
    :thickness thickness
    :bottom-diameter-x bottom-diameter-x
    :bottom-diameter-y bottom-diameter-y
    :top-diameter-x top-diameter-x
    :top-diameter-y top-diameter-y
    :spacing-x spacing-x
    :spacing-y spacing-y
    :cover cover
    :layers layers
    :bottom-count-x (nth 0 bottom-count)
    :bottom-count-y (nth 1 bottom-count)
    :top-count-x (nth 0 top-count)
    :top-count-y (nth 1 top-count)
    :bottom-weight bottom-weight
    :top-weight top-weight
    :total-weight total-weight
  )
)

;; ============================================
;; 8. KULLANICI ARAYÜZÜ FONKSİYONLARI
;; ============================================

;; --- Döşeme Tipini Seç ---
(defun select-slab-type (prompt / type)
  "Döşeme tipini seç"
  (initget 1 "Tek Çift Nervürlü Kirişsiz")
  (setq type (getkword (strcat prompt " [Tek Doğrultulu/Çift Doğrultulu/Nervürlü/Kirişsiz] <Çift Doğrultulu>: ")))
  (cond
    ((or (not type) (= type "Çift") (= type "Çift Doğrultulu")) "Çift Doğrultulu")
    ((= type "Tek") "Tek Doğrultulu")
    ((= type "Nervürlü") "Nervürlü")
    ((= type "Kirişsiz") "Kirişsiz")
    (T "Çift Doğrultulu")
  )
)

;; ============================================
;; 9. ANA KOMUTLAR
;; ============================================

(defun C:REBAR-SLAB ( / 
  base-point width length thickness
  bottom-diameter-x bottom-diameter-y
  top-diameter-x top-diameter-y
  spacing-x spacing-y cover layers
  slab-type result
)
  "Ana fonksiyon: Döşeme donatı yerleştirme"
  
  (vl-load-com)
  (vla-startundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== REBAR-Döşeme: Döşeme Donatı Yerleştirme ===")
  (princ "\nTürkiye Standartlarına Göre (TS 500)")
  
  ;; Katmanları oluştur
  (create-slab-layers)
  
  ;; 1. Döşeme tipini ve boyutlarını al
  (princ "\n--- Döşeme Tipi ve Boyutları ---")
  (setq slab-type (select-slab-type "Döşeme tipi"))
  
  (setq base-point (getpoint "\nDöşeme köşe noktasını seçiniz: "))
  (setq width (get-positive-number "\nDöşeme genişliğini giriniz (cm): " 500.0))
  (setq length (get-positive-number "Döşeme uzunluğunu giriniz (cm): " 600.0))
  (setq thickness (get-positive-number "Döşeme kalınlığını giriniz (cm): " 15.0))
  
  ;; 2. Donatı parametrelerini al
  (princ "\n--- Alt Donatı ---")
  (setq bottom-diameter-x (select-diameter "Alt X doğrultusu donatı çapı"))
  (setq bottom-diameter-y (select-diameter "Alt Y doğrultusu donatı çapı"))
  (setq spacing-x (get-positive-number "X doğrultusu donatı aralığı (cm): " 20.0))
  (setq spacing-y (get-positive-number "Y doğrultusu donatı aralığı (cm): " 20.0))
  
  (princ "\n--- Üst Donatı (opsiyonel) ---")
  (if (confirm "Üst katman donatı eklensin mi?")
    (progn
      (setq top-diameter-x (select-diameter "Üst X doğrultusu donatı çapı"))
      (setq top-diameter-y (select-diameter "Üst Y doğrultusu donatı çapı"))
      (setq layers 2)
    )
    (progn
      (setq top-diameter-x bottom-diameter-x)
      (setq top-diameter-y bottom-diameter-y)
      (setq layers 1)
    )
  )
  
  (princ "\n--- Diğer Parametreler ---")
  (setq cover (get-positive-number "Paspayı mesafesi (cm): " 2.0))
  
  ;; 3. Ön izleme ve onay
  (princ "\n--- Ön İzleme ---")
  (princ (strcat "\nDöşeme Tipi: " slab-type))
  (princ (strcat "\nBoyutlar: " (rtos width 2 1) "×" (rtos length 2 1) "×" (rtos thickness 2 1) " cm"))
  (princ (strcat "\nAlt X: Ø" (itoa bottom-diameter-x) " - " (rtos spacing-x 2 1) " cm"))
  (princ (strcat "\nAlt Y: Ø" (itoa bottom-diameter-y) " - " (rtos spacing-y 2 1) " cm"))
  (if (> layers 1)
    (progn
      (princ (strcat "\nÜst X: Ø" (itoa top-diameter-x) " - " (rtos spacing-x 2 1) " cm"))
      (princ (strcat "\nÜst Y: Ø" (itoa top-diameter-y) " - " (rtos spacing-y 2 1) " cm"))
    )
  )
  (princ (strcat "\nPaspayı: " (rtos cover 2 1) " cm"))
  (princ (strcat "\nKatman: " (itoa layers)))
  
  (if (not (confirm "\nDonatı yerleştirilsin mi?"))
    (progn
      (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
      (princ)
      (exit)
    )
  )
  
  ;; 4. Donatı yerleştir
  (setq result
    (place-slab-rebar 
      base-point width length thickness
      bottom-diameter-x bottom-diameter-y
      top-diameter-x top-diameter-y
      spacing-x spacing-y cover layers
    )
  )
  
  (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== İşlem Tamamlandı ===")
  (princ (strcat "\nToplam Donatı Ağırlığı: " (rtos (nth 18 result) 2 2) " kg"))
  (princ (strcat "\nAlt Donatı: " (itoa (nth 12 result)) "×" (itoa (nth 13 result)) 
                 " Ø" (itoa (nth 4 result)) "/" (itoa (nth 5 result))))
  (if (> (nth 3 result) 1)
    (princ (strcat "\nÜst Donatı: " (itoa (nth 14 result)) "×" (itoa (nth 15 result)) 
                   " Ø" (itoa (nth 6 result)) "/" (itoa (nth 7 result)))))
  )
  (princ)
)

;; ============================================
;; 10. OTOMATİK YÜKLEME VE KOMUTLAR
;; ============================================

(princ "\nREBAR-Döşeme v1.0 LISP dosyası yüklendi.")
(princ "\nKullanılabilir komutlar:")
(princ "\n  - REBAR-SLAB: Döşeme donatı yerleştir")
(princ "\n  - RD: Döşeme donatı (kısaltma)")
(princ)

;; Komutları tanımla
(defun C:RD () (C:REBAR-SLAB))
(defun C:RS () (C:REBAR-SLAB))

(princ "\nREBAR-Doseme.lsp yüklendi.\n")
(princ)
