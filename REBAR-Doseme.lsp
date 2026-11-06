;;
;; REBAR-Doseme.lsp
;; ============================================
;; AutoCAD LISP - Döşeme (Plak) Donatı Yerleştirme
;; Türkiye Standartlarına Göre (TS 500)
;; ============================================
;; Sürüm: 2.0
;; Gerekli: REBAR-Ortak.lsp
;;
;; Çizim: PLAN görünüşü. Alt donatı düz, üst donatı kesikli çizgi.
;; Döşeme tipleri:
;;   Cift : çift doğrultulu plak (iki doğrultuda ana donatı)
;;   Tek  : tek doğrultulu plak (kısa doğrultuda ana donatı + dağıtma donatısı)
;;

(if (not *rb:ortak-yuklendi*)
  (if (findfile "REBAR-Ortak.lsp")
    (load "REBAR-Ortak.lsp")
    (alert "REBAR-Ortak.lsp bulunamadı!\nDosyayı REBAR-Doseme.lsp ile aynı klasöre koyun\nve klasörü AutoCAD destek yollarına ekleyin.")))

;; ============================================
;; ÇİZİM
;; ============================================

;; Bir doğrultudaki çubukları çizer, metraj satırı döndürür.
;; yon: "X" (X'e paralel çubuklar, Y boyunca dizilir) veya "Y"
(defun rb:doseme-cubuklar (yon Lx Ly c ca katman etiket konum-orani poz yh
                           / cap s r konumlar boy n k)
  (setq cap (car ca) s (cadr ca) r (/ cap 20.0))
  (if (= yon "X")
    (setq konumlar (rb:diz (+ c r) (- Ly (* 2.0 (+ c r))) s) boy (- Lx (* 2.0 c)))
    (setq konumlar (rb:diz (+ c r) (- Lx (* 2.0 (+ c r))) s) boy (- Ly (* 2.0 c))))
  (setq n (length konumlar))
  (foreach v konumlar
    (if (= yon "X")
      (rb:cizgi (list c v) (list (- Lx c) v) katman (rb:renk cap))
      (rb:cizgi (list v c) (list v (- Ly c)) katman (rb:renk cap))))
  (if konumlar
    (progn
      (setq k (nth (fix (* konum-orani (1- n))) konumlar))
      (if (= yon "X")
        (rb:yazi (/ Lx 2.0) (+ k (* 0.8 yh))
                 (strcat etiket ": " (itoa n) "%%c" (itoa cap) "/" (rb:s s) " L=" (rb:s boy))
                 yh 0.0 "REBAR-TEXT")
        (rb:yazi (- k (* 0.8 yh)) (/ Ly 2.0)
                 (strcat etiket ": " (itoa n) "%%c" (itoa cap) "/" (rb:s s) " L=" (rb:s boy))
                 yh (/ pi 2.0) "REBAR-TEXT"))))
  (rb:satir poz etiket cap n boy))

;; ============================================
;; ANA GÖVDE
;; ============================================

(defun rb:doseme-govde ( / tip p0 Lx Ly hf c kisa uzun oran ana-yon xa ya ust xu yu
                          rmin smax-kisa smax-uzun yh satirlar as-ana as-dag)
  (rb:katmanlari-hazirla
    '("REBAR-SLAB" "REBAR-SLAB-BOT" "REBAR-SLAB-TOP" "REBAR-TEXT" "REBAR-DIM" "REBAR-TABLE"))
  (setq tip (rb:secenek-al "Döşeme tipi" "Cift Tek" "Cift"))
  (setq p0 (getpoint "\nDöşeme sol-alt köşe noktasını seçiniz: "))
  (if (null p0)
    (princ "\nNokta seçilmedi, iptal edildi.")
    (progn
      (setq Lx (rb:sayi-al "Döşeme boyutu - X yönü (cm)" 500.0)
            Ly (rb:sayi-al "Döşeme boyutu - Y yönü (cm)" 600.0)
            hf (rb:sayi-al "Döşeme kalınlığı (cm)" 15.0)
            c  (rb:sayi-al "Paspayı (cm)" 2.0)
            kisa (min Lx Ly) uzun (max Lx Ly) oran (/ uzun kisa)
            ana-yon (if (<= Lx Ly) "X" "Y"))    ; ana donatı kısa açıklık doğrultusunda
      (princ (strcat "\nUzun/kısa kenar oranı: " (rb:s2 oran)
                     (if (> oran 2.0) "  -> tek doğrultulu çalışır" "  -> çift doğrultulu çalışır")))
      (princ "\n--- Alt Donatı ---")
      (if (= tip "Cift")
        (setq xa (rb:cap-aralik-al "Alt X donatısı" 10 15.0)
              ya (rb:cap-aralik-al "Alt Y donatısı" 10 15.0))
        (progn
          (princ (strcat "\nAna donatı kısa açıklık doğrultusunda (" ana-yon ") yerleştirilir."))
          (if (= ana-yon "X")
            (setq xa (rb:cap-aralik-al "Ana donatı (X)" 10 15.0)
                  ya (rb:cap-aralik-al "Dağıtma donatısı (Y)" 8 30.0))
            (setq ya (rb:cap-aralik-al "Ana donatı (Y)" 10 15.0)
                  xa (rb:cap-aralik-al "Dağıtma donatısı (X)" 8 30.0)))))
      (setq ust (rb:evet-mi "Üst donatı ağı eklensin mi?" nil))
      (if ust
        (setq xu (rb:cap-aralik-al "Üst X donatısı" 8 20.0)
              yu (rb:cap-aralik-al "Üst Y donatısı" 8 20.0)))
      ;; --- Kontroller ---
      (princ "\n--- TS 500 Kontrolleri ---")
      (setq rmin (rb:rho-min-plak)
            smax-kisa (min (* 1.5 hf) 20.0)
            smax-uzun (min (* 1.5 hf) 25.0))
      (rb:paspayi-kontrol "DOSEME" c (max (car xa) (car ya)))
      (rb:kontrol (>= hf 8.0) (strcat "Döşeme kalınlığı " (rb:s hf) " cm >= 8 cm"))
      (if (and (= tip "Cift") (> oran 2.0))
        (rb:kontrol nil "Uzun/kısa oranı > 2: tek doğrultulu döşeme olarak hesaplanmalı"))
      (if (and (= tip "Tek") (<= oran 2.0))
        (rb:kontrol nil "Uzun/kısa oranı <= 2: çift doğrultulu döşeme olarak hesaplanmalı"))
      (if (= tip "Cift")
        (progn
          (rb:oran-kontrol "X" (/ (rb:alan (car xa)) (* hf (cadr xa))) rmin)
          (rb:oran-kontrol "Y" (/ (rb:alan (car ya)) (* hf (cadr ya))) rmin)
          (rb:max-aralik-kontrol "X donatısı" (cadr xa) (if (= ana-yon "X") smax-kisa smax-uzun))
          (rb:max-aralik-kontrol "Y donatısı" (cadr ya) (if (= ana-yon "Y") smax-kisa smax-uzun)))
        (progn
          (setq as-ana (if (= ana-yon "X") (/ (rb:alan (car xa)) (cadr xa)) (/ (rb:alan (car ya)) (cadr ya)))
                as-dag (if (= ana-yon "X") (/ (rb:alan (car ya)) (cadr ya)) (/ (rb:alan (car xa)) (cadr xa))))
          (rb:oran-kontrol "Ana" (/ as-ana hf) rmin)
          (rb:kontrol (>= as-dag (/ as-ana 5.0)) "Dağıtma donatısı >= ana donatının 1/5'i")
          (rb:max-aralik-kontrol "Ana donatı" (if (= ana-yon "X") (cadr xa) (cadr ya)) smax-kisa)
          (rb:max-aralik-kontrol "Dağıtma donatısı" (if (= ana-yon "X") (cadr ya) (cadr xa)) 30.0)))
      (foreach d (append (list (list "Alt X" xa) (list "Alt Y" ya))
                         (if ust (list (list "Üst X" xu) (list "Üst Y" yu))))
        (rb:net-aralik-kontrol (car d) (cadr (cadr d)) (car (cadr d)) 2.5))
      ;; --- Çizim ---
      (if (rb:evet-mi "Donatı çizilsin mi?" T)
        (progn
          (setq yh (rb:yh uzun))
          (rb:koord (rb:wcs p0) (rb:ucs-aci))
          (rb:dikdortgen 0.0 0.0 Lx Ly "REBAR-SLAB" nil)
          (setq satirlar
                (list (rb:doseme-cubuklar "X" Lx Ly c xa "REBAR-SLAB-BOT" "Alt X" 0.25 "1" yh)
                      (rb:doseme-cubuklar "Y" Lx Ly c ya "REBAR-SLAB-BOT" "Alt Y" 0.25 "2" yh)))
          (if ust
            (setq satirlar
                  (append satirlar
                          (list (rb:doseme-cubuklar "X" Lx Ly c xu "REBAR-SLAB-TOP" "Üst X" 0.75 "3" yh)
                                (rb:doseme-cubuklar "Y" Lx Ly c yu "REBAR-SLAB-TOP" "Üst Y" 0.75 "4" yh)))))
          (rb:yazi (/ Lx 2.0) (- (* 6.0 yh))
                   (strcat (if (= tip "Cift") "ÇİFT DOĞRULTULU" "TEK DOĞRULTULU")
                           " DÖŞEME " (rb:s Lx) "x" (rb:s Ly) " h=" (rb:s hf))
                   (* 1.2 yh) 0.0 "REBAR-TEXT")
          (rb:olcu (list 0.0 0.0) (list Lx 0.0) (- (* 3.0 yh)) yh)
          (rb:olcu (list Lx 0.0) (list Lx Ly) (- (* 3.0 yh)) yh)
          (rb:metraj-sonu satirlar (rb:lp (+ Lx (* 8.0 yh)) Ly) yh)
          (rb:uyari-ozeti)))))
  (princ))

;; ============================================
;; KOMUTLAR
;; ============================================

(defun c:REBAR-SLAB () (rb:komut "REBAR-Döşeme: Döşeme Donatısı" 'rb:doseme-govde))
(defun c:RD () (c:REBAR-SLAB))
(defun c:RS () (c:REBAR-SLAB))
(defun c:DOSEME () (c:REBAR-SLAB))
(defun c:DOSME () (c:REBAR-SLAB))

(princ "\nREBAR-Doseme v2.0 yüklendi. Komutlar: REBAR-SLAB / RD / DOSEME")
(princ)
