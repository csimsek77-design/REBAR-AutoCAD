;;
;; REBAR-Temel.lsp
;; ============================================
;; AutoCAD LISP - Temel Donatı Yerleştirme (Tekil / Sürekli / Radye)
;; Türkiye Standartlarına Göre (TS 500)
;; ============================================
;; Sürüm: 2.0
;; Gerekli: REBAR-Ortak.lsp
;;
;; Çizim: PLAN görünüşü. Alt donatı düz çizgi, üst donatı kesikli çizgi.
;; "X donatısı" = X eksenine paralel çubuklar (Y boyunca dizilir).
;;

(if (not *rb:ortak-yuklendi*)
  (if (findfile "REBAR-Ortak.lsp")
    (load "REBAR-Ortak.lsp")
    (alert "REBAR-Ortak.lsp bulunamadı!\nDosyayı REBAR-Temel.lsp ile aynı klasöre koyun\nve klasörü AutoCAD destek yollarına ekleyin.")))

;; ============================================
;; ÇİZİM
;; ============================================

;; Bir donatı ağını (X ve Y çubukları) çizer, metraj satırlarını döndürür.
;; B: X boyutu, L: Y boyutu, c: paspayı, xa/ya: (çap aralık), katman,
;; etiket: "Alt"/"Üst", konum-orani: etiketin hangi çubukta duracağı (0..1)
(defun rb:temel-ag (B L c xa ya katman etiket konum-orani poz h
                    / capx sx capy sy rx ry ysler xsler boyx boyy nx ny ye xe)
  (setq capx (car xa) sx (cadr xa) capy (car ya) sy (cadr ya)
        rx (/ capx 20.0) ry (/ capy 20.0)
        ;; X çubukları Y boyunca dizilir
        ysler (rb:diz (+ c rx) (- L (* 2.0 (+ c rx))) sx)
        ;; Y çubukları X boyunca dizilir
        xsler (rb:diz (+ c ry) (- B (* 2.0 (+ c ry))) sy)
        boyx (- B (* 2.0 c))
        boyy (- L (* 2.0 c))
        nx (length ysler)
        ny (length xsler))
  (foreach y ysler (rb:cizgi (list c y) (list (- B c) y) katman (rb:renk capx)))
  (foreach x xsler (rb:cizgi (list x c) (list x (- L c)) katman (rb:renk capy)))
  ;; Etiketler
  (if ysler
    (progn
      (setq ye (nth (fix (* konum-orani (1- nx))) ysler))
      (rb:yazi (/ B 2.0) (+ ye (* 0.8 h))
               (strcat etiket " X: " (itoa nx) "%%c" (itoa capx) "/" (rb:s sx) " L=" (rb:s boyx))
               h 0.0 "REBAR-TEXT")))
  (if xsler
    (progn
      (setq xe (nth (fix (* konum-orani (1- ny))) xsler))
      (rb:yazi (- xe (* 0.8 h)) (/ L 2.0)
               (strcat etiket " Y: " (itoa ny) "%%c" (itoa capy) "/" (rb:s sy) " L=" (rb:s boyy))
               h (/ pi 2.0) "REBAR-TEXT")))
  (list (rb:satir (strcat poz ".1") (strcat etiket " X") capx nx boyx)
        (rb:satir (strcat poz ".2") (strcat etiket " Y") capy ny boyy)))

;; ============================================
;; KONTROLLER
;; ============================================

(defun rb:temel-kontrol (B L H c xa ya ust xu yu / rmin)
  (princ "\n--- TS 500 Kontrolleri ---")
  (setq rmin (rb:rho-min-plak))
  (rb:paspayi-kontrol "TEMEL" c (max (car xa) (car ya)))
  (rb:kontrol (>= H 25.0) (strcat "Temel yüksekliği " (rb:s H) " cm >= 25 cm"))
  (foreach d (append (list (list "Alt X" xa L) (list "Alt Y" ya B))
                     (if ust (list (list "Üst X" xu L) (list "Üst Y" yu B))))
    (rb:net-aralik-kontrol (car d) (cadr (cadr d)) (car (cadr d)) 2.5)
    (rb:max-aralik-kontrol (car d) (cadr (cadr d)) 30.0))
  ;; Alt donatı oranı: As / (kesit genişliği * H), her doğrultuda
  (rb:oran-kontrol "Alt X"
    (/ (* (rb:alan (car xa)) (/ 100.0 (cadr xa))) (* 100.0 H)) rmin)
  (rb:oran-kontrol "Alt Y"
    (/ (* (rb:alan (car ya)) (/ 100.0 (cadr ya))) (* 100.0 H)) rmin))

;; ============================================
;; ANA GÖVDE
;; ============================================

(defun rb:temel-govde ( / tip vars p0 B L H c xa ya ust xu yu yh satirlar)
  (rb:katmanlari-hazirla
    '("REBAR-FOOTING" "REBAR-FOOTING-BOT" "REBAR-FOOTING-TOP" "REBAR-TEXT" "REBAR-DIM" "REBAR-TABLE"))
  (setq tip (rb:secenek-al "Temel tipi" "Tekil Surekli Radye" "Tekil"))
  (setq vars (cond ((= tip "Tekil")   '(150.0 150.0 60.0))
                   ((= tip "Surekli") '(80.0 1000.0 60.0))
                   (T                 '(1000.0 1500.0 80.0))))
  (setq p0 (getpoint "\nTemel sol-alt köşe noktasını seçiniz: "))
  (if (null p0)
    (princ "\nNokta seçilmedi, iptal edildi.")
    (progn
      (setq B (rb:sayi-al "Temel genişliği - X yönü (cm)" (car vars))
            L (rb:sayi-al "Temel uzunluğu - Y yönü (cm)" (cadr vars))
            H (rb:sayi-al "Temel yüksekliği (cm)" (caddr vars))
            c (rb:sayi-al "Paspayı (cm)" (rb:min-paspayi "TEMEL")))
      (princ "\n--- Alt Donatı ---")
      (setq xa (rb:cap-aralik-al "Alt X donatısı" 14 15.0)
            ya (rb:cap-aralik-al "Alt Y donatısı" 14 15.0))
      (setq ust (rb:evet-mi "Üst donatı ağı (çift kat) eklensin mi?" (/= tip "Tekil")))
      (if ust
        (setq xu (rb:cap-aralik-al "Üst X donatısı" (car xa) (cadr xa))
              yu (rb:cap-aralik-al "Üst Y donatısı" (car ya) (cadr ya))))
      (rb:temel-kontrol B L H c xa ya ust xu yu)
      (if (rb:evet-mi "Donatı çizilsin mi?" T)
        (progn
          (setq yh (rb:yh (max B L)))
          (rb:koord (rb:wcs p0) (rb:ucs-aci))
          (rb:dikdortgen 0.0 0.0 B L "REBAR-FOOTING" nil)
          (setq satirlar (rb:temel-ag B L c xa ya "REBAR-FOOTING-BOT" "Alt" 0.25 "1" yh))
          (if ust
            (setq satirlar (append satirlar
                                   (rb:temel-ag B L c xu yu "REBAR-FOOTING-TOP" "Üst" 0.75 "2" yh))))
          (rb:yazi (/ B 2.0) (- (* 6.0 yh))
                   (strcat (cond ((= tip "Tekil") "TEKİL TEMEL ")
                                 ((= tip "Surekli") "SÜREKLİ TEMEL ")
                                 (T "RADYE TEMEL "))
                           (rb:s B) "x" (rb:s L) " H=" (rb:s H))
                   (* 1.2 yh) 0.0 "REBAR-TEXT")
          (rb:olcu (list 0.0 0.0) (list B 0.0) (- (* 3.0 yh)) yh)
          (rb:olcu (list B 0.0) (list B L) (- (* 3.0 yh)) yh)
          (rb:metraj-sonu satirlar (rb:lp (+ B (* 8.0 yh)) L) yh)
          (rb:uyari-ozeti)))))
  (princ))

;; ============================================
;; KOMUTLAR
;; ============================================

(defun c:REBAR-FOOTING () (rb:komut "REBAR-Temel: Temel Donatısı" 'rb:temel-govde))
(defun c:RT () (c:REBAR-FOOTING))
(defun c:TEMEL () (c:REBAR-FOOTING))
(defun c:RFT () (c:REBAR-FOOTING))

(princ "\nREBAR-Temel v2.0 yüklendi. Komutlar: REBAR-FOOTING / RT / TEMEL")
(princ)
