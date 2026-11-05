;;
;; ACAD.LSP - AutoCAD Otomatik Yükleme Dosyası
;; ============================================
;; Bu dosya, AutoCAD başladığında REBAR modüllerini otomatik yükler
;; ============================================
;;

;; REBAR serisini yükle
(if (findfile "REBAR-Ana.lsp")
  (load "REBAR-Ana.lsp")
  (progn
    ;; Eğer REBAR-Ana.lsp bulunamazsa, tek tek yükle
    (if (findfile "REBAR-Temel.lsp") (load "REBAR-Temel.lsp"))
    (if (findfile "REBAR-Kolon.lsp") (load "REBAR-Kolon.lsp"))
    (if (findfile "REBAR-Kiris.lsp") (load "REBAR-Kiris.lsp"))
    (if (findfile "REBAR-Doseme.lsp") (load "REBAR-Doseme.lsp"))
  )
)

;; ACAD.LSP mesajı
(princ "\nACAD.LSP: REBAR modülleri yüklendi. 'REBAR' komutunu kullanın.\n")
(princ)
