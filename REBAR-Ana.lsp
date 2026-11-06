;;
;; REBAR-Ana.lsp
;; ============================================
;; AutoCAD LISP - Tüm Donatı Yerleştirme Modülleri
;; Ana Yükleyici Dosyası
;; ============================================
;; Oluşturma: 2024
;; Sürüm: 1.0
;;

;; ============================================
;; AÇIKLAMA
;; ============================================
;; Bu dosya, REBAR serisinin tüm modüllerini yükler:
;; - REBAR-Temel.lsp: Temel donatı yerleştirme
;; - REBAR-Kolon.lsp: Kolon ve perde donatı yerleştirme
;; - REBAR-Kiris.lsp: Kiriş donatı yerleştirme
;; - REBAR-Doseme.lsp: Döşeme donatı yerleştirme
;;
;; ============================================

(princ "\n=== REBAR Serisi Ana Yükleyici ===")
(princ "\nTürkiye Standartlarına Göre Donatı Yerleştirme")
(princ "\nÇaplar: 8,10,12,14,16,18,20,22,24,26,28,30,32 mm")
(princ "\n========================================")

;; ============================================
;; 1. VERİ YAPILARI (Ortak)
;; ============================================

;; Donatı Çapları ve Ağırlıkları (Türkiye Standartları)
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

;; Donatı Sınıfları
(setq *rebar-grades* '(
    ("S220"   . 2200)    ; kg/cm²
    ("S420"   . 4200)
    ("B420C"  . 4200)
    ("B500C"  . 5000)
))

;; Minimum Donatı Oranları (TS 500)
(setq *min-rebar-ratios* '(
    ("Temel"      . 0.008)   ; 0.8‰
    ("Kolon"      . 0.010)   ; 1.0‰
    ("Kiriş"      . 0.008)   ; 0.8‰
    ("Döşeme"     . 0.002)   ; 0.2‰
    ("Perde"      . 0.004)   ; 0.4‰
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

;; Donatı Çap Renkleri
(setq *diameter-colors* '(
    (8  . 1)   (10 . 2)   (12 . 3)   (14 . 4)
    (16 . 5)   (18 . 6)   (20 . 7)   (22 . 10)
    (24 . 11)  (26 . 12)  (28 . 13)  (30 . 14)
    (32 . 15)
))

;; Çizgi Tipleri
(setq *linetype-continuous* "CONTINUOUS")

;; ============================================
;; 2. ORTAK YARDIMCI FONKSİYONLAR
;; ============================================

;; --- Nokta İşlemleri ---
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

;; --- Açı Hesaplama ---
(defun angle (p1 p2)
  (atan (/ (- (cadr p2) (cadr p1)) (- (car p2) (car p1)))))

;; --- Donatı Verisini Al ---
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
  (cdr (assoc grade *rebar-grades*))
)

(defun get-min-rebar-ratio (element-type)
  (cdr (assoc element-type *min-rebar-ratios*))
)

(defun get-diameter-color (diameter)
  (cdr (assoc diameter *diameter-colors*))
)

(defun get-layer-color (layer-name)
  (cdr (assoc layer-name *layer-colors*))
)

;; --- Katman Yönetimi ---
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

;; --- Kullanıcı Arayüzü ---
(defun confirm (prompt)
  (initget 1 "Evet Hayır E H")
  (cond
    ((= (getkword (strcat prompt " [Evet/Hayır] <Evet>: ")) "Evet") T)
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
      (progn (alert "Geçersiz çap! 12 olarak ayarlandı.") 12)
      (if (not diameter) 12 diameter)
    )
  )
)

(defun select-stirrup-diameter (prompt)
  (let ((diameter 8))
    (initget 1 "6 8 10 12 14 16")
    (setq diameter (getint (strcat prompt " [6/8/10/12/14/16] <8>: ")))
    (if (and diameter (not (member diameter '(6 8 10 12 14 16))))
      (progn (alert "Geçersiz etriye çapı! 8 olarak ayarlandı.") 8)
      (if (not diameter) 8 diameter)
    )
  )
)

;; ============================================
;; 3. TÜM MODÜLLERİ YÜKLE
;; ============================================

(princ "\nModüller yükleniyor...")

;; Modül dosyalarını yükle - AutoCAD'in arama yolunu kullan
(defun load-rebar-module (filename)
  (let ((filepath (findfile filename)))
    (if filepath
      (progn
        (load filepath)
        T
      )
      (progn
        (princ (strcat "\nUYARI: " filename " bulunamadı!"))
        nil
      )
    )
  )
)

(load-rebar-module "REBAR-Temel.lsp")
(load-rebar-module "REBAR-Kolon.lsp")
(load-rebar-module "REBAR-Kiris.lsp")
(load-rebar-module "REBAR-Doseme.lsp")

;; ============================================
;; 4. ANA MENÜ FONKSİYONU
;; ============================================

(defun C:REBAR ()
  "REBAR Ana Menü - Donatı Yerleştirme Seçenekleri"
  (vl-load-com)
  
  (princ "\n=== REBAR ANA MENÜ ===")
  (princ "\nTürkiye Standartlarına Göre Donatı Yerleştirme")
  (princ "\n========================================")
  (princ "\n1. Temel Donatı")
  (princ "\n2. Kolon Donatı")
  (princ "\n3. Perde Donatı")
  (princ "\n4. Kiriş Donatı")
  (princ "\n5. Döşeme Donatı")
  (princ "\n========================================")
  
  (initget 1 "1 2 3 4 5")
  (let ((choice (getint "\nSeçiminiz [1/2/3/4/5] <1>: ")))
    (cond
      ((or (not choice) (= choice 1)) (C:REBAR-FOOTING))
      ((= choice 2) (C:REBAR-COLUMN))
      ((= choice 3) (C:REBAR-WALL))
      ((= choice 4) (C:REBAR-BEAM))
      ((= choice 5) (C:REBAR-SLAB))
      (T (princ "\nGeçersiz seçim!"))
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

;; Modül komutları (kısaltmalar)
(defun C:RT () (C:REBAR-FOOTING))  ; R-Temel
(defun C:RK () (C:REBAR-COLUMN))   ; R-Kolon
(defun C:RP () (C:REBAR-WALL))     ; R-Perde
(defun C:RB () (C:REBAR-BEAM))     ; R-Kiriş
(defun C:RD () (C:REBAR-SLAB))     ; R-Döşeme

;; Türkçe komutlar
(defun C:TEMEL () (C:REBAR-FOOTING))
(defun C:KOLON () (C:REBAR-COLUMN))
(defun C:PERDE () (C:REBAR-WALL))
(defun C:KIRIS () (C:REBAR-BEAM))
(defun C:DÖŞEME () (C:REBAR-SLAB))
(defun C:DOSME () (C:REBAR-SLAB))  ; Türkçe karakter olmadan

;; ============================================
;; 6. AUTOLOAD AYARLARI
;; ============================================

;; AutoCAD başladığında otomatik yükle
(if (and (not (vl-catch-all-error-p
          (vl-catch-all-apply 'vla-get-menubar 
            (list (vla-get-activedocument (vlax-get-acad-object))))))
        (= (getvar "CVPORT") 1))
  (progn
    ;; REBAR menüsünü oluştur
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Donatı" "REBAR" "Donatı yerleştirme menüsü" 1))
    
    ;; Alt menü öğelerini ekle
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Temel" "REBAR-FOOTING" "Temel donatı yerleştir" 1))
    
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Kolon" "REBAR-COLUMN" "Kolon donatı yerleştir" 1))
    
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Perde" "REBAR-WALL" "Perde donatı yerleştir" 1))
    
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Kiriş" "REBAR-BEAM" "Kiriş donatı yerleştir" 1))
    
    (vl-catch-all-apply 'vla-addcommand
      (list (vla-get-menubar (vla-get-activedocument (vlax-get-acad-object)))
            "REBAR" "Döşeme" "REBAR-SLAB" "Döşeme donatı yerleştir" 1))
    
    (princ "\nREBAR menüsü AutoCAD menüsüne eklendi.")
  )
)

;; ============================================
;; 7. SON MESAJ
;; ============================================

(princ "\n=== REBAR Serisi v1.0 Yüklendi ===")
(princ "\nKullanılabilir komutlar:")
(princ "\n  REBAR      - Ana menü")
(princ "\n  R          - Ana menü (kısaltma)")
(princ "\n  RT / TEMEL - Temel donatı")
(princ "\n  RK / KOLON - Kolon donatı")
(princ "\n  RP / PERDE - Perde donatı")
(princ "\n  RB / KIRIS - Kiriş donatı")
(princ "\n  RD / DOSME - Döşeme donatı")
(princ "\n========================================")
(princ "\nTürkiye Standartlarına Göre (TS 500)")
(princ "\nÇaplar: 8,10,12,14,16,18,20,22,24,26,28,30,32 mm")
(princ "\n========================================\n")

(princ)
