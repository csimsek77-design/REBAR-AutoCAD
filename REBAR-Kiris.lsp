;;
;; REBAR-Kiris.lsp
;; ============================================
;; AutoCAD LISP - Kiris Donati Yerlestirme
;; Turkiye Standartlarina Gore (TS 500)
;; ============================================
;; Olusturma: 2024
;; Surum: 1.0
;;

;; ============================================
;; 1. ORTAK VERI YAPILARI
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
        ("Kiris"      . 0.008)
        ("Doseme"     . 0.002)
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
    (defun select-stirrup-diameter (prompt / diameter)
      (setq diameter 8)
      (initget 1 "6 8 10 12 14 16")
      (setq diameter (getint (strcat prompt " [6/8/10/12/14/16] <8>: ")))
      (if (and diameter (not (member diameter '(6 8 10 12 14 16))))
        (progn (alert "Gecersiz etriye capi! 8 olarak ayarlandi.") 8)
        (if (not diameter) 8 diameter)
      )
    )
  )
)

;; ============================================
;; 3. KIRIS KATMANLARI
;; ============================================

(defun create-beam-layers ()
  (foreach layer-info *layer-colors*
    (create-layer (car layer-info) (cdr layer-info) *linetype-continuous*)
  )
  (create-layer "REBAR-BEAM" 2 *linetype-continuous*)
  (create-layer "REBAR-BEAM-TOP" 2 *linetype-continuous*)
  (create-layer "REBAR-BEAM-BOT" 3 *linetype-continuous*)
  (create-layer "REBAR-BEAM-ETRIYE" 6 *linetype-continuous*)
  (princ "\nKiris katmanlari olusturuldu.")
)

;; ============================================
;; 4. KIRIS DONATI HESAPLAMA FONKSIYONLARI
;; ============================================

(defun calculate-beam-rebar-count (length spacing cover)
  (let* ((effective-length (- length (* 2 cover)))
         (count (fix (/ effective-length spacing))))
    (max 2 (1+ count))
  )
)

(defun calculate-bottom-rebar-count (length spacing cover)
  (calculate-beam-rebar-count length spacing cover))

(defun calculate-top-rebar-count (length span-length spacing cover)
  (let* ((effective-length (- span-length (* 2 cover)))
         (support-length (* 0.2 span-length))
         (count (fix (/ support-length spacing))))
    (max 2 (1+ count))
  )
)

(defun calculate-beam-stirrup-count (length spacing cover)
  (let* ((effective-length (- length (* 2 cover)))
         (count (fix (/ effective-length spacing))))
    (max 1 (1+ count))
  )
)

;; ============================================
;; 5. KIRIS CIZIM FONKSIYONLARI
;; ============================================

(defun draw-beam-outline (start-point end-point width height)
  (set-current-layer "REBAR-BEAM")
  (let* ((length (dist start-point end-point))
         (angle (angle start-point end-point))
         (pts (list
           start-point
           (polar start-point angle width)
           (polar end-point (+ angle pi) width)
           end-point
           start-point
         )))
    (command "_.PLINE" pts "")
    (vla-put-closed (vlax-ename->vla-object (entlast)) :vlax-true)
    (vla-put-color (vlax-ename->vla-object (entlast)) 2)
  )
)

(defun draw-bottom-rebar (start-point end-point width height
                         diameter spacing cover / length count z-pos)
  (set-current-layer "REBAR-BEAM-BOT")
  (setq length (dist start-point end-point))
  (setq count (calculate-bottom-rebar-count length spacing cover))
  (setq z-pos (+ (caddr start-point) cover))
  (dotimes (i count)
    (let* ((ratio (/ i (1- count)))
           (x-pos (+ (car start-point) (* ratio (- (car end-point) (car start-point)))))
           (y-pos (+ (cadr start-point) (* ratio (- (cadr end-point) (cadr start-point)))))
           (start-pt (list x-pos y-pos z-pos))
           (end-pt (list (+ x-pos (* (sin (angle start-point end-point)) width))
                         (- y-pos (* (cos (angle start-point end-point)) width))
                         z-pos)))
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter))
    )
  )
)

(defun draw-top-rebar (start-point end-point width height
                       diameter spacing cover span-length / length count z-pos)
  (set-current-layer "REBAR-BEAM-TOP")
  (setq length (dist start-point end-point))
  (setq count (calculate-top-rebar-count length span-length spacing cover))
  (setq z-pos (+ (caddr start-point) height cover))
  (dotimes (i count)
    (let* ((x-pos (+ (car start-point) (* i spacing (sin (angle start-point end-point)))))
           (y-pos (+ (cadr start-point) (* i spacing (cos (angle start-point end-point)))))
           (start-pt (list x-pos y-pos z-pos))
           (end-pt (list (+ x-pos (* (sin (angle start-point end-point)) width))
                         (- y-pos (* (cos (angle start-point end-point)) width))
                         z-pos)))
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter))
    )
  )
  (dotimes (i count)
    (let* ((x-pos (- (car end-point) (* i spacing (sin (angle start-point end-point)))))
           (y-pos (- (cadr end-point) (* i spacing (cos (angle start-point end-point)))))
           (start-pt (list x-pos y-pos z-pos))
           (end-pt (list (+ x-pos (* (sin (angle start-point end-point)) width))
                         (- y-pos (* (cos (angle start-point end-point)) width))
                         z-pos)))
      (command "_.LINE" start-pt end-pt "")
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color diameter))
    )
  )
)

(defun draw-beam-stirrup (start-point end-point width height
                         stirrup-diameter spacing cover / length count z-pos z-step)
  (set-current-layer "REBAR-BEAM-ETRIYE")
  (setq length (dist start-point end-point))
  (setq count (calculate-beam-stirrup-count length spacing cover))
  (setq z-pos (+ (caddr start-point) cover))
  (setq z-step spacing)
  (dotimes (i count)
    (let* ((z-current (+ z-pos (* i z-step)))
           (ratio (/ (* i spacing) length))
           (x-pos (+ (car start-point) (* ratio (- (car end-point) (car start-point)))))
           (y-pos (+ (cadr start-point) (* ratio (- (cadr end-point) (cadr start-point)))))
           (pts (list
             (list (+ x-pos (* (sin (angle start-point end-point)) cover))
                   (- y-pos (* (cos (angle start-point end-point)) cover)) z-current)
             (list (+ x-pos (* (sin (angle start-point end-point)) (- cover width)))
                   (- y-pos (* (cos (angle start-point end-point)) (- cover width))) z-current)
             (list (+ x-pos (* (sin (angle start-point end-point)) (- cover width)))
                   (- y-pos (* (cos (angle start-point end-point)) cover)) z-current)
             (list (+ x-pos (* (sin (angle start-point end-point)) cover))
                   (- y-pos (* (cos (angle start-point end-point)) (- cover width))) z-current)
             (list (+ x-pos (* (sin (angle start-point end-point)) cover))
                   (- y-pos (* (cos (angle start-point end-point)) cover)) z-current)))
      (command "_.PLINE" pts "")
      (vla-put-closed (vlax-ename->vla-object (entlast)) :vlax-true)
      (vla-put-color (vlax-ename->vla-object (entlast)) (get-diameter-color stirrup-diameter))
    )
  )
)

;; ============================================
;; 6. KIRIS DONATI ANA FONKSIYONU
;; ============================================

(defun place-beam-rebar (start-point end-point width height
                        bottom-diameter top-diameter stirrup-diameter
                        bottom-spacing top-spacing stirrup-spacing cover / 
                        length span-length
                        bottom-count top-count stirrup-count
                        bottom-weight top-weight stirrup-weight total-weight perimeter)
  (setq length (dist start-point end-point))
  (setq span-length length)
  (draw-beam-outline start-point end-point width height)
  (draw-bottom-rebar start-point end-point width height bottom-diameter bottom-spacing cover)
  (draw-top-rebar start-point end-point width height top-diameter top-spacing cover span-length)
  (draw-beam-stirrup start-point end-point width height stirrup-diameter stirrup-spacing cover)
  (setq bottom-count (calculate-bottom-rebar-count length bottom-spacing cover))
  (setq top-count (calculate-top-rebar-count length span-length top-spacing cover))
  (setq stirrup-count (calculate-beam-stirrup-count length stirrup-spacing cover))
  (setq perimeter (* 2 (+ width height)))
  (setq bottom-weight (* bottom-count length (get-rebar-weight bottom-diameter) 0.01))
  (setq top-weight (* top-count (* 2 (* 0.2 span-length)) (get-rebar-weight top-diameter) 0.01))
  (setq stirrup-weight (* stirrup-count perimeter (get-rebar-weight stirrup-diameter) 0.01))
  (setq total-weight (+ bottom-weight top-weight stirrup-weight))
  (set-current-layer "REBAR-TEXT")
  (let* ((mid-point (mapcar '/ (mapcar '+ start-point end-point) '(2 2 2)))
         (offset-point (pt+ mid-point (list 0 5 0))))
    (command "_.TEXT" "_MC" offset-point 2.5 "0"
      (strcat "Alt: " (itoa bottom-count) "xO" (itoa bottom-diameter)))
    (command "_.TEXT" "_MC" (pt+ offset-point (list 0 3 0)) 2.5 "0"
      (strcat "Ust: " (itoa top-count) "xO" (itoa top-diameter) " (mesnet)"))
    (command "_.TEXT" "_MC" (pt+ offset-point (list 0 1 0)) 2.5 "0"
      (strcat "Etriye: O" (itoa stirrup-diameter) "-" (itoa (int stirrup-spacing))))
    (command "_.TEXT" "_MC" (pt+ offset-point (list 0 -1 0)) 2.5 "0"
      (strcat "Agirlik: " (rtos total-weight 2 2) " kg"))
  )
  (list :length length :width width :height height
        :bottom-diameter bottom-diameter :top-diameter top-diameter
        :stirrup-diameter stirrup-diameter :bottom-spacing bottom-spacing
        :top-spacing top-spacing :stirrup-spacing stirrup-spacing :cover cover
        :bottom-count bottom-count :top-count top-count :stirrup-count stirrup-count
        :perimeter perimeter :bottom-weight bottom-weight :top-weight top-weight
        :stirrup-weight stirrup-weight :total-weight total-weight))

;; ============================================
;; 7. KULLANICI ARAYUZU FONKSIYONLARI
;; ============================================

(defun select-beam-type (prompt / type)
  (initget 1 "Dikdortgen T L Kutu")
  (setq type (getkword (strcat prompt " [Dikdortgen/T/L/Kutu] <Dikdortgen>: ")))
  (cond
    ((or (not type) (= type "Dikdortgen")) "Dikdortgen")
    ((= type "T") "T")
    ((= type "L") "L")
    ((= type "Kutu") "Kutu")
    (T "Dikdortgen")
  )
)

;; ============================================
;; 8. ANA KOMUT
;; ============================================

(defun C:REBAR-BEAM ( / start-point end-point width height
                        bottom-diameter top-diameter stirrup-diameter
                        bottom-spacing top-spacing stirrup-spacing cover
                        beam-type result)
  (vl-load-com)
  (vla-startundomark (vla-get-activedocument (vlax-get-acad-object)))
  (princ "\n=== REBAR-Kiris: Kiris Donati Yerlestirme ===")
  (princ "\nTurkiye Standartlarina Gore (TS 500)")
  (create-beam-layers)
  (princ "\n--- Kiris Tipi ve Boyutlari ---")
  (setq beam-type (select-beam-type "Kiris tipi"))
  (setq start-point (getpoint "\nKiris baslangic noktasini seciniz: "))
  (setq end-point (getpoint "Kiris bitis noktasini seciniz: "))
  (setq width (get-positive-number "\nKiris genisligini giriniz (cm): " 30.0))
  (setq height (get-positive-number "Kiris yuksekligini giriniz (cm): " 50.0))
  (princ "\n--- Alt Donati ---")
  (setq bottom-diameter (select-diameter "Alt donati capi"))
  (setq bottom-spacing (get-positive-number "Alt donati araligi (cm): " 15.0))
  (princ "\n--- Ust Donati (Mesnet) ---")
  (setq top-diameter (select-diameter "Ust donati capi"))
  (setq top-spacing (get-positive-number "Ust donati araligi (cm): " 20.0))
  (princ "\n--- Etriye Donati ---")
  (setq stirrup-diameter (select-stirrup-diameter "Etriye capi"))
  (setq stirrup-spacing (get-positive-number "Etriye araligi (cm): " 15.0))
  (princ "\n--- Diger Parametreler ---")
  (setq cover (get-positive-number "Paspayi mesafesi (cm): " 3.0))
  (princ "\n--- On Izleme ---")
  (princ (strcat "\nKiris Tipi: " beam-type))
  (princ (strcat "\nBoyutlar: " (rtos (dist start-point end-point) 2 1) "x" (rtos width 2 1) "x" (rtos height 2 1) " cm"))
  (princ (strcat "\nAlt Donati: O" (itoa bottom-diameter) " - " (rtos bottom-spacing 2 1) " cm"))
  (princ (strcat "\nUst Donati: O" (itoa top-diameter) " - " (rtos top-spacing 2 1) " cm"))
  (princ (strcat "\nEtriye: O" (itoa stirrup-diameter) " - " (rtos stirrup-spacing 2 1) " cm"))
  (princ (strcat "\nPaspayi: " (rtos cover 2 1) " cm"))
  (if (not (confirm "\nDonati yerlestirilsin mi?"))
    (progn
      (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
      (princ)
      (exit)))
  (setq result (place-beam-rebar start-point end-point width height
                                  bottom-diameter top-diameter stirrup-diameter
                                  bottom-spacing top-spacing stirrup-spacing cover))
  (vla-endundomark (vla-get-activedocument (vlax-get-acad-object)))
  (princ "\n=== Islem Tamamlandi ===")
  (princ (strcat "\nToplam Donati Agirligi: " (rtos (nth 18 result) 2 2) " kg"))
  (princ (strcat "\nAlt Donati: " (itoa (nth 10 result)) "xO" (itoa (nth 4 result))))
  (princ (strcat "\nUst Donati: " (itoa (nth 11 result)) "xO" (itoa (nth 5 result))))
  (princ (strcat "\nEtriye: " (itoa (nth 12 result)) " adet O" (itoa (nth 6 result))))
  (princ))

;; ============================================
;; 9. OTOMATIK YUKLEME VE KOMUTLAR
;; ============================================

(princ "\nREBAR-Kiris v1.0 LISP dosyasi yuklendi.")
(princ "\nKullanilabilir komutlar:")
(princ "\n  - REBAR-BEAM: Kiris donati yerlestir")
(princ "\n  - RB: Kiris donati (kisaltma)")
(princ)

(defun C:RB () (C:REBAR-BEAM))

(princ "\nREBAR-Kiris.lsp yuklendi.\n")
(princ)