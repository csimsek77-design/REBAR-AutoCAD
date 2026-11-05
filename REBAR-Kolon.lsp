;;
;; REBAR-Kolon.lsp
;; ============================================
;; AutoCAD LISP - Kolon/Perde Donati Yerlestirme
;; Turkiye Standartlarina Gore (TS 500)
;; ============================================
;; Olusturma: 2024
;; Surum: 1.0
;;

;; ============================================
;; 1. ORTAK VERI YAPILARI
;; ============================================

;; Eger REBAR-Temel.lsp yuklenmediyse, veri yapilarini tekrar tanimla
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
        ("Kiris"      . 0.008)
        ("Doseme"     . 0.002)
        ("Perde"      . 0.004)
    ))
    (setq *min-cover* 2.5)
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
;; 2. YARDIMCI FONKSIYONLAR
;; ============================================

(if (not (boundp 'pt+))
  (progn
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
      (cdr (assoc diameter *diameter-colors*))
    )
    (defun create-layer (layer-name color linetype)
      (if (not (tblsearch "LAYER" layer-name))
        (command "_.-LAYER" "_N" layer-name "_C" color "" "_L" linetype "" "")
      )
    )
    (defun set-current-layer (layer-name)
      (if (tblsearch "LAYER" layer-name)
        (command "_.-LAYER" "_S" layer-name "")
        (create-layer layer-name 7 *linetype-continuous*)
      )
    )
    (defun confirm (prompt)
      (initget 1 "Evet Hayir E H")
      (cond
        ((= (getkword (strcat prompt " [Evet/Hayir] <Evet>: ")) "Evet") T)
        (T nil)
      )
    )
    (defun get-positive-number (prompt default)
      (let ((value (getreal (strcat prompt " <" (rtos default) ">: "))))
        (if (or (not value) (<= value 0)) default value)
      )
    )
    (defun select-diameter (prompt)
      (let ((diameter 16))
        (initget 1 "8 10 12 14 16 18 20 22 24 26 28 30 32")
        (setq diameter (getint (strcat prompt " [8/10/12/14/16/18/20/22/24/26/28/30/32] <16>: ")))
        (if (and diameter (not (member diameter '(8 10 12 14 16 18 20 22 24 26 28 30 32))))
          (progn (alert "Gecersiz cap! 16 olarak ayarlandi.") 16)
          (if (not diameter) 16 diameter)
        )
      )
    )
    (defun select-stirrup-diameter (prompt)
      (let ((diameter 8))
        (initget 1 "6 8 10 12 14 16")
        (setq diameter (getint (strcat prompt " [6/8/10/12/14/16] <8>: ")))
        (if (and diameter (not (member diameter '(6 8 10 12 14 16))))
          (progn (alert "Gecersiz etriye capi! 8 olarak ayarlandi.") 8)
          (if (not diameter) 8 diameter)
        )
      )
    )
  )
)

;; ============================================
;; 3. KOLON/PERDE KATMANLARI
;; ============================================

(defun create-column-layers ()
  (foreach layer-info *layer-colors*
    (create-layer (car layer-info) (cdr layer-info) *linetype-continuous*)
  )
  (create-layer "REBAR-COLUMN" 4 *linetype-continuous*)
  (create-layer "REBAR-COLUMN-ETRIYE" 6 *linetype-continuous*)
  (create-layer "REBAR-COLUMN-TOP" 2 *linetype-continuous*)
  (create-layer "REBAR-COLUMN-BOT" 3 *linetype-continuous*)
  (princ "\nKolon katmanlari olusturuldu.")
)

;; ============================================
;; 4. KOLON DONATI HESAPLAMA FONKSIYONLARI
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

(defun calculate-stirrup-count (height spacing cover)
  (let* ((effective-height (- height (* 2 cover)))
         (count (fix (/ effective-height spacing))))
    (max 1 (1+ count))
  )
)

(defun calculate-longitudinal-weight (count length diameter)
  (* count length (get-rebar-weight diameter) 0.01))

(defun calculate-stirrup-weight (count perimeter diameter)
  (* count perimeter (get-rebar-weight diameter) 0.01))

;; ============================================
;; 5. KOLON CIZIM FONKSIYONLARI
;; ============================================

(defun draw-column-outline (base-point width length height)
  (set-current-layer "REBAR-COLUMN")
  (let ((pts (list base-point
                    (pt+ base-point (list width 0))
                    (pt+ base-point (list width length))
                    (pt+ base-point (list 0 length))
                    base-point)))
    (command "_.PLINE" pts "")
    (vla-put-closed (vlax-ename->vla-object (entlast)) :vlax-true)
    (vla-put-color (vlax-ename->vla-object (entlast)) 4)
  )
)

(defun draw-rectangular-longitudinal (base-point width length height
                                      diameter-x diameter-y spacing cover)
  (set-current-layer "REBAR-COLUMN")
  (let* ((count-x (calculate-rebar-count width spacing cover))
         (count-y (calculate-rebar-count length spacing cover))
         (z-bottom (+ (caddr base-point) cover))
         (z-top (+ (caddr base-point) height cover)))
    (dotimes (i count-x)
      (let* ((y-pos (+ (cadr base-point) cover (* i spacing)))
             (start-pt (list (car base-point) y-pos z-bottom))
             (end-pt (list (car base-point) y-pos z-top)))
        (command "_.LINE" start-pt end-pt "")
        (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter-x))
      )
    )
    (dotimes (i count-y)
      (let* ((x-pos (+ (car base-point) cover (* i spacing)))
             (start-pt (list x-pos (cadr base-point) z-bottom))
             (end-pt (list x-pos (cadr base-point) z-top)))
        (command "_.LINE" start-pt end-pt "")
        (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter-y))
      )
    )
  )
)

(defun draw-stirrup (base-point width length height stirrup-diameter spacing cover)
  (set-current-layer "REBAR-COLUMN-ETRIYE")
  (let* ((count (calculate-stirrup-count height spacing cover))
         (z-bottom (+ (caddr base-point) cover))
         (z-step spacing))
    (dotimes (i count)
      (let* ((z-pos (+ z-bottom (* i z-step)))
             (pts (list
                   (list (+ (car base-point) cover) (+ (cadr base-point) cover) z-pos)
                   (list (+ (car base-point) cover (- (cadr base-point) length)) z-pos)
                   (list (- (car base-point) cover (- (cadr base-point) length)) z-pos)
                   (list (- (car base-point) cover (+ (cadr base-point) cover)) z-pos)
                   (list (+ (car base-point) cover (+ (cadr base-point) cover)) z-pos))))
        (command "_.PLINE" pts "")
        (vla-put-closed (vlax-ename->vla-object (entlast)) :vlax-true)
        (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color stirrup-diameter))
      )
    )
  )
)

;; ============================================
;; 6. KOLON DONATI ANA FONKSIYONU
;; ============================================

(defun place-column-rebar (base-point width length height
                          long-diameter-x long-diameter-y stirrup-diameter
                          long-spacing stirrup-spacing cover / 
                          long-count-x long-count-y stirrup-count
                          long-weight stirrup-weight total-weight perimeter)
  (draw-column-outline base-point width length height)
  (setq long-count-x (calculate-rebar-count width long-spacing cover))
  (setq long-count-y (calculate-rebar-count length long-spacing cover))
  (draw-rectangular-longitudinal base-point width length height
                                long-diameter-x long-diameter-y long-spacing cover)
  (setq stirrup-count (calculate-stirrup-count height stirrup-spacing cover))
  (draw-stirrup base-point width length height stirrup-diameter stirrup-spacing cover)
  (setq perimeter (* 2 (+ width length)))
  (setq long-weight (+ (calculate-longitudinal-weight long-count-x height long-diameter-x)
                        (calculate-longitudinal-weight long-count-y height long-diameter-y)))
  (setq stirrup-weight (calculate-stirrup-weight stirrup-count perimeter stirrup-diameter))
  (setq total-weight (+ long-weight stirrup-weight))
  (set-current-layer "REBAR-TEXT")
  (command "_.TEXT" "_MC"
    (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 5) (/ height 2)))
    2.5 "0"
    (strcat "Boyuna: " (itoa long-count-x) "xO" (itoa long-diameter-x)
            " + " (itoa long-count-y) "xO" (itoa long-diameter-y)))
  (command "_.TEXT" "_MC"
    (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 8) (/ height 2)))
    2.5 "0"
    (strcat "Etriye: O" (itoa stirrup-diameter) "-" (itoa (int stirrup-spacing)) "/" (itoa (int stirrup-spacing))))
  (command "_.TEXT" "_MC"
    (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 11) (/ height 2)))
    2.5 "0"
    (strcat "Toplam Agirlik: " (rtos total-weight 2 2) " kg"))
  (list :width width :length length :height height
        :long-diameter-x long-diameter-x :long-diameter-y long-diameter-y
        :stirrup-diameter stirrup-diameter :long-spacing long-spacing
        :stirrup-spacing stirrup-spacing :cover cover
        :long-count-x long-count-x :long-count-y long-count-y
        :stirrup-count stirrup-count :perimeter perimeter
        :long-weight long-weight :stirrup-weight stirrup-weight
        :total-weight total-weight))

;; ============================================
;; 7. PERDE DONATI FONKSIYONU
;; ============================================

(defun place-wall-rebar (base-point width length height
                        horizontal-diameter vertical-diameter stirrup-diameter
                        h-spacing v-spacing stirrup-spacing cover / 
                        h-count v-count stirrup-count
                        h-weight v-weight stirrup-weight total-weight)
  (draw-column-outline base-point width length height)
  (setq h-count (calculate-rebar-count length h-spacing cover))
  (setq v-count (calculate-rebar-count width v-spacing cover))
  (set-current-layer "REBAR-COLUMN")
  (dotimes (i h-count)
    (let* ((y-pos (+ (cadr base-point) cover (* i h-spacing)))
           (start-pt (list (car base-point) y-pos (+ (caddr base-point) cover)))
           (end-pt (list (+ (car base-point) width) y-pos (+ (caddr base-point) cover))))
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color horizontal-diameter))
    )
  )
  (dotimes (i v-count)
    (let* ((x-pos (+ (car base-point) cover (* i v-spacing)))
           (start-pt (list x-pos (cadr base-point) (+ (caddr base-point) cover)))
           (end-pt (list x-pos (+ (cadr base-point) length) (+ (caddr base-point) cover))))
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color vertical-diameter))
    )
  )
  (if stirrup-diameter
    (progn
      (setq stirrup-count (calculate-stirrup-count height stirrup-spacing cover))
      (draw-stirrup base-point width length height stirrup-diameter stirrup-spacing cover)
      (setq stirrup-weight (calculate-stirrup-weight stirrup-count (* 2 (+ width length)) stirrup-diameter))
    )
    (setq stirrup-weight 0.0))
  (setq h-weight (calculate-longitudinal-weight h-count width horizontal-diameter))
  (setq v-weight (calculate-longitudinal-weight v-count length vertical-diameter))
  (setq total-weight (+ h-weight v-weight stirrup-weight))
  (set-current-layer "REBAR-TEXT")
  (command "_.TEXT" "_MC"
    (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 5) (/ height 2)))
    2.5 "0"
    (strcat "Yatay: " (itoa h-count) "xO" (itoa horizontal-diameter)
            " | Dikey: " (itoa v-count) "xO" (itoa vertical-diameter)))
  (if stirrup-diameter
    (command "_.TEXT" "_MC"
      (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 8) (/ height 2)))
      2.5 "0"
      (strcat "Etriye: O" (itoa stirrup-diameter) "-" (itoa (int stirrup-spacing)))))
  (command "_.TEXT" "_MC"
    (pt+ base-point (list (/ width 2) (+ (cadr base-point) length 11) (/ height 2)))
    2.5 "0"
    (strcat "Toplam Agirlik: " (rtos total-weight 2 2) " kg"))
  (list :width width :length length :height height
        :h-diameter horizontal-diameter :v-diameter vertical-diameter
        :stirrup-diameter stirrup-diameter :h-spacing h-spacing
        :v-spacing v-spacing :stirrup-spacing stirrup-spacing :cover cover
        :h-count h-count :v-count v-count
        :stirrup-count (if stirrup-diameter stirrup-count 0)
        :h-weight h-weight :v-weight v-weight
        :stirrup-weight stirrup-weight :total-weight total-weight))

;; ============================================
;; 8. KULLANICI ARAYUZU FONKSIYONLARI
;; ============================================

(defun select-column-type (prompt / type)
  (initget 1 "Kare Dikdortgen")
  (setq type (getkword (strcat prompt " [Kare/Dikdortgen] <Dikdortgen>: ")))
  (cond
    ((or (not type) (= type "Dikdortgen")) "Dikdortgen")
    ((= type "Kare") "Kare")
    (T "Dikdortgen")
  )
)

;; ============================================
;; 9. ANA KOMUTLAR
;; ============================================

(defun C:REBAR-COLUMN ( / base-point width length height
                          long-diameter-x long-diameter-y stirrup-diameter
                          long-spacing stirrup-spacing cover column-type result)
  (vl-load-com)
  (vla-startundomark (vla-get-activedocument (vlax-get-acad-object)))
  (princ "\n=== REBAR-Kolon: Kolon Donati Yerlestirme ===")
  (princ "\nTurkiye Standartlarina Gore (TS 500)")
  (create-column-layers)
  (princ "\n--- Kolon Tipi ve Boyutlari ---")
  (setq column-type (select-column-type "Kolon tipi"))
  (setq base-point (getpoint "\nKolon taban noktasini seciniz: "))
  (if (= column-type "Kare")
    (progn
      (setq width (get-positive-number "\nKolon genisligini giriniz (cm): " 50.0))
      (setq length width))
    (progn
      (setq width (get-positive-number "\nKolon genisligini giriniz (cm): " 50.0))
      (setq length (get-positive-number "Kolon uzunlugunu giriniz (cm): " 50.0))))
  (setq height (get-positive-number "Kolon yuksekligini giriniz (cm): " 300.0))
  (princ "\n--- Boyuna Donati ---")
  (setq long-diameter-x (select-diameter "X dogrultusu boyuna donati capi"))
  (setq long-diameter-y (select-diameter "Y dogrultusu boyuna donati capi"))
  (setq long-spacing (get-positive-number "Boyuna donati araligi (cm): " 20.0))
  (princ "\n--- Etriye Donati ---")
  (setq stirrup-diameter (select-stirrup-diameter "Etriye capi"))
  (setq stirrup-spacing (get-positive-number "Etriye araligi (cm): " 15.0))
  (princ "\n--- Diger Parametreler ---")
  (setq cover (get-positive-number "Paspayi mesafesi (cm): " 3.0))
  (princ "\n--- On Izleme ---")
  (princ (strcat "\nKolon Tipi: " column-type))
  (princ (strcat "\nBoyutlar: " (rtos width 2 1) "x" (rtos length 2 1) "x" (rtos height 2 1) " cm"))
  (princ (strcat "\nBoyuna X: O" (itoa long-diameter-x) " - " (rtos long-spacing 2 1) " cm"))
  (princ (strcat "\nBoyuna Y: O" (itoa long-diameter-y) " - " (rtos long-spacing 2 1) " cm"))
  (princ (strcat "\nEtriye: O" (itoa stirrup-diameter) " - " (rtos stirrup-spacing 2 1) " cm"))
  (princ (strcat "\nPaspayi: " (rtos cover 2 1) " cm"))
  (if (not (confirm "\nDonati yerlestirilsin mi?"))
    (progn
      (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
      (princ)
      (exit)))
  (setq result (place-column-rebar base-point width length height
                                    long-diameter-x long-diameter-y stirrup-diameter
                                    long-spacing stirrup-spacing cover))
  (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
  (princ "\n=== Islem Tamamlandi ===")
  (princ (strcat "\nToplam Donati Agirligi: " (rtos (nth 17 result) 2 2) " kg"))
  (princ (strcat "\nBoyuna Donati: " (itoa (nth 8 result)) "xO" (itoa (nth 4 result))
                 " + " (itoa (nth 9 result)) "xO" (itoa (nth 5 result))))
  (princ (strcat "\nEtriye: " (itoa (nth 10 result)) " adet O" (itoa (nth 6 result))))
  (princ))

(defun C:REBAR-WALL ( / base-point width length height
                        h-diameter v-diameter stirrup-diameter
                        h-spacing v-spacing stirrup-spacing cover result)
  (vl-load-com)
  (vla-startundomark (vla-get-activedocument (vlax-get-acad-object)))
  (princ "\n=== REBAR-Kolon: Perde Donati Yerlestirme ===")
  (princ "\nTurkiye Standartlarina Gore (TS 500)")
  (create-column-layers)
  (princ "\n--- Perde Boyutlari ---")
  (setq base-point (getpoint "\nPerde kose noktasini seciniz: "))
  (setq width (get-positive-number "\nPerde kalinligini giriniz (cm): " 20.0))
  (setq length (get-positive-number "Perde uzunlugunu giriniz (cm): " 300.0))
  (setq height (get-positive-number "Perde yuksekligini giriniz (cm): " 300.0))
  (princ "\n--- Yatay Donati ---")
  (setq h-diameter (select-diameter "Yatay donati capi"))
  (setq h-spacing (get-positive-number "Yatay donati araligi (cm): " 20.0))
  (princ "\n--- Dikey Donati ---")
  (setq v-diameter (select-diameter "Dikey donati capi"))
  (setq v-spacing (get-positive-number "Dikey donati araligi (cm): " 20.0))
  (princ "\n--- Etriye Donati (opsiyonel) ---")
  (setq stirrup-diameter (select-stirrup-diameter "Etriye capi (0 icin yok)"))
  (if (= stirrup-diameter 0) (setq stirrup-diameter nil))
  (if stirrup-diameter
    (setq stirrup-spacing (get-positive-number "Etriye araligi (cm): " 20.0))
    (setq stirrup-spacing 0))
  (princ "\n--- Diger Parametreler ---")
  (setq cover (get-positive-number "Paspayi mesafesi (cm): " 3.0))
  (princ "\n--- On Izleme ---")
  (princ (strcat "\nPerde: " (rtos width 2 1) "x" (rtos length 2 1) "x" (rtos height 2 1) " cm"))
  (princ (strcat "\nYatay: O" (itoa h-diameter) " - " (rtos h-spacing 2 1) " cm"))
  (princ (strcat "\nDikey: O" (itoa v-diameter) " - " (rtos v-spacing 2 1) " cm"))
  (if stirrup-diameter
    (princ (strcat "\nEtriye: O" (itoa stirrup-diameter) " - " (rtos stirrup-spacing 2 1) " cm")))
  (princ (strcat "\nPaspayi: " (rtos cover 2 1) " cm"))
  (if (not (confirm "\nDonati yerlestirilsin mi?"))
    (progn
      (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
      (princ)
      (exit)))
  (setq result (place-wall-rebar base-point width length height
                                h-diameter v-diameter stirrup-diameter
                                h-spacing v-spacing stirrup-spacing cover))
  (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
  (princ "\n=== Islem Tamamlandi ===")
  (princ (strcat "\nToplam Donati Agirligi: " (rtos (nth 13 result) 2 2) " kg"))
  (princ))

;; ============================================
;; 10. OTOMATIK YUKLEME VE KOMUTLAR
;; ============================================

(princ "\nREBAR-Kolon v1.0 LISP dosyasi yuklendi.")
(princ "\nKullanilabilir komutlar:")
(princ "\n  - REBAR-COLUMN: Kolon donati yerlestir")
(princ "\n  - RK: Kolon donati (kisaltma)")
(princ "\n  - REBAR-WALL: Perde donati yerlestir")
(princ "\n  - RP: Perde donati (kisaltma)")
(princ)

(defun C:RK () (C:REBAR-COLUMN))
(defun C:RC () (C:REBAR-COLUMN))
(defun C:RP () (C:REBAR-WALL))
(defun C:RW () (C:REBAR-WALL))

(princ "\nREBAR-Kolon.lsp yuklendi.\n")
(princ)