(in-package #:terminal-protocol/tests)

;;; A fixed grid: each row is a string; "W" followed by a character marks a
;;; wide cell (the character, then a spacer).

(defclass grid-terminal (tp:terminal)
  ((rows :initarg :rows :reader grid-rows)
   (cols :initarg :cols :reader grid-cols)))

(defclass grid-frame (tp:frame) ())

(defun grid-cells (line cols)
  (let ((cells (make-array cols :initial-element nil)) (x 0) (i 0))
    (loop while (and (< i (length line)) (< x cols))
          do (if (char= (char line i) #\W)
                 (progn (setf (aref cells x) (tp:make-cell :text (string (char line (1+ i)))
                                                           :width :wide)
                              (aref cells (1+ x)) (tp:make-cell :width :spacer))
                        (incf x 2) (incf i 2))
                 (progn (setf (aref cells x)
                              (if (char= (char line i) #\Space)
                                  (tp:make-cell)
                                  (tp:make-cell :text (string (char line i)))))
                        (incf x) (incf i))))
    (dotimes (j cols cells) (unless (aref cells j) (setf (aref cells j) (tp:make-cell))))))

(defmethod tp:make-frame ((term grid-terminal)) (make-instance 'grid-frame :terminal term))
(defmethod tp:frame-update ((frame grid-frame)) :full)
(defmethod tp:frame-size ((frame grid-frame))
  (let ((term (tp:frame-terminal frame)))
    (values (grid-cols term) (length (grid-rows term)))))
(defmethod tp:frame-row ((frame grid-frame) y)
  (let ((term (tp:frame-terminal frame)))
    (make-instance 'tp:row :y y :cells (grid-cells (nth y (grid-rows term)) (grid-cols term)))))

(defun grid (cols &rest rows)
  (make-instance 'grid-terminal :backend nil :host nil :cols cols :rows rows))

(defun hits (matches)
  (mapcar (lambda (m) (list (tp:terminal-match-x m) (tp:terminal-match-y m)
                            (tp:terminal-match-end m)))
          matches))

(deftest search-finds-every-hit
  (let ((term (grid 12 "foo bar foo" "xfoo" "")))
    (ok (equal (hits (tp:terminal-search term "foo")) '((0 0 3) (8 0 11) (1 1 4))))
    (ok (null (tp:terminal-search term "zzz")))
    (ok (null (tp:terminal-search term "")))))

(deftest search-case-and-overlap
  (let ((term (grid 10 "Aaa")))
    (ok (equal (hits (tp:terminal-search term "aa")) '((1 0 3))))
    (ok (equal (hits (tp:terminal-search term "aa" :case-sensitive nil)) '((0 0 2) (1 0 3))))))

(deftest search-reports-columns-for-wide-cells
  ;; "日本x": 日 at 0-1, 本 at 2-3, x at 4.
  (let ((term (grid 8 "W日W本x")))
    (ok (equal (hits (tp:terminal-search term "本x")) '((2 0 5))))
    (ok (equal (hits (tp:terminal-search term "日")) '((0 0 2))))))

(deftest selection-linear
  (let ((term (grid 6 "abcdef" "ghij" "klmnop")))
    (ok (equal (tp:terminal-selection-text term 2 0 3 0) "cd"))
    (ok (equal (tp:terminal-selection-text term 4 0 1 2) (format nil "ef~%ghij~%kl")))
    ;; Corners in either order.
    (ok (equal (tp:terminal-selection-text term 1 2 4 0) (format nil "ef~%ghij~%kl")))))

(deftest selection-rectangular
  (let ((term (grid 6 "abcdef" "ghij" "klmnop")))
    (ok (equal (tp:terminal-selection-text term 1 0 2 2 :rectangular t)
               (format nil "bc~%hi~%lm")))
    (ok (equal (tp:terminal-selection-text term 2 2 1 0 :rectangular t)
               (format nil "bc~%hi~%lm")))))

(deftest selection-skips-spacers-and-trims
  (let ((term (grid 8 "W日x    " "")))
    (ok (equal (tp:terminal-selection-text term 0 0 7 0) "日x"))
    (ok (equal (tp:terminal-selection-text term 0 0 7 1) (format nil "日x~%")))))
