(in-package #:terminal-protocol)

;;; A backend-neutral snapshot built only from protocol calls. Parity suites
;;; compare these with EQUALP.

(defun %row-line (cells)
  (let ((line (with-output-to-string (out)
                (loop for cell across cells
                      unless (eq (cell-width cell) :spacer)
                        do (let ((text (cell-text cell)))
                             (write-string (if (string= text "") " " text) out))))))
    (string-right-trim " " line)))

(defun terminal-snapshot (terminal &key (cells t))
  "→ a plist describing TERMINAL's viewport:
 :COLS :ROWS :CURSOR :TITLE :PWD :SCREEN :LINES and, when CELLS is true, :CELLS.
:LINES is one string per row with trailing blanks trimmed. :CELLS is a vector
of CELL vectors."
  (with-frame (frame terminal)
    (multiple-value-bind (cols rows) (frame-size frame)
      (let ((row-cells (make-array rows))
            (lines (make-array rows)))
        (dotimes (y rows)
          (let ((cs (row-cells (frame-row frame y))))
            (setf (aref row-cells y) (coerce cs 'simple-vector)
                  (aref lines y) (%row-line cs))))
        (append (list :cols cols
                      :rows rows
                      :cursor (frame-cursor frame)
                      :title (terminal-title terminal)
                      :pwd (terminal-pwd terminal)
                      :screen (terminal-active-screen terminal)
                      :lines (coerce lines 'list))
                (when cells
                  (list :cells row-cells)))))))
