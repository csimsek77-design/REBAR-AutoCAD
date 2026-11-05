;; REBAR-Ana.lsp
;; ============================================
;; AutoCAD LISP - Tum Donati Yerlestirme Modulleri
;; Ana Yukleyici Dosyasi
;; ============================================
;; Olusturma: 2024
;; Surum: 1.0
;;

;; ============================================
;; ACIKLAMA
;; ============================================
;; Bu dosya, REBAR serisinin tum modullerini yukler:
;; - REBAR-Temel.lsp: Temel donati yerlestirme
;; - REBAR-Kolon.lsp: Kolon ve perde donati yerlestirme
;; - REBAR-Kiris.lsp: Kiris donati yerlestirme
;; - REBAR-Doseme.lsp: Doseme donati yerlestirme
;;
;; ============================================

(princ "\n=== REBAR Serisi Ana Yukleyici ===")
(princ "\nTurkiye Standartlarina Gore Donati Yerlestirme")
(princ "\nCaplar: 8,10,12,14,16,18,20,22,24,26,28,30,32 mm")
(princ "\n========================================")

;; ============================================
;; 1. VERI YAPILARI (Ortak)
;; ============================================

;; Donati Caplari ve Agirliklari (Turkiye Standartlari)
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

;; Donati Siniflari
(setq *rebar-grades* '(
    ("S220"   . 2200)    ; kg/cm2
    ("S420"   . 4200)
    ("B420C"  . 4200)
    ("B500C"  . 5000)
))

;; Minimum Donati Oranlari (TS 500)
(setq *min-rebar-ratios* '(
    ("Temel"      . 0.008)   ; 0.8%o
    ("Kolon"      . 0.010)   ; 1.0%o
    ("Kiris"      . 0.008)   ; 0.8%o
    ("Doseme"     . 0.002)   ; 0.2%o
    ("Perde"      . 0.004)   ; 0.4%o
))

;; Minimum Paspayi
(setq *min-cover* 2.5)

;; Katman Renkleri
(setq *layer-colors* '(
    ("REBAR-FOOTING"     . 1)
    ("REBAR-FOOTING-TOP" . 2)
    ("REBAR-FOOTING-BOT" . 3)
    ("REBAR-COLUMN"      . 4)
    ("REBAR-COLUMN-ETRIYE" . 6)
    ("REBAR-BEAM"        . 2)
    ("REBAR-BEAM-TOP"    . 2)
    ("REBAR-BEAM-BOT"    . 3)
    ("REBAR-BEAM-ETRIYE" . 6)
    ("REBAR-SLAB"        . 5)
    ("REBAR-SLAB-TOP"    . 5)
    ("REBAR-SLAB-BOT"    . 3)
    ("REBAR-TEXT"        . 5)
    ("REBAR-TABLE"       . 7)
    ("REBAR-DIM"         . 250)
))

;; Donati Cap Renkleri
(setq *diameter-colors* '(
    (8  . 1)   (10 . 2)   (12 . 3)   (14 . 4)
    (16 . 5)   (18 . 6)   (20 . 7)   (22 . 10)
    (24 . 11)  (26 . 12)  (28 . 13)  (30 . 14)
    (32 . 15)
))

;; Cizgi Tipleri
(setq *linetype-continuous* "CONTINUOUS")

;; ============================================
;; 2. ORTAK YARDIMCI FONKSIYONLAR
;; ============================================

;; --- Nokta Islemleri ---
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

;; --- Mesafe Hesaplama ---
(defun dist (p1 p2)
  (sqrt (+ (expt (- (car p2) (car p1)) 2)
           (expt (- (cadr p2) (cadr p1)) 2))))

;; --- Aci Hesaplama ---
(defun angle (p1 p2)
  (atan (/ (- (cadr p2) (cadr p1)) (- (car p2) (car p1)))))

;; --- Donati Verisini Al ---
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

(defun get-rebar-strength (grade)
  (cdr (assoc grade *rebar-grades*)))

(defun get-min-rebar-ratio (element-type)
  (cdr (assoc element-type *min-rebar-ratios*)))

(defun get-diameter-color (diameter)
  (cdr (assoc diameter *diameter-colors*)))

(defun get-layer-color (layer-name)
  (cdr (assoc layer-name *layer-colors*)))

;; --- Katman Yonetimi ---
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

;; --- Kullanici Arayuzu ---
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
  (let ((diameter 12))
    (initget 1 "8 10 12 14 16 18 20 22 24 26 28 30 32")
    (setq diameter (getint (strcat prompt " [8/10/12/14/16/18/20/22/24/26/28/30/32] <12>: ")))
    (if (and diameter (not (member diameter '(8 10 12 14 16 18 20 22 24 26 28 30 32))))
      (progn (alert "Gecersiz cap! 12 olarak ayarlandi.") 12)
      (if (not diameter) 12 diameter)
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

;; ============================================
;; 3. TUM MODULLERI YUKLE
;; ============================================

(princ "\nModuller yukleniyor...")

;; Modul dosyalarini yukle
(if (findfile "REBAR-Temel.lsp")
  (load "REBAR-Temel.lsp")
  (princ "\nUYARI: REBAR-Temel.lsp bulunamadi!")
)

(if (findfile "REBAR-Kolon.lsp")
  (load "REBAR-Kolon.lsp")
  (princ "\nUYARI: REBAR-Kolon.lsp bulunamadi!")
)

(if (findfile "REBAR-Kiris.lsp")
  (load "REBAR-Kiris.lsp")
  (princ "\nUYARI: REBAR-Kiris.lsp bulunamadi!")
)

(if (findfile "REBAR-Doseme.lsp")
  (load "REBAR-Doseme.lsp")
  (princ "\nUYARI: REBAR-Doseme.lsp bulunamadi!")
)

;; ============================================
;; 4. ANA MENU FONKSIYONU
;; ============================================

(defun C:REBAR ()
  "REBAR Ana Menu - Donati Yerlestirme Secenekleri"
  (vl-load-com)
  
  (princ "\n=== REBAR ANA MENU ===")
  (princ "\nTurkiye Standartlarina Gore Donati Yerlestirme")
  (princ "\n========================================")
  (princ "\n1. Temel Donati")
  (princ "\n2. Kolon Donati")
  (princ "\n3. Perde Donati")
  (princ "\n4. Kiris Donati")
  (princ "\n5. Doseme Donati")
  (princ "\n========================================")
  
  (initget 1 "1 2 3 4 5")
  (let ((choice (getkword "\nSeciminiz [1/2/3/4/5] <1>: ")))
    (cond
      ((or (not choice) (= choice "1")) (C:REBAR-FOOTING))
      ((= choice "2") (C:REBAR-COLUMN))
      ((= choice "3") (C:REBAR-WALL))
      ((= choice "4") (C:REBAR-BEAM))
      ((= choice "5") (C:REBAR-SLAB))
      (T (princ "\nGecersiz secim!"))
    )
  )
  (princ)
)

;; ============================================
;; 5. KOMUT TANIMLAMALARI
;; ============================================

;; Ana komutlar
(defun C:R () (C:REBAR))
(defun C:REBAR-MENU () (C:REBAR))

;; Modul komutlari (kisaltmalar)
(defun C:RT () (C:REBAR-FOOTING))  ; R-Temel
(defun C:RK () (C:REBAR-COLUMN))   ; R-Kolon
(defun C:RP () (C:REBAR-WALL))     ; R-Perde
(defun C:RB () (C:REBAR-BEAM))     ; R-Kiris
(defun C:RD () (C:REBAR-SLAB))     ; R-Doseme

;; Turkce komutlar
(defun C:TEMEL () (C:REBAR-FOOTING))
(defun C:KOLON () (C:REBAR-COLUMN))
(defun C:PERDE () (C:REBAR-WALL))
(defun C:KIRIS () (C:REBAR-BEAM))
(defun C:DOSME () (C:REBAR-SLAB))  ; Turkce karakter olmadan

;; ============================================
;; 6. AUTOLOAD AYARLARI
;; ============================================

;; AutoCAD basladiginda otomatik yukle
(if (and (not (vl-catch-all-error-p
          (vl-catch-all-apply 'vla-get-menubar 
            (list (vla-get-activedocument (vlax-get-acad-object))))))
        (= (getvar "CVPORT") 1))
  (progn
    ;; REBAR menusunu olustur
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Donati" "REBAR" "Donati yerlestirme menusu" 1))
    
    ;; Alt menu ogelerini ekle
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Temel" "REBAR-FOOTING" "Temel donati yerlestir" 1))
    
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Kolon" "REBAR-COLUMN" "Kolon donati yerlestir" 1))
    
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Perde" "REBAR-WALL" "Perde donati yerlestir" 1))
    
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Kiris" "REBAR-BEAM" "Kiris donati yerlestir" 1))
    
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Doseme" "REBAR-SLAB" "Doseme donati yerlestir" 1))
    
    (princ "\nREBAR menusu AutoCAD menusune eklendi.")
  )
)

;; ============================================
;; 7. SON MESAJ
;; ============================================

(princ "\n=== REBAR Serisi v1.0 Yuklendi ===")
(princ "\nKullanilabilir komutlar:")
(princ "\n  REBAR      - Ana menu")
(princ "\n  R          - Ana menu (kisaltma)")
(princ "\n  RT / TEMEL - Temel donati")
(princ "\n  RK / KOLON - Kolon donati")
(princ "\n  RP / PERDE - Perde donati")
(princ "\n  RB / KIRIS - Kiris donati")
(princ "\n  RD / DOSME - Doseme donati")
(princ "\n========================================")
(princ "\nTurkiye Standartlarina Gore (TS 500)")
(princ "\nCaplar: 8,10,12,14,16,18,20,22,24,26,28,30,32 mm")
(princ "\n========================================\n")

(princ)