;;
;; REBAR-Kolon.lsp
;; ============================================
;; AutoCAD LISP - Kolon ve Perde Donatı Yerleştirme
;; Türkiye Standartlarına Göre (TS 500 / TBDY 2018)
;; ============================================
;; Sürüm: 2.0
;; Gerekli: REBAR-Ortak.lsp
;;
;; Kolon: KESİT (plan) çizilir: kalıp, etriye, boyuna çubuklar, çirozlar.
;; Perde: KESİT (plan) çizilir: iki yüzde yatay çubuklar ve düşey çubuklar.
;;

(if (not *rb:ortak-yuklendi*)
  (if (findfile "REBAR-Ortak.lsp")
    (load "REBAR-Ortak.lsp")
    (alert "REBAR-Ortak.lsp bulunamadı!\nDosyayı REBAR-Kolon.lsp ile aynı klasöre koyun\nve klasörü AutoCAD destek yollarına ekleyin.")))

;; ============================================
;; ORTAK KOLON HESAPLARI
;; ============================================

;; Etriye kanca boyu (135°, her uç): max(10Ø, 10 cm)
(defun rb:kanca (cap-e) (max (* 10.0 (rb:cm cap-e)) 10.0))

;; Kolon etriye adedi: iki uçta sarılma bölgesi (su aralıklı), ortada so aralıklı
;; Hk: kolon net yüksekliği, lu: sarılma bölgesi boyu
(defun rb:kolon-etriye-adedi (Hk lu su so / n-uc orta)
  (if (<= Hk (* 2.0 lu))
    (rb:adet Hk su)
    (progn
      (setq n-uc (rb:adet lu su)
            orta (- Hk (* 2.0 lu)))
      (+ (* 2 n-uc) (max 0 (1- (rb:tavan (/ orta so))))))))

;; ============================================
;; KOLON GÖVDESİ
;; ============================================

(defun rb:kolon-govde ( / tip p0 bx hy D Hk c capb nx ny n cape su so lb ciroz
                         bmin bmax lu a ae xler yler ara-y n-etr boy-etr
                         satirlar yh Ac rho net-x net-y
                         su-max so-max r-etr r-cub ang i)
  (rb:katmanlari-hazirla
    '("REBAR-COLUMN" "REBAR-COLUMN-BOYUNA" "REBAR-COLUMN-ETRIYE" "REBAR-TEXT" "REBAR-DIM" "REBAR-TABLE"))
  (setq tip (rb:secenek-al "Kolon tipi" "Dikdortgen Kare Dairesel" "Dikdortgen"))
  (setq p0 (getpoint (if (= tip "Dairesel")
                       "\nKolon merkez noktasını seçiniz: "
                       "\nKolon sol-alt köşe noktasını seçiniz: ")))
  (if (null p0)
    (princ "\nNokta seçilmedi, iptal edildi.")
    (progn
      ;; --- Boyutlar ---
      (cond
        ((= tip "Dairesel")
         (setq D (rb:sayi-al "Kolon çapı (cm)" 50.0) bx D hy D))
        ((= tip "Kare")
         (setq bx (rb:sayi-al "Kolon boyutu (cm)" 50.0) hy bx))
        (T
         (setq bx (rb:sayi-al "Kolon genişliği - X yönü (cm)" 40.0)
               hy (rb:sayi-al "Kolon uzunluğu - Y yönü (cm)" 60.0))))
      (setq Hk (rb:sayi-al "Kolon net yüksekliği (cm)" 300.0)
            c  (rb:sayi-al "Paspayı (cm)" 3.0)
            bmin (min bx hy) bmax (max bx hy))
      ;; --- Boyuna donatı ---
      (princ "\n--- Boyuna Donatı ---")
      (setq capb (rb:cap-al "Boyuna donatı çapı (mm)" 16 *rb:caplar*))
      (if (= tip "Dairesel")
        (setq n (rb:tamsayi-al "Toplam boyuna çubuk adedi"
                               (max 6 (rb:tavan (/ (* 0.01 pi D D 0.25) (rb:alan capb)))) 6))
        (progn
          ;; Varsayılan adetler: ~15 cm aralık, ρ >= %1 olana kadar artır
          (setq nx (max 2 (1+ (fix (/ (- bx (* 2.0 c)) 15.0))))
                ny (max 2 (1+ (fix (/ (- hy (* 2.0 c)) 15.0)))))
          (while (< (* (- (* 2 (+ nx ny)) 4) (rb:alan capb)) (* 0.01 bx hy))
            (if (> (/ bx (float nx)) (/ hy (float ny))) (setq nx (1+ nx)) (setq ny (1+ ny))))
          (setq nx (rb:tamsayi-al "X yüzündeki çubuk adedi (köşeler dahil)" nx 2)
                ny (rb:tamsayi-al "Y yüzündeki çubuk adedi (köşeler dahil)" ny 2)
                n  (- (* 2 (+ nx ny)) 4))))
      (setq lb (rb:sayi-al "Boyuna çubuk boyu - filiz/bindirme dahil (cm)" Hk))
      ;; --- Etriye ---
      (princ "\n--- Etriye ---")
      (setq cape (rb:cap-al "Etriye çapı (mm)" 8 *rb:etriye-caplari*)
            ;; TBDY 7.3.4: sarılma bölgesi boyu ve aralıkları
            lu (max bmax (/ Hk 6.0) 50.0)
            su-max (min (/ bmin 3.0) 15.0 (* 6.0 (rb:cm capb)))
            so-max (min (* 12.0 (rb:cm capb)) bmin 20.0)
            su (rb:sayi-al (strcat "Sarılma bölgesi etriye aralığı (uçlarda " (rb:s lu) " cm)")
                           (max 5.0 (float (fix su-max))))
            so (rb:sayi-al "Orta bölge etriye aralığı (cm)" (max 5.0 (float (fix so-max)))))
      (if (/= tip "Dairesel")
        (setq ciroz (and (or (> nx 2) (> ny 2))
                         (rb:evet-mi "Ara çubuklara çiroz eklensin mi?" T))))
      ;; --- Hesaplar ---
      (setq a  (+ c (rb:cm cape) (/ capb 20.0))    ; yüzden boyuna çubuk merkezine
            ae (+ c (/ cape 20.0))                  ; yüzden etriye eksenine
            Ac (if (= tip "Dairesel") (/ (* pi D D) 4.0) (* bx hy))
            rho (/ (* n (rb:alan capb)) Ac)
            n-etr (rb:kolon-etriye-adedi Hk lu su so))
      (if (= tip "Dairesel")
        (setq boy-etr (+ (* pi (- D (* 2.0 ae))) (* 2.0 (rb:kanca cape))))
        (setq boy-etr (+ (* 2.0 (+ (- bx (* 2.0 ae)) (- hy (* 2.0 ae))))
                         (* 2.0 (rb:kanca cape)))))
      ;; --- Kontroller ---
      (princ "\n--- TS 500 / TBDY 2018 Kontrolleri ---")
      (rb:paspayi-kontrol "KOLON" c capb)
      (if (= tip "Dairesel")
        (rb:kontrol (>= D 35.0) (strcat "Dairesel kolon çapı " (rb:s D) " cm >= 35 cm (TBDY)"))
        (rb:kontrol (>= bmin 30.0) (strcat "Kolon kısa kenarı " (rb:s bmin) " cm >= 30 cm (TBDY)")))
      (rb:kontrol (and (>= rho 0.01) (<= rho 0.04))
                  (strcat "Boyuna donatı oranı " (rb:yuzde rho) " aralığı %1 - %4"))
      (if (= tip "Dairesel")
        (setq net-x (- (/ (* pi (- D (* 2.0 a))) n) (rb:cm capb)))
        (setq net-x (- (/ (- bx (* 2.0 a)) (1- nx)) (rb:cm capb))
              net-y (- (/ (- hy (* 2.0 a)) (1- ny)) (rb:cm capb))))
      (foreach nt (list net-x net-y)
        (if nt
          (rb:kontrol (>= nt (max (* 1.5 (rb:cm capb)) 4.0))
                      (strcat "Boyuna çubuk net aralığı " (rb:s2 nt) " cm >= max(1.5Ø, 4 cm)"))))
      (rb:kontrol (>= cape 8) (strcat "Etriye çapı Ø" (itoa cape) " >= Ø8 (TBDY)"))
      (rb:kontrol (>= cape (/ capb 3.0)) "Etriye çapı >= boyuna çap / 3")
      (rb:max-aralik-kontrol "Sarılma bölgesi etriye" su su-max)
      (rb:max-aralik-kontrol "Orta bölge etriye" so so-max)
      ;; --- Çizim ---
      (if (rb:evet-mi "Donatı çizilsin mi?" T)
        (progn
          (setq yh (rb:yh (* 4.0 bmax)))
          (rb:koord (rb:wcs p0) (rb:ucs-aci))
          (if (= tip "Dairesel")
            (progn
              ;; yerel orijin = merkez
              (rb:daire 0.0 0.0 (/ D 2.0) "REBAR-COLUMN" nil)
              (setq r-etr (- (/ D 2.0) ae))
              (rb:daire 0.0 0.0 r-etr "REBAR-COLUMN-ETRIYE" (rb:renk cape))
              (setq r-cub (- (/ D 2.0) a) i 0)
              (repeat n
                (setq ang (/ (* 2.0 pi i) n))
                (rb:cubuk (* r-cub (cos ang)) (* r-cub (sin ang)) capb "REBAR-COLUMN-BOYUNA")
                (setq i (1+ i)))
              (rb:olcu (list (- (/ D 2.0)) (- (/ D 2.0))) (list (/ D 2.0) (- (/ D 2.0)))
                       (- (* 2.0 yh)) yh)
              (setq p0 (list (- (/ D 2.0)) (- (/ D 2.0)))))   ; yazılar için sol-alt
            (progn
              (rb:dikdortgen 0.0 0.0 bx hy "REBAR-COLUMN" nil)
              (rb:dikdortgen ae ae (- bx (* 2.0 ae)) (- hy (* 2.0 ae))
                             "REBAR-COLUMN-ETRIYE" (rb:renk cape))
              (setq xler (rb:esit a (- bx a) nx)
                    yler (rb:esit a (- hy a) ny))
              ;; alt ve üst yüz çubukları
              (foreach x xler
                (rb:cubuk x a capb "REBAR-COLUMN-BOYUNA")
                (rb:cubuk x (- hy a) capb "REBAR-COLUMN-BOYUNA"))
              ;; sol ve sağ yüz ara çubukları (köşeler hariç)
              (setq ara-y (cdr (reverse (cdr yler))))
              (foreach y ara-y
                (rb:cubuk a y capb "REBAR-COLUMN-BOYUNA")
                (rb:cubuk (- bx a) y capb "REBAR-COLUMN-BOYUNA"))
              ;; çirozlar
              (if ciroz
                (progn
                  (foreach x (cdr (reverse (cdr xler)))
                    (rb:cizgi (list x ae) (list x (- hy ae)) "REBAR-COLUMN-ETRIYE" (rb:renk cape)))
                  (foreach y ara-y
                    (rb:cizgi (list ae y) (list (- bx ae) y) "REBAR-COLUMN-ETRIYE" (rb:renk cape)))))
              (rb:olcu (list 0.0 0.0) (list bx 0.0) (- (* 2.0 yh)) yh)
              (rb:olcu (list bx 0.0) (list bx hy) (- (* 2.0 yh)) yh)
              (setq p0 (list 0.0 0.0))))
          ;; --- Yazılar (kesitin altında) ---
          (rb:yazi (+ (car p0) (/ bx 2.0)) (- (cadr p0) (* 5.0 yh))
                   (strcat "KOLON " (if (= tip "Dairesel") (strcat "%%c" (rb:s D)) (strcat (rb:s bx) "x" (rb:s hy))))
                   (* 1.2 yh) 0.0 "REBAR-TEXT")
          (rb:yazi (+ (car p0) (/ bx 2.0)) (- (cadr p0) (* 7.0 yh))
                   (strcat (itoa n) "%%c" (itoa capb) "  (" (rb:yuzde rho) ")")
                   yh 0.0 "REBAR-TEXT")
          (rb:yazi (+ (car p0) (/ bx 2.0)) (- (cadr p0) (* 9.0 yh))
                   (strcat "Etr. %%c" (itoa cape) "/" (rb:s su) "/" (rb:s so) "  (" (itoa n-etr) " ad.)")
                   yh 0.0 "REBAR-TEXT")
          ;; --- Metraj ---
          (setq satirlar (list (rb:satir "1" "Boyuna" capb n lb)
                               (rb:satir "2" (if (= tip "Dairesel") "Fret" "Etriye") cape n-etr boy-etr)))
          (if ciroz
            (progn
              ;; X yüzü ara çubuklarını bağlayan çirozlar (Y yönünde) ve tersi
              (if (> nx 2)
                (setq satirlar (append satirlar
                  (list (rb:satir "3" "Çiroz-Y" cape (* (- nx 2) n-etr)
                                  (+ (- hy (* 2.0 ae)) (* 2.0 (rb:kanca cape))))))))
              (if (> ny 2)
                (setq satirlar (append satirlar
                  (list (rb:satir "4" "Çiroz-X" cape (* (- ny 2) n-etr)
                                  (+ (- bx (* 2.0 ae)) (* 2.0 (rb:kanca cape))))))))))
          (rb:metraj-sonu satirlar (rb:lp (+ (car p0) bx (* 6.0 yh)) (+ (cadr p0) hy)) yh)
          (rb:uyari-ozeti)))))
  (princ))

;; ============================================
;; PERDE GÖVDESİ
;; ============================================

(defun rb:perde-govde ( / p0 lw tw Hw c dv yv capv sv caph sh a-h a-v xler n-v n-h
                         boy-v boy-h rho-v rho-h yh satirlar)
  (rb:katmanlari-hazirla
    '("REBAR-WALL" "REBAR-WALL-DIKEY" "REBAR-WALL-YATAY" "REBAR-TEXT" "REBAR-DIM" "REBAR-TABLE"))
  (setq p0 (getpoint "\nPerde sol-alt köşe noktasını seçiniz: "))
  (if (null p0)
    (princ "\nNokta seçilmedi, iptal edildi.")
    (progn
      (setq lw (rb:sayi-al "Perde uzunluğu - X yönü (cm)" 300.0)
            tw (rb:sayi-al "Perde kalınlığı - Y yönü (cm)" 25.0)
            Hw (rb:sayi-al "Perde (kat) yüksekliği (cm)" 300.0)
            c  (rb:sayi-al "Paspayı (cm)" 2.5))
      (princ "\n--- Gövde Donatısı (her iki yüzde) ---")
      (setq dv (rb:cap-aralik-al "Düşey donatı" 12 20.0)
            yv (rb:cap-aralik-al "Yatay donatı" 10 20.0)
            capv (car dv) sv (cadr dv)
            caph (car yv) sh (cadr yv))
      ;; Yatay çubuklar dışta, düşey çubuklar içte
      (setq a-h (+ c (/ caph 20.0))
            a-v (+ c (rb:cm caph) (/ capv 20.0))
            xler (rb:diz a-v (- lw (* 2.0 a-v)) sv)
            n-v (* 2 (length xler))
            n-h (* 2 (rb:adet Hw sh))
            boy-v Hw
            boy-h (- lw (* 2.0 c))
            rho-v (/ (* 2.0 (rb:alan capv)) (* tw sv))
            rho-h (/ (* 2.0 (rb:alan caph)) (* tw sh)))
      (princ "\n--- TS 500 / TBDY 2018 Kontrolleri ---")
      (rb:paspayi-kontrol "PERDE" c (max capv caph))
      (rb:kontrol (>= tw 20.0) (strcat "Perde kalınlığı " (rb:s tw) " cm >= 20 cm (TBDY)"))
      (rb:kontrol (>= tw (/ Hw 20.0)) "Perde kalınlığı >= kat yüksekliği / 20 (TBDY)")
      (rb:oran-kontrol "Düşey gövde" rho-v 0.0025)
      (rb:oran-kontrol "Yatay gövde" rho-h 0.0025)
      (rb:max-aralik-kontrol "Düşey donatı" sv 25.0)
      (rb:max-aralik-kontrol "Yatay donatı" sh 25.0)
      (rb:net-aralik-kontrol "Düşey donatı" sv capv 2.5)
      (if (rb:evet-mi "Donatı çizilsin mi?" T)
        (progn
          (setq yh (rb:yh lw))
          (rb:koord (rb:wcs p0) (rb:ucs-aci))
          (rb:dikdortgen 0.0 0.0 lw tw "REBAR-WALL" nil)
          ;; yatay çubuklar (iki yüz)
          (rb:cizgi (list c a-h) (list (- lw c) a-h) "REBAR-WALL-YATAY" (rb:renk caph))
          (rb:cizgi (list c (- tw a-h)) (list (- lw c) (- tw a-h)) "REBAR-WALL-YATAY" (rb:renk caph))
          ;; düşey çubuklar (iki yüz)
          (foreach x xler
            (rb:cubuk x a-v capv "REBAR-WALL-DIKEY")
            (rb:cubuk x (- tw a-v) capv "REBAR-WALL-DIKEY"))
          (rb:yazi (/ lw 2.0) (+ tw (* 1.5 yh))
                   (strcat "Düşey: 2x" (itoa (/ n-v 2)) "%%c" (itoa capv) "/" (rb:s sv)
                           "   Yatay: %%c" (itoa caph) "/" (rb:s sh) " (çift sıra)")
                   yh 0.0 "REBAR-TEXT")
          (rb:yazi (/ lw 2.0) (- (* 5.0 yh))
                   (strcat "PERDE " (rb:s lw) "x" (rb:s tw) " H=" (rb:s Hw))
                   (* 1.2 yh) 0.0 "REBAR-TEXT")
          (rb:olcu (list 0.0 0.0) (list lw 0.0) (- (* 2.0 yh)) yh)
          (rb:olcu (list lw 0.0) (list lw tw) (- (* 2.0 yh)) yh)
          (setq satirlar (list (rb:satir "1" "Düşey" capv n-v boy-v)
                               (rb:satir "2" "Yatay" caph n-h boy-h)))
          (princ "\nNot: Çiroz ve perde uç bölgesi (kolon) donatısı ayrıca tanımlanmalıdır.")
          (rb:metraj-sonu satirlar (rb:lp (+ lw (* 6.0 yh)) tw) yh)
          (rb:uyari-ozeti)))))
  (princ))

;; ============================================
;; KOMUTLAR
;; ============================================

(defun c:REBAR-COLUMN () (rb:komut "REBAR-Kolon: Kolon Donatısı" 'rb:kolon-govde))
(defun c:REBAR-WALL ()   (rb:komut "REBAR-Perde: Perde Donatısı" 'rb:perde-govde))
(defun c:RK () (c:REBAR-COLUMN))
(defun c:RC () (c:REBAR-COLUMN))
(defun c:KOLON () (c:REBAR-COLUMN))
(defun c:RP () (c:REBAR-WALL))
(defun c:RW () (c:REBAR-WALL))
(defun c:PERDE () (c:REBAR-WALL))

(princ "\nREBAR-Kolon v2.0 yüklendi. Komutlar: REBAR-COLUMN / RK / KOLON, REBAR-WALL / RP / PERDE")
(princ)
