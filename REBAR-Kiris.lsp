;;
;; REBAR-Kiris.lsp
;; ============================================
;; AutoCAD LISP - Kiriş Donatı Yerleştirme
;; Türkiye Standartlarına Göre (TS 500 / TBDY 2018)
;; ============================================
;; Sürüm: 2.0
;; Gerekli: REBAR-Ortak.lsp
;;
;; Çizim: Kiriş BOYUNA GÖRÜNÜŞÜ (seçilen iki nokta doğrultusunda) ve
;; yanında enine KESİT. Etriyeler uçlarda sıklaştırılır (sarılma bölgesi = 2h).
;;

(if (not *rb:ortak-yuklendi*)
  (if (findfile "REBAR-Ortak.lsp")
    (load "REBAR-Ortak.lsp")
    (alert "REBAR-Ortak.lsp bulunamadı!\nDosyayı REBAR-Kiris.lsp ile aynı klasöre koyun\nve klasörü AutoCAD destek yollarına ekleyin.")))

;; ============================================
;; ETRİYE KONUMLARI
;; ============================================
;; Ln: kiriş net açıklığı, lu: sarılma bölgesi boyu, su/so: aralıklar
;; İlk etriye mesnet yüzünden 5 cm içeride (TBDY).
(defun rb:kiris-etriye-konumlari (Ln lu su so / x sol orta n-orta k lst)
  (if (<= Ln (+ (* 2.0 lu) so))
    ;; kısa kiriş: tamamı sıklaştırılmış
    (rb:diz 5.0 (- Ln 10.0) su)
    (progn
      (setq x 5.0)
      (while (<= x (+ lu 1e-6))
        (setq sol (cons x sol) x (+ x su)))
      (setq sol (reverse sol)
            orta (- Ln (* 2.0 lu))
            n-orta (1- (rb:tavan (/ orta so)))
            k 1)
      (repeat (max 0 n-orta)
        (setq lst (cons (+ lu (* k (/ orta (1+ n-orta)))) lst) k (1+ k)))
      (append sol
              (reverse lst)
              (reverse (mapcar '(lambda (v) (- Ln v)) sol))))))

;; ============================================
;; KİRİŞ GÖVDESİ
;; ============================================

(defun rb:kiris-govde ( / p1 p2 w1 w2 Ln bw hk c n-alt cap-alt n-ust cap-ust cape
                         su so lu dd su-max so-max a-alt a-ust ae konumlar n-etr
                         boy-etr boy-boyuna rho rho-max net yh kx satirlar xs)
  (rb:katmanlari-hazirla
    '("REBAR-BEAM" "REBAR-BEAM-TOP" "REBAR-BEAM-BOT" "REBAR-BEAM-ETRIYE"
      "REBAR-TEXT" "REBAR-DIM" "REBAR-TABLE"))
  (setq p1 (getpoint "\nKiriş başlangıç noktası (mesnet yüzü): "))
  (if p1 (setq p2 (getpoint p1 "\nKiriş bitiş noktası (mesnet yüzü): ")))
  (if (or (null p1) (null p2))
    (princ "\nNokta seçilmedi, iptal edildi.")
    (progn
      (setq w1 (rb:wcs p1) w2 (rb:wcs p2)
            Ln (distance (rb:2d w1) (rb:2d w2)))
      (princ (strcat "\nKiriş net açıklığı: " (rb:s2 Ln) " cm"))
      (setq bw (rb:sayi-al "Kiriş genişliği bw (cm)" 30.0)
            hk (rb:sayi-al "Kiriş yüksekliği h (cm)" 50.0)
            c  (rb:sayi-al "Paspayı (cm)" 3.0))
      (princ "\n--- Alt (açıklık) Donatısı ---")
      (setq cap-alt (rb:cap-al "Alt donatı çapı (mm)" 16 *rb:caplar*)
            n-alt   (rb:tamsayi-al "Alt donatı adedi" 3 2))
      (princ "\n--- Üst (mesnet/montaj) Donatısı ---")
      (setq cap-ust (rb:cap-al "Üst donatı çapı (mm)" 14 *rb:caplar*)
            n-ust   (rb:tamsayi-al "Üst donatı adedi" 2 2))
      (princ "\n--- Etriye ---")
      (setq cape (rb:cap-al "Etriye çapı (mm)" 8 *rb:etriye-caplari*)
            dd   (- hk c (rb:cm cape) (/ cap-alt 20.0))     ; faydalı yükseklik d
            lu   (* 2.0 hk)                                   ; TBDY sarılma bölgesi
            su-max (min (/ hk 4.0) (* 8.0 (rb:cm (min cap-alt cap-ust))) 15.0)
            so-max (/ dd 2.0)
            su (rb:sayi-al (strcat "Sarılma bölgesi etriye aralığı (uçlarda " (rb:s lu) " cm)")
                           (max 5.0 (float (fix su-max))))
            so (rb:sayi-al "Orta bölge etriye aralığı (cm)" (max 5.0 (float (fix (min so-max 20.0))))))
      ;; --- Hesaplar ---
      (setq ae    (+ c (/ cape 20.0))
            a-alt (+ c (rb:cm cape) (/ cap-alt 20.0))
            a-ust (+ c (rb:cm cape) (/ cap-ust 20.0))
            konumlar (rb:kiris-etriye-konumlari Ln lu su so)
            n-etr (length konumlar)
            boy-etr (+ (* 2.0 (+ (- bw (* 2.0 ae)) (- hk (* 2.0 ae)))) (* 2.0 (max (* 10.0 (rb:cm cape)) 10.0)))
            boy-boyuna (- Ln (* 2.0 c))
            rho (/ (* n-alt (rb:alan cap-alt)) (* bw dd))
            rho-max 0.02)
      ;; --- Kontroller ---
      (princ "\n--- TS 500 / TBDY 2018 Kontrolleri ---")
      (rb:paspayi-kontrol "KIRIS" c (max cap-alt cap-ust))
      (rb:kontrol (>= bw 25.0) (strcat "Kiriş genişliği " (rb:s bw) " cm >= 25 cm (TBDY)"))
      (rb:kontrol (>= hk 30.0) (strcat "Kiriş yüksekliği " (rb:s hk) " cm >= 30 cm (TBDY)"))
      (rb:oran-kontrol "Alt (çekme)" rho (rb:rho-min-kiris))
      (rb:kontrol (<= rho rho-max) (strcat "Alt donatı oranı " (rb:yuzde rho) " <= %2 (TBDY)"))
      (foreach d (list (list "Alt" n-alt cap-alt a-alt) (list "Üst" n-ust cap-ust a-ust))
        (setq net (- (/ (- bw (* 2.0 (nth 3 d))) (1- (nth 1 d))) (rb:cm (nth 2 d))))
        (rb:kontrol (>= net (max (rb:cm (nth 2 d)) 2.5))
                    (strcat (car d) " çubuklar net aralığı " (rb:s2 net) " cm >= max(Ø, 2.5 cm)")))
      (rb:kontrol (>= cape 8) (strcat "Etriye çapı Ø" (itoa cape) " >= Ø8 (TBDY)"))
      (rb:max-aralik-kontrol "Sarılma bölgesi etriye" su su-max)
      (rb:max-aralik-kontrol "Orta bölge etriye (d/2)" so so-max)
      ;; --- Çizim ---
      (if (rb:evet-mi "Donatı çizilsin mi?" T)
        (progn
          (setq yh (rb:yh (* 4.0 hk)))
          ;; yerel x: kiriş ekseni (p1 -> p2), yerel y: yukarı (görünüş düzlemi)
          (rb:koord w1 (angle (rb:2d w1) (rb:2d w2)))
          ;; Görünüş
          (rb:dikdortgen 0.0 0.0 Ln hk "REBAR-BEAM" nil)
          (rb:cizgi (list c a-alt) (list (- Ln c) a-alt) "REBAR-BEAM-BOT" (rb:renk cap-alt))
          (rb:cizgi (list c (- hk a-ust)) (list (- Ln c) (- hk a-ust)) "REBAR-BEAM-TOP" (rb:renk cap-ust))
          (foreach x konumlar
            (rb:cizgi (list x c) (list x (- hk c)) "REBAR-BEAM-ETRIYE" (rb:renk cape)))
          (rb:yazi (/ Ln 2.0) (- (* 1.5 yh))
                   (strcat (itoa n-alt) "%%c" (itoa cap-alt) " L=" (rb:s boy-boyuna) " (alt)")
                   yh 0.0 "REBAR-TEXT")
          (rb:yazi (/ Ln 2.0) (+ hk (* 1.5 yh))
                   (strcat (itoa n-ust) "%%c" (itoa cap-ust) " L=" (rb:s boy-boyuna) " (üst)")
                   yh 0.0 "REBAR-TEXT")
          (rb:yazi (/ Ln 2.0) (/ hk 2.0)
                   (strcat "Etr. %%c" (itoa cape) "/" (rb:s su) "/" (rb:s so)
                           "  (" (itoa n-etr) " ad.)")
                   (* 0.8 yh) 0.0 "REBAR-TEXT")
          (rb:olcu (list 0.0 0.0) (list Ln 0.0) (- (* 4.0 yh)) yh)
          (rb:olcu (list 0.0 hk) (list 0.0 0.0) (- (* 2.0 yh)) yh)
          (rb:olcu (list 0.0 hk) (list lu hk) (* 3.5 yh) yh)
          ;; Kesit (görünüşün sağında)
          (setq kx (+ Ln (max (* 2.0 bw) (* 10.0 yh))))
          (rb:dikdortgen kx 0.0 bw hk "REBAR-BEAM" nil)
          (rb:dikdortgen (+ kx ae) ae (- bw (* 2.0 ae)) (- hk (* 2.0 ae)) "REBAR-BEAM-ETRIYE" (rb:renk cape))
          (foreach x (rb:esit (+ kx a-alt) (- (+ kx bw) a-alt) n-alt)
            (rb:cubuk x a-alt cap-alt "REBAR-BEAM-BOT"))
          (foreach x (rb:esit (+ kx a-ust) (- (+ kx bw) a-ust) n-ust)
            (rb:cubuk x (- hk a-ust) cap-ust "REBAR-BEAM-TOP"))
          (rb:yazi (+ kx (/ bw 2.0)) (+ hk (* 1.5 yh)) "KESİT" (* 1.2 yh) 0.0 "REBAR-TEXT")
          (rb:yazi (+ kx (/ bw 2.0)) (- (* 1.5 yh))
                   (strcat (rb:s bw) "/" (rb:s hk)) yh 0.0 "REBAR-TEXT")
          ;; Metraj
          (setq satirlar (list (rb:satir "1" "Alt" cap-alt n-alt boy-boyuna)
                               (rb:satir "2" "Üst" cap-ust n-ust boy-boyuna)
                               (rb:satir "3" "Etriye" cape n-etr boy-etr)))
          (princ "\nNot: Mesnet ek donatısı, kanca/bindirme boyları ayrıca değerlendirilmelidir.")
          (rb:metraj-sonu satirlar (rb:lp 0.0 (- (* 8.0 yh))) yh)
          (rb:uyari-ozeti)))))
  (princ))

;; ============================================
;; KOMUTLAR
;; ============================================

(defun c:REBAR-BEAM () (rb:komut "REBAR-Kiriş: Kiriş Donatısı" 'rb:kiris-govde))
(defun c:RB () (c:REBAR-BEAM))
(defun c:KIRIS () (c:REBAR-BEAM))

(princ "\nREBAR-Kiris v2.0 yüklendi. Komutlar: REBAR-BEAM / RB / KIRIS")
(princ)
