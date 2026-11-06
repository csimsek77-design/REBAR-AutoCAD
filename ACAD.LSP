;;
;; ACAD.LSP - REBAR otomatik yükleme örneği
;; ============================================
;; Bu satırları kendi acaddoc.lsp dosyanıza eklemeniz önerilir
;; (acaddoc.lsp her çizim açıldığında yüklenir; ACAD.LSP ise varsayılan
;; olarak AutoCAD oturumu başında yalnızca bir kez yüklenir).
;; Mevcut bir ACAD.LSP / acaddoc.lsp dosyanız varsa ÜZERİNE YAZMAYIN,
;; aşağıdaki satırları ekleyin.
;; ============================================

(if (findfile "REBAR-Ana.lsp")
  (load "REBAR-Ana.lsp")
  (princ "\nREBAR-Ana.lsp bulunamadı: klasörü destek yollarına ekleyin."))
(princ)
