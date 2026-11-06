;;
;; REBAR-Ana.lsp
;; ============================================
;; AutoCAD LISP - REBAR Donatı Yerleştirme Serisi
;; Ana Yükleyici ve Menü
;; ============================================
;; Sürüm: 2.0
;;
;; Bu dosya yüklendiğinde sırasıyla şunları yükler:
;;   REBAR-Ortak.lsp  : ortak kütüphane (veri, çizim, kontrol, metraj)
;;   REBAR-Temel.lsp  : temel donatısı
;;   REBAR-Kolon.lsp  : kolon ve perde donatısı
;;   REBAR-Kiris.lsp  : kiriş donatısı
;;   REBAR-Doseme.lsp : döşeme donatısı
;;
;; Dosyaların bulunduğu klasör AutoCAD destek dosyası arama yollarına
;; (OPTIONS > Files > Support File Search Path) eklenmiş olmalıdır.
;;

(vl-load-com)

(defun rb:modul-yukle (dosya / yol)
  (if (setq yol (findfile dosya))
    (progn (load yol) T)
    (progn (princ (strcat "\nUYARI: " dosya " bulunamadı (destek yollarını kontrol edin).")) nil)))

(princ "\n=== REBAR Serisi v2.0 yükleniyor ===")
(setq *rb:ortak-yuklendi* nil)          ; ortak kütüphaneyi her yüklemede tazele
(rb:modul-yukle "REBAR-Ortak.lsp")
(if *rb:ortak-yuklendi*
  (foreach m '("REBAR-Temel.lsp" "REBAR-Kolon.lsp" "REBAR-Kiris.lsp" "REBAR-Doseme.lsp")
    (rb:modul-yukle m))
  (alert "REBAR-Ortak.lsp yüklenemedi! Modüller yüklenmedi."))

;; ============================================
;; ANA MENÜ
;; ============================================

(defun c:REBAR ( / secim)
  (princ "\n=== REBAR ANA MENÜ - Donatı Yerleştirme (TS 500) ===")
  (initget "Temel Kolon Perde kIris Doseme Ayar")
  (setq secim (getkword "\nEleman seçiniz [Temel/Kolon/Perde/kIris/Doseme/Ayar] <Temel>: "))
  (if (null secim) (setq secim "Temel"))
  (cond
    ((and (= secim "Temel")  c:REBAR-FOOTING) (c:REBAR-FOOTING))
    ((and (= secim "Kolon")  c:REBAR-COLUMN)  (c:REBAR-COLUMN))
    ((and (= secim "Perde")  c:REBAR-WALL)    (c:REBAR-WALL))
    ((and (= secim "kIris")  c:REBAR-BEAM)    (c:REBAR-BEAM))
    ((and (= secim "Doseme") c:REBAR-SLAB)    (c:REBAR-SLAB))
    ((and (= secim "Ayar")   c:REBAR-AYAR)    (c:REBAR-AYAR))
    (T (princ (strcat "\n" secim " modülü yüklü değil."))))
  (princ))

(defun c:REBAR-MENU () (c:REBAR))

(princ "\n=== REBAR Serisi v2.0 yüklendi ===")
(princ "\n  REBAR                - Ana menü")
(princ "\n  RT  / TEMEL          - Temel donatısı")
(princ "\n  RK  / KOLON          - Kolon donatısı")
(princ "\n  RP  / PERDE          - Perde donatısı")
(princ "\n  RB  / KIRIS          - Kiriş donatısı")
(princ "\n  RD  / DOSEME         - Döşeme donatısı")
(princ "\n  REBAR-AYAR           - Beton/çelik sınıfı, yazı yüksekliği")
(princ "\n========================================\n")
(princ)
