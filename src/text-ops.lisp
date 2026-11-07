(in-package #:terminal-protocol)

;;; Search and selection over the viewport, written once on top of frames,
;;; so every backend gets them. Coordinates are cells: X columns, Y rows,
;;; both from 0. Wide characters count as two columns, as on screen.

(defstruct (terminal-match (:constructor make-terminal-match (x y end)))
  "A search hit on row Y covering columns [X, END)."
  (x 0 :type (integer 0) :read-only t)
  (y 0 :type (integer 0) :read-only t)
  (end 0 :type (integer 0) :read-only t))

(defun %row-text-and-columns (cells)
  "→ (values text columns), where (aref columns i) is the column of the
I-th character of TEXT. Spacer cells contribute nothing; empty cells a space."
  (let ((text (make-string-output-stream))
        (columns (make-array 0 :adjustable t :fill-pointer 0)))
    (loop for cell across cells
          for x from 0
          unless (eq (cell-width cell) :spacer)
            do (let ((s (if (string= (cell-text cell) "") " " (cell-text cell))))
                 (loop for ch across s
                       do (write-char ch text)
                          (vector-push-extend x columns))))
    (values (get-output-stream-string text) columns)))

(defun %cell-end (cells x)
  "Column just past cell X (two columns for a wide cell)."
  (if (eq (cell-width (aref cells x)) :wide) (+ x 2) (1+ x)))

(defgeneric terminal-search (terminal pattern &key case-sensitive)
  (:documentation "→ a list of TERMINAL-MATCH for every occurrence of the
string PATTERN in the viewport, top to bottom, left to right. Matches do
not span rows. CASE-SENSITIVE defaults to T.")
  (:method ((terminal terminal) pattern &key (case-sensitive t))
    (check-type pattern string)
    (when (string= pattern "")
      (return-from terminal-search '()))
    (let ((test (if case-sensitive #'char= #'char-equal))
          (out '()))
      (with-frame (frame terminal)
        (multiple-value-bind (cols rows) (frame-size frame)
          (declare (ignore cols))
          (dotimes (y rows)
            (let ((cells (row-cells (frame-row frame y))))
              (multiple-value-bind (text columns) (%row-text-and-columns cells)
                (loop for start = 0 then (1+ hit)
                      for hit = (search pattern text :start2 start :test test)
                      while hit
                      do (let ((last (+ hit (length pattern) -1)))
                           (push (make-terminal-match (aref columns hit) y
                                                      (%cell-end cells (aref columns last)))
                                 out))))))))
      (nreverse out))))

(defgeneric terminal-selection-text (terminal start-x start-y end-x end-y &key rectangular)
  (:documentation "→ the text of the viewport cells from (START-X, START-Y) to
(END-X, END-Y), both inclusive, as a terminal copies a mouse selection.
Linear selections run to the end of each row in between; RECTANGULAR
takes columns START-X..END-X of every row. Rows are joined with newlines
and their trailing blanks trimmed. The corners may be given in either order.")
  (:method ((terminal terminal) start-x start-y end-x end-y &key rectangular)
    (dolist (v (list start-x start-y end-x end-y))
      (check-type v (integer 0)))
    (when (or (> start-y end-y) (and (= start-y end-y) (> start-x end-x)))
      (rotatef start-x end-x)
      (rotatef start-y end-y))
    (when (and rectangular (> start-x end-x))
      (rotatef start-x end-x))
    (with-frame (frame terminal)
      (multiple-value-bind (cols rows) (frame-size frame)
        (flet ((row-slice (y from to)
                 (let ((cells (row-cells (frame-row frame y))))
                   (string-right-trim
                    " "
                    (with-output-to-string (s)
                      (loop for x from (max 0 from) to (min to (1- cols))
                            for cell = (aref cells x)
                            unless (eq (cell-width cell) :spacer)
                              do (write-string (if (string= (cell-text cell) "")
                                                   " " (cell-text cell))
                                               s)))))))
          (format nil "~{~A~^~%~}"
                  (loop for y from start-y to (min end-y (1- rows))
                        collect (cond (rectangular (row-slice y start-x end-x))
                                      ((= start-y end-y) (row-slice y start-x end-x))
                                      ((= y start-y) (row-slice y start-x (1- cols)))
                                      ((= y end-y) (row-slice y 0 end-x))
                                      (t (row-slice y 0 (1- cols)))))))))))
