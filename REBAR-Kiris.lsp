;;
;; REBAR-Kiris.lsp
;; ============================================
;; AutoCAD LISP - Kiriş Donatı Yerleştirme
;; Türkiye Standartlarına Göre (TS 500)
;; ============================================
;; Oluşturma: 2024
;; Sürüm: 1.0
;;

;; ============================================
;; 1. ORTAK VERİ YAPILARI
;; ============================================

;; Eğer REBAR-Temel.lsp yüklenmediyse, veri yapılarını tekrar tanımla
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
    
    (setq *min-cover* 2.5)
    
    (setq *layer-colors* '(
        ("REBAR-FOOTING"     . 1)
        ("REBAR-COLUMN"      . 4)
        ("REBAR-BEAM"        . 2)
        ("REBAR-BEAM-TOP"    . 2)
        ("REBAR-BEAM-BOT"    . 3)
        ("REBAR-BEAM-ETRIYE" . 6)
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
;; 2. KİRİŞ VERİ YAPILARI
;; ============================================

;; --- Kiriş Tipi Tanımları ---
(setq *beam-types* '(
    ("Dikdörtgen" . "RECTANGULAR")
    ("T" . "T-SHAPED")
    ("L" . "L-SHAPED")
    ("Kutu" . "BOX")
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
    (setq value (getreal (strcat prompt " <" (rtos default) ">: ")))
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

(if (not (boundp 'select-stirrup-diameter))
  (defun select-stirrup-diameter (prompt / diameter)
    (setq diameter 8)
    (initget 1 "6 8 10 12 14 16")
    (setq diameter (getint (strcat prompt " [6/8/10/12/14/16] <8>: ")))
    (if (and diameter (not (member diameter '(6 8 10 12 14 16))))
      (progn (alert "Geçersiz etriye çapı! 8 olarak ayarlandı.") 8)
      (if (not diameter) 8 diameter)
    )
  )
)

;; ============================================
;; 4. KİRİŞ KATMANLARI
;; ============================================

(defun create-beam-layers ()
  "Kiriş donatı için katmanları oluştur"
  (foreach layer-info *layer-colors*
    (create-layer (car layer-info) (cdr layer-info) *linetype-continuous*)
  )
  (create-layer "REBAR-BEAM" 2 *linetype-continuous*)
  (create-layer "REBAR-BEAM-TOP" 2 *linetype-continuous*)
  (create-layer "REBAR-BEAM-BOT" 3 *linetype-continuous*)
  (create-layer "REBAR-BEAM-ETRIYE" 6 *linetype-continuous*)
  (princ "\nKiriş katmanları oluşturuldu.")
)

;; ============================================
;; 5. KİRİŞ DONATI HESAPLAMA FONKSİYONLARI
;; ============================================

;; --- Donatı Sayısını Hesapla (Kiriş için) ---
(defun calculate-beam-rebar-count (length spacing cover)
  "Kiriş uzunluğuna göre donatı sayısını hesapla"
  (let* (
    (effective-length (- length (* 2 cover)))
    (count (fix (/ effective-length spacing)))
    )
    (max 2 (1+ count))  ; Minimum 2 donatı (mesnetler)
  )
)

;; --- Alt Donatı Sayısını Hesapla ---
(defun calculate-bottom-rebar-count (length spacing cover)
  "Kiriş alt donatı sayısını hesapla"
  (calculate-beam-rebar-count length spacing cover)
)

;; --- Üst Donatı Sayısını Hesapla ---
(defun calculate-top-rebar-count (length span-length spacing cover)
  "Kiriş üst donatı sayısını hesapla (mesnet bölgeleri)"
  (let* (
    (effective-length (- span-length (* 2 cover)))
    (support-length (* 0.2 span-length))  ; Mesnet bölgesi uzunluğu
    (count (fix (/ support-length spacing)))
    )
    (max 2 (1+ count))  ; Minimum 2 donatı
  )
)

;; --- Etriye Sayısını Hesapla (Kiriş) ---
(defun calculate-beam-stirrup-count (length spacing cover)
  "Kiriş etriye sayısını hesapla"
  (let* (
    (effective-length (- length (* 2 cover)))
    (count (fix (/ effective-length spacing)))
    )
    (max 1 (1+ count))
  )
)

;; ============================================
;; 6. KİRİŞ ÇİZİM FONKSİYONLARI
;; ============================================

;; --- Kiriş Kalıbını Çiz ---
(defun draw-beam-outline (start-point end-point width height)
  "Kiriş kalıbını çiz"
  (set-current-layer "REBAR-BEAM")
  (let* (
    (length (dist start-point end-point))
    (angle (angle start-point end-point))
    (pts (list
      start-point
      (polar start-point angle width)
      (polar end-point (+ angle pi) width)
      end-point
      start-point
    ))
    )
    (command "_.PLINE" pts "")
    (vla-put-closed (vlax-ename->vla-object (entlast)) :vlax-true)
    (vla-put-color (vlax-ename->vla-object (entlast)) 2)  ; Sarı
  )
)

;; --- Alt Donatı Çiz ---
(defun draw-bottom-rebar (start-point end-point width height 
                         diameter spacing cover / 
                         length count z-pos)
  "Kiriş alt donatısını çiz"
  (set-current-layer "REBAR-BEAM-BOT")
  
  (setq length (dist start-point end-point))
  (setq count (calculate-bottom-rebar-count length spacing cover))
  (setq z-pos (+ (caddr start-point) cover))
  
  (dotimes (i count)
    (let* (
      (ratio (/ i (1- count)))
      (x-pos (+ (car start-point) (* ratio (- (car end-point) (car start-point)))))
      (y-pos (+ (cadr start-point) (* ratio (- (cadr end-point) (cadr start-point)))))
      (start-pt (list x-pos y-pos z-pos))
      (end-pt (list (+ x-pos (* (sin (angle start-point end-point)) width)) 
                     (- y-pos (* (cos (angle start-point end-point)) width)) 
                     z-pos))
      )
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter))
    )
  )
)

;; --- Üst Donatı Çiz ---
(defun draw-top-rebar (start-point end-point width height 
                       diameter spacing cover span-length / 
                       length count z-pos)
  "Kiriş üst donatısını çiz (mesnet bölgeleri)"
  (set-current-layer "REBAR-BEAM-TOP")
  
  (setq length (dist start-point end-point))
  (setq count (calculate-top-rebar-count length span-length spacing cover))
  (setq z-pos (+ (caddr start-point) height cover))
  
  ;; Başlangıç mesneti
  (dotimes (i count)
    (let* (
      (x-pos (+ (car start-point) (* i spacing (sin (angle start-point end-point)))))
      (y-pos (+ (cadr start-point) (* i spacing (cos (angle start-point end-point)))))
      (start-pt (list x-pos y-pos z-pos))
      (end-pt (list (+ x-pos (* (sin (angle start-point end-point)) width)) 
                     (- y-pos (* (cos (angle start-point end-point)) width)) 
                     z-pos))
      )
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter))
    )
  )
  
  ;; Bitiş mesneti
  (dotimes (i count)
    (let* (
      (x-pos (- (car end-point) (* i spacing (sin (angle start-point end-point)))))
      (y-pos (- (cadr end-point) (* i spacing (cos (angle start-point end-point)))))
      (start-pt (list x-pos y-pos z-pos))
      (end-pt (list (+ x-pos (* (sin (angle start-point end-point)) width)) 
                     (- y-pos (* (cos (angle start-point end-point)) width)) 
                     z-pos))
      )
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter))
    )
  )
)

;; --- Etriye Çiz (Kiriş) ---
(defun draw-beam-stirrup (start-point end-point width height 
                         stirrup-diameter spacing cover / 
                         length count z-pos z-step)
  "Kiriş etriyelerini çiz"
  (set-current-layer "REBAR-BEAM-ETRIYE")
  
  (setq length (dist start-point end-point))
  (setq count (calculate-beam-stirrup-count length spacing cover))
  (setq z-pos (+ (caddr start-point) cover))
  (setq z-step spacing)
  
  (dotimes (i count)
    (let* (
      (z-current (+ z-pos (* i z-step)))
      (ratio (/ (* i spacing) length))
      (x-pos (+ (car start-point) (* ratio (- (car end-point) (car start-point)))))
      (y-pos (+ (cadr start-point) (* ratio (- (cadr end-point) (cadr start-point)))))
      (pts (list
        (list (+ x-pos (* (sin (angle start-point end-point)) cover)) 
              (- y-pos (* (cos (angle start-point end-point)) cover)) 
              z-current)
        (list (+ x-pos (* (sin (angle start-point end-point)) (- cover width))) 
              (- y-pos (* (cos (angle start-point end-point)) (- cover width))) 
              z-current)
        (list (+ x-pos (* (sin (angle start-point end-point)) (- cover width))) 
              (- y-pos (* (cos (angle start-point end-point)) cover)) 
              z-current)
        (list (+ x-pos (* (sin (angle start-point end-point)) cover)) 
              (- y-pos (* (cos (angle start-point end-point)) (- cover width))) 
              z-current)
        (list (+ x-pos (* (sin (angle start-point end-point)) cover)) 
              (- y-pos (* (cos (angle start-point end-point)) cover)) 
              z-current)
      ))
      )
      (command "_.PLINE" pts "")
      (vla-put-closed (vlax-ename->vla-object (entlast)) :vlax-true)
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color stirrup-diameter))
    )
  )
)

;; ============================================
;; 7. KİRİŞ DONATI ANA FONKSİYONU
;; ============================================

(defun place-beam-rebar (start-point end-point width height
                        bottom-diameter top-diameter stirrup-diameter
                        bottom-spacing top-spacing stirrup-spacing cover / 
                        length span-length
                        bottom-count top-count stirrup-count
                        bottom-weight top-weight stirrup-weight total-weight
                        perimeter)
  "Kiriş üzerinde donatı yerleştir"
  
  (setq length (dist start-point end-point))
  (setq span-length length)  ; Basit kiriş için açıklık = uzunluk
  
  ;; Kiriş kalıbını çiz
  (draw-beam-outline start-point end-point width height)
  
  ;; Alt donatı çiz
  (draw-bottom-rebar start-point end-point width height 
                     bottom-diameter bottom-spacing cover)
  
  ;; Üst donatı çiz
  (draw-top-rebar start-point end-point width height 
                  top-diameter top-spacing cover span-length)
  
  ;; Etriye çiz
  (draw-beam-stirrup start-point end-point width height 
                     stirrup-diameter stirrup-spacing cover)
  
  ;; Donatı sayılarını hesapla
  (setq bottom-count (calculate-bottom-rebar-count length bottom-spacing cover))
  (setq top-count (calculate-top-rebar-count length span-length top-spacing cover))
  (setq stirrup-count (calculate-beam-stirrup-count length stirrup-spacing cover))
  
  ;; Etriye çevresini hesapla
  (setq perimeter (* 2 (+ width height)))
  
  ;; Ağırlıkları hesapla
  (setq bottom-weight (* bottom-count length (get-rebar-weight bottom-diameter) 0.01))
  (setq top-weight (* top-count (* 2 (* 0.2 span-length)) (get-rebar-weight top-diameter) 0.01))  ; Mesnet bölgeleri
  (setq stirrup-weight (* stirrup-count perimeter (get-rebar-weight stirrup-diameter) 0.01))
  
  (setq total-weight (+ bottom-weight top-weight stirrup-weight))
  
  ;; Etiketleri yerleştir
  (set-current-layer "REBAR-TEXT")
  
  (let* (
    (mid-point (mapcar '/ (mapcar '+ start-point end-point) '(2 2 2)))
    (offset-point (pt+ mid-point (list 0 5 0)))
    )
    (command "_.TEXT" "_MC" offset-point 2.5 "0"
      (strcat "Alt: " (itoa bottom-count) "×Ø" (itoa bottom-diameter)))
    
    (command "_.TEXT" "_MC" (pt+ offset-point (list 0 3 0)) 2.5 "0"
      (strcat "Üst: " (itoa top-count) "×Ø" (itoa top-diameter) " (mesnet)"))
    
    (command "_.TEXT" "_MC" (pt+ offset-point (list 0 1 0)) 2.5 "0"
      (strcat "Etriye: Ø" (itoa stirrup-diameter) "-" (itoa (int stirrup-spacing))))
    
    (command "_.TEXT" "_MC" (pt+ offset-point (list 0 -1 0)) 2.5 "0"
      (strcat "Ağırlık: " (rtos total-weight 2 2) " kg"))
  )
  
  ;; Sonuçları döndür
  (list
    :length length
    :width width
    :height height
    :bottom-diameter bottom-diameter
    :top-diameter top-diameter
    :stirrup-diameter stirrup-diameter
    :bottom-spacing bottom-spacing
    :top-spacing top-spacing
    :stirrup-spacing stirrup-spacing
    :cover cover
    :bottom-count bottom-count
    :top-count top-count
    :stirrup-count stirrup-count
    :perimeter perimeter
    :bottom-weight bottom-weight
    :top-weight top-weight
    :stirrup-weight stirrup-weight
    :total-weight total-weight
  )
)

;; ============================================
;; 8. KULLANICI ARAYÜZÜ FONKSİYONLARI
;; ============================================

;; --- Kiriş Tipini Seç ---
(defun select-beam-type (prompt / type)
  "Kiriş tipini seç"
  (initget 1 "Dikdörtgen T L Kutu")
  (setq type (getkword (strcat prompt " [Dikdörtgen/T/L/Kutu] <Dikdörtgen>: ")))
  (cond
    ((or (not type) (= type "Dikdörtgen")) "Dikdörtgen")
    ((= type "T") "T")
    ((= type "L") "L")
    ((= type "Kutu") "Kutu")
    (T "Dikdörtgen")
  )
)

;; ============================================
;; 9. ANA KOMUTLAR
;; ============================================

(defun C:REBAR-BEAM ( / 
  start-point end-point width height
  bottom-diameter top-diameter stirrup-diameter
  bottom-spacing top-spacing stirrup-spacing cover
  beam-type result
)
  "Ana fonksiyon: Kiriş donatı yerleştirme"
  
  (vl-load-com)
  (vla-startundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== REBAR-Kiriş: Kiriş Donatı Yerleştirme ===")
  (princ "\nTürkiye Standartlarına Göre (TS 500)")
  
  ;; Katmanları oluştur
  (create-beam-layers)
  
  ;; 1. Kiriş tipini ve boyutlarını al
  (princ "\n--- Kiriş Tipi ve Boyutları ---")
  (setq beam-type (select-beam-type "Kiriş tipi"))
  
  (setq start-point (getpoint "\nKiriş başlangıç noktasını seçiniz: "))
  (setq end-point (getpoint "Kiriş bitiş noktasını seçiniz: "))
  
  (setq width (get-positive-number "\nKiriş genişliğini giriniz (cm): " 30.0))
  (setq height (get-positive-number "Kiriş yüksekliğini giriniz (cm): " 50.0))
  
  ;; 2. Donatı parametrelerini al
  (princ "\n--- Alt Donatı ---")
  (setq bottom-diameter (select-diameter "Alt donatı çapı"))
  (setq bottom-spacing (get-positive-number "Alt donatı aralığı (cm): " 15.0))
  
  (princ "\n--- Üst Donatı (Mesnet) ---")
  (setq top-diameter (select-diameter "Üst donatı çapı"))
  (setq top-spacing (get-positive-number "Üst donatı aralığı (cm): " 20.0))
  
  (princ "\n--- Etriye Donatı ---")
  (setq stirrup-diameter (select-stirrup-diameter "Etriye çapı"))
  (setq stirrup-spacing (get-positive-number "Etriye aralığı (cm): " 15.0))
  
  (princ "\n--- Diğer Parametreler ---")
  (setq cover (get-positive-number "Paspayı mesafesi (cm): " 3.0))
  
  ;; 3. Ön izleme ve onay
  (princ "\n--- Ön İzleme ---")
  (princ (strcat "\nKiriş Tipi: " beam-type))
  (princ (strcat "\nBoyutlar: " (rtos (dist start-point end-point) 2 1) "×" (rtos width 2 1) "×" (rtos height 2 1) " cm"))
  (princ (strcat "\nAlt Donatı: Ø" (itoa bottom-diameter) " - " (rtos bottom-spacing 2 1) " cm"))
  (princ (strcat "\nÜst Donatı: Ø" (itoa top-diameter) " - " (rtos top-spacing 2 1) " cm"))
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
    (place-beam-rebar 
      start-point end-point width height
      bottom-diameter top-diameter stirrup-diameter
      bottom-spacing top-spacing stirrup-spacing cover
    )
  )
  
  (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== İşlem Tamamlandı ===")
  (princ (strcat "\nToplam Donatı Ağırlığı: " (rtos (nth 18 result) 2 2) " kg"))
  (princ (strcat "\nAlt Donatı: " (itoa (nth 10 result)) "×Ø" (itoa (nth 4 result))))
  (princ (strcat "\nÜst Donatı: " (itoa (nth 11 result)) "×Ø" (itoa (nth 5 result))))
  (princ (strcat "\nEtriye: " (itoa (nth 12 result)) " adet Ø" (itoa (nth 6 result))))
  (princ)

;; ============================================
;; 10. OTOMATİK YÜKLEME VE KOMUTLAR
;; ============================================

(princ "\nREBAR-Kiriş v1.0 LISP dosyası yüklendi.")
(princ "\nKullanılabilir komutlar:")
(princ "\n  - REBAR-BEAM: Kiriş donatı yerleştir")
(princ "\n  - RB: Kiriş donatı (kısaltma)")
(princ)

;; Komutları tanımla
(defun C:RB () (C:REBAR-BEAM))
(defun C:RK () (C:REBAR-BEAM))  ; RK zaten kolon için kullanılıyor, farklı kısaltma

(princ "\nREBAR-Kiris.lsp yüklendi.\n")
(princ)
