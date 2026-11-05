;;
;; REBAR-Temel.lsp
;; ============================================
;; AutoCAD LISP - Temel Donati Yerlestirme
;; Turkiye Standartlarina Gore (TS 500)
;; Caplar: 8,10,12,14,16,18,20,22,24,26,28,30,32 mm
;; ============================================
;; Olusturma: 2024
;; Surum: 1.1 - Gelistirilmis
;;

;; ============================================
;; 1. VERI YAPILARI VE SABITLER
;; ============================================

;; --- Donati Caplari ve Agirliklari (Turkiye Standartlari) ---
;; Format: (cap_mm agirlik_kg/m alan_cm2)
(setq *rebar-data* '(
    (8   0.395  0.503)   ; O8
    (10  0.617  0.785)   ; O10
    (12  0.888  1.131)   ; O12
    (14  1.210  1.540)   ; O14
    (16  1.580  2.011)   ; O16
    (18  2.000  2.545)   ; O18
    (20  2.470  3.142)   ; O20
    (22  2.980  3.801)   ; O22
    (24  3.550  4.524)   ; O24
    (26  4.170  5.309)   ; O26
    (28  4.830  6.158)   ; O28
    (30  5.550  7.069)   ; O30
    (32  6.310  8.042)   ; O32
))

;; --- Donati Siniflari ve Akma Dayanimlari ---
(setq *rebar-grades* '(
    ("S220"   . 2200)    ; kg/cm2
    ("S420"   . 4200)
    ("B420C"  . 4200)
    ("B500C"  . 5000)
))

;; --- TS 500 Minimum Donati Oranlari (%) ---
(setq *min-rebar-ratios* '(
    ("Temel"      . 0.008)   ; 0.8permil
    ("Kolon"      . 0.010)   ; 1.0permil
    ("Kiris"      . 0.008)   ; 0.8permil
    ("Doseme"     . 0.002)   ; 0.2permil
    ("Perde"      . 0.004)   ; 0.4permil
))

;; --- Minimum Paspayi (cm) ---
(setq *min-cover* 2.5)

;; --- Katman Renkleri ---
(setq *layer-colors* '(
    ("REBAR-FOOTING"     . 1)
    ("REBAR-FOOTING-TOP" . 2)
    ("REBAR-FOOTING-BOT" . 3)
    ("REBAR-TEXT"        . 5)
    ("REBAR-TABLE"       . 7)
    ("REBAR-DIM"         . 250)
))

;; --- Donati Cap Renkleri ---
(setq *diameter-colors* '(
    (8  . 1)
    (10 . 2)
    (12 . 3)
    (14 . 4)
    (16 . 5)
    (18 . 6)
    (20 . 7)
    (22 . 10)
    (24 . 11)
    (26 . 12)
    (28 . 13)
    (30 . 14)
    (32 . 15)
))

;; --- Cizgi Tipleri ---
(setq *linetype-continuous* "CONTINUOUS")
(setq *linetype-dashed*    "DASHED")
(setq *linetype-center*    "CENTER2")

;; ============================================
;; 2. YARDIMCI FONKSIYONLAR
;; ============================================

(defun pt+ (p1 p2)
  (if (and (= (length p1) 3) (= (length p2) 3))
    (list (+ (car p1) (car p2)) (+ (cadr p1) (cadr p2)) (+ (caddr p1) (caddr p2)))
    (list (+ (car p1) (car p2)) (+ (cadr p1) (cadr p2)))
  )
)

(defun pt- (p1 p2)
  (if (and (= (length p1) 3) (= (length p2) 3))
    (list (- (car p1) (car p2)) (- (cadr p1) (cadr p2)) (- (caddr p1) (caddr p2)))
    (list (- (car p1) (car p2)) (- (cadr p1) (cadr p2)))
  )
)

(defun pt* (p scalar)
  (if (= (length p) 3)
    (list (* (car p) scalar) (* (cadr p) scalar) (* (caddr p) scalar))
    (list (* (car p) scalar) (* (cadr p) scalar))
  )
)

(defun pt/ (p scalar)
  (if (= (length p) 3)
    (list (/ (car p) scalar) (/ (cadr p) scalar) (/ (caddr p) scalar))
    (list (/ (car p) scalar) (/ (cadr p) scalar))
  )
)

(defun dist (p1 p2)
  (sqrt (+ (expt (- (car p2) (car p1)) 2)
           (expt (- (cadr p2) (cadr p1)) 2))))

(defun get-rebar-weight (diameter)
  (let ((data (assoc diameter *rebar-data*)))
    (if data (cadr data) 0.0)
  )
)

(defun get-rebar-area (diameter)
  (let ((data (assoc diameter *rebar-data*)))
    (if data (caddr data) 0.0)
  )
)

(defun get-diameter-color (diameter)
  (cdr (assoc diameter *diameter-colors*)))

;; ============================================
;; 3. KATMAN YONETIMI FONKSIYONLARI
;; ============================================

(defun create-layer (layer-name color linetype / layer-exists)
  (if (tblsearch "LAYER" layer-name)
    (setq layer-exists T)
    (progn
      (command "_.-LAYER" "_N" layer-name "_C" color "" "_L" linetype "" "")
      (setq layer-exists nil)
    )
  )
  layer-exists
)

(defun create-footing-layers ()
  (foreach layer-info *layer-colors*
    (create-layer (car layer-info) (cdr layer-info) *linetype-continuous*)
  )
  (create-layer "REBAR-FOOTING-TOP" 2 *linetype-continuous*)
  (create-layer "REBAR-FOOTING-BOT" 3 *linetype-continuous*)
  (princ "\nKatmanlar olusturuldu: REBAR-FOOTING, REBAR-FOOTING-TOP, REBAR-FOOTING-BOT, REBAR-TEXT, REBAR-TABLE, REBAR-DIM")
  (princ)
)

(defun set-current-layer (layer-name)
  (if (tblsearch "LAYER" layer-name)
    (command "_.-LAYER" "_S" layer-name "")
    (create-layer layer-name 7 *linetype-continuous*)
  )
)

;; ============================================
;; 4. KONTROL FONKSIYONLARI (TS 500)
;; ============================================

(defun check-cover (cover diameter)
  (let ((min-cover-calc (max *min-cover* (* 1.5 (/ diameter 10.0)))))
    (if (< cover min-cover-calc)
      (progn
        (alert (strcat "UYARI: Paspayi yetersiz!\nMevcut: " (rtos cover 2 1) " cm\nGerekli: " (rtos min-cover-calc 2 1) " cm"))
        nil
      )
      (progn
        (princ (strcat "\nPaspayi kontrolu: BASARILI (" (rtos cover 2 1) " cm >= " (rtos min-cover-calc 2 1) " cm)"))
        T
      )
    )
  )
)

(defun check-spacing (spacing diameter)
  (let ((max-spacing (min 30.0 (* 2 (/ diameter 10.0)))))
    (if (> spacing max-spacing)
      (progn
        (alert (strcat "UYARI: Donati araligi fazla!\nMevcut: " (rtos spacing 2 1) " cm\nMaksimum: " (rtos max-spacing 2 1) " cm"))
        nil
      )
      T
    )
  )
)

(defun check-all-parameters (diameter-x spacing-x diameter-y spacing-y cover)
  (and
    (check-cover cover diameter-x)
    (check-cover cover diameter-y)
    (check-spacing spacing-x diameter-x)
    (check-spacing spacing-y diameter-y)
  )
)

;; ============================================
;; 5. CIZIM FONKSIYONLARI
;; ============================================

(defun draw-rebar-line (start-point end-point diameter / line-obj)
  (set-current-layer (if (= (getvar "CLAYER") "REBAR-FOOTING-TOP")
                      "REBAR-FOOTING-TOP"
                      (if (= (getvar "CLAYER") "REBAR-FOOTING-BOT")
                        "REBAR-FOOTING-BOT"
                        "REBAR-FOOTING")))
  (command "_.LINE" start-point end-point "")
  (setq line-obj (entlast))
  (vla-put-color (vlax-ename->vla-object line-obj) (get-diameter-color diameter))
  (vla-put-linetype (vlax-ename->vla-object line-obj) *linetype-continuous*)
  line-obj
)

(defun place-rebar-label (position text height / text-obj)
  (set-current-layer "REBAR-TEXT")
  (command "_.TEXT" "_MC" position height "0" text)
  (setq text-obj (entlast))
  (vla-put-color (vlax-ename->vla-object text-obj) 5)
  text-obj
)

(defun draw-footing-outline (base-point width length height / pts)
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
  (vla-put-color (vlax-ename->vla-object (entlast)) 1)
)

(defun draw-footing-dimensions (base-point width length height)
  (set-current-layer "REBAR-DIM")
  (command "_.DIM" "_HOR"
    (pt+ base-point (list 0 -5))
    (pt+ base-point (list width -5))
    (pt+ base-point (list (/ width 2) -10)) "")
  (command "_.DIM" "_VER"
    (pt+ base-point (list width -5))
    (pt+ base-point (list width length))
    (pt+ base-point (list (+ width 5) (/ length 2))) "")
)

;; ============================================
;; 6. TEMEL DONATI HESAPLAMA FONKSIYONLARI
;; ============================================

(defun calculate-rebar-count (dimension spacing cover)
  (let ((effective-length (- dimension (* 2 cover)))
        (count (fix (/ effective-length spacing))))
    (if (<= effective-length spacing)
      1
      (max 1 (1+ count))
    )
  )
)

(defun calculate-total-length (count spacing dimension)
  (* count dimension))

(defun calculate-total-weight (total-length diameter)
  (* total-length (get-rebar-weight diameter) 0.01))

;; ============================================
;; 7. TEMEL DONATI ANA FONKSIYONLARI
;; ============================================

(defun place-x-rebar (base-point width length height diameter spacing cover layers z-offset)
  (let* ((count (calculate-rebar-count length spacing cover))
         (z-pos (+ (caddr base-point) z-offset)))
    (dotimes (i count)
      (let* ((y-pos (+ (cadr base-point) cover (* i spacing)))
             (start-pt (list (car base-point) y-pos z-pos))
             (end-pt   (list (+ (car base-point) width) y-pos z-pos)))
        (draw-rebar-line start-pt end-pt diameter)
      )
    )
  )
)

(defun place-y-rebar (base-point width length height diameter spacing cover layers z-offset)
  (let* ((count (calculate-rebar-count width spacing cover))
         (z-pos (+ (caddr base-point) z-offset)))
    (dotimes (i count)
      (let* ((x-pos (+ (car base-point) cover (* i spacing)))
             (start-pt (list x-pos (cadr base-point) z-pos))
             (end-pt   (list x-pos (+ (cadr base-point) length) z-pos)))
        (draw-rebar-line start-pt end-pt diameter)
      )
    )
  )
)

(defun place-footing-rebar (base-point width length height
                           diameter-x spacing-x diameter-y spacing-y
                           cover layers / z-bottom z-top)
  (setq z-bottom (+ (caddr base-point) cover))
  (setq z-top (+ (caddr base-point) height cover))
  (draw-footing-outline base-point width length height)
  
  (set-current-layer "REBAR-FOOTING-BOT")
  (place-x-rebar base-point width length height diameter-x spacing-x cover 1 z-bottom)
  (place-y-rebar base-point width length height diameter-y spacing-y cover 1 z-bottom)
  
  (if (> layers 1)
    (progn
      (set-current-layer "REBAR-FOOTING-TOP")
      (place-x-rebar base-point width length height diameter-x spacing-x cover layers z-top)
      (place-y-rebar base-point width length height diameter-y spacing-y cover layers z-top)
    )
  )
  
  (place-rebar-label
    (pt+ base-point (list (/ width 2) (/ length 2) (+ height 5)))
    (strcat "O" (itoa diameter-x) "-" (itoa (int spacing-x)) "/" (itoa (int spacing-y))
            (if (> layers 1) " - 2KAT" " - 1KAT"))
    3.0)
  
  (place-rebar-label
    (pt+ base-point (list (/ width 2) (- (cadr base-point) 10) (/ height 2)))
    (strcat "X: " (itoa (calculate-rebar-count length spacing-x cover)) "xO" (itoa diameter-x)
            " | Y: " (itoa (calculate-rebar-count width spacing-y cover)) "xO" (itoa diameter-y))
    2.5)
  
  (place-rebar-label
    (pt+ base-point (list (/ width 2) (- (cadr base-point) 15) (/ height 2)))
    (strcat "Toplam Agirlik: " (rtos (* (+ (* (calculate-rebar-count length spacing-x cover) length (get-rebar-weight diameter-x) 0.01)
                                      (* (calculate-rebar-count width spacing-y cover) width (get-rebar-weight diameter-y) 0.01)) layers) 2 2) " kg")
    2.5)
  
  (draw-footing-dimensions base-point width length height)
)

;; ============================================
;; 8. ANA FONKSIYON - TEMEL DONATI
;; ============================================

(defun C:REBAR-FOOTING ( / base-point width length height
                          diameter-x diameter-y spacing-x spacing-y
                          cover layers footing-type)
  (vl-load-com)
  (vla-startundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== REBAR-Temel v1.1: Temel Donati Yerlestirme ===")
  (princ "\nTurkiye Standartlarina Gore (TS 500)")
  (princ "\nCaplar: 8,10,12,14,16,18,20,22,24,26,28,30,32 mm")
  
  (create-footing-layers)
  
  (princ "\n--- Temel Tipi ve Boyutlari ---")
  (initget 1 "Tekil Surekli Raft")
  (setq footing-type (getkword "Temel tipi [Tekil/Surekli/Raft] <Tekil>: "))
  (if (not footing-type) (setq footing-type "Tekil"))
  
  (setq base-point (getpoint "\nTemel kose noktasini seciniz: "))
  (setq width (get-positive-number "\nTemel genisligini giriniz (cm): " 100.0))
  (setq length (get-positive-number "Temel uzunlugunu giriniz (cm): " 100.0))
  (setq height (get-positive-number "Temel yuksekligini giriniz (cm): " 50.0))
  
  (princ "\n--- X Dogrultusu Donati (Boyuna) ---")
  (initget 1 "8 10 12 14 16 18 20 22 24 26 28 30 32")
  (setq diameter-x (getint "X dogrultusu donati capi [8/10/12/14/16/18/20/22/24/26/28/30/32] <12>: "))
  (if (not diameter-x) (setq diameter-x 12))
  (setq spacing-x (get-positive-number "X dogrultusu donati araligi (cm): " 20.0))
  
  (princ "\n--- Y Dogrultusu Donati (Enine) ---")
  (initget 1 "8 10 12 14 16 18 20 22 24 26 28 30 32")
  (setq diameter-y (getint "Y dogrultusu donati capi [8/10/12/14/16/18/20/22/24/26/28/30/32] <12>: "))
  (if (not diameter-y) (setq diameter-y 12))
  (setq spacing-y (get-positive-number "Y dogrultusu donati araligi (cm): " 20.0))
  
  (princ "\n--- Diger Parametreler ---")
  (setq cover (get-positive-number "Paspayi mesafesi (cm): " 4.0))
  (setq layers (getint "\nKatman sayisi [1/2]: <1>: "))
  (if (not layers) (setq layers 1))
  
  (princ "\n--- On Izleme ---")
  (princ (strcat "\nTemel Tipi: " footing-type))
  (princ (strcat "\nTemel: " (rtos width 2 1) "x" (rtos length 2 1) "x" (rtos height 2 1) " cm"))
  (princ (strcat "\nX Donati: O" (itoa diameter-x) " - " (rtos spacing-x 2 1) " cm aralik"))
  (princ (strcat "\nY Donati: O" (itoa diameter-y) " - " (rtos spacing-y 2 1) " cm aralik"))
  (princ (strcat "\nPaspayi: " (rtos cover 2 1) " cm"))
  (princ (strcat "\nKatman: " (itoa layers)))
  
  (if (not (confirm "\nDonati yerlestirilsin mi?"))
    (progn
      (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
      (princ)
      (exit)
    )
  )
  
  (place-footing-rebar base-point width length height
                      diameter-x spacing-x diameter-y spacing-y cover layers)
  
  (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
  
  (princ "\n=== Islem Tamamlandi ===")
  (princ)
)

(defun C:RFT () (C:REBAR-FOOTING))
(defun C:TEMEL () (C:REBAR-FOOTING))
(defun C:FOOTING () (C:REBAR-FOOTING))

(princ "\nREBAR-Temel.lsp v1.1 yuklendi.\n")
(princ)