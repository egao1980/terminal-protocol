(in-package #:terminal-protocol/tests)

;;; A toy backend. Bytes are stored, not parsed, except a few control bytes
;;; that fire effects:
;;;   #x07 → bell   #x05 (ENQ) → reply "OK"   #x01 → title "t"
;;;   #x02 → feed the same terminal from inside the host (reentrancy probe)

(defclass mock-backend (tp:terminal-backend) ())

(defclass mock-terminal (tp:terminal)
  ((cols :initarg :cols :accessor mock-cols)
   (rows :initarg :rows :accessor mock-rows)
   (fed :initform '() :accessor mock-fed)
   (title :initform nil :accessor mock-title)
   (modes :initform (make-hash-table :test #'equal) :reader mock-modes)
   (closes :initform 0 :accessor mock-closes)))

(defmethod tp:backend-supports-p ((b mock-backend) feature)
  (eq feature :scrollback))

(defmethod tp:backend-make-terminal ((b mock-backend) &key cols rows host
                                     &allow-other-keys)
  (make-instance 'mock-terminal :backend b :host host :cols cols :rows rows))

(defmethod tp:terminal-feed ((term mock-terminal) octets &key (start 0) end)
  (loop for i from start below (or end (length octets))
        for octet = (aref octets i)
        do (push octet (mock-fed term))
           (case octet
             (#x07 (tp:call-host term #'tp:host-bell))
             (#x05 (tp:call-host term #'tp:host-write-pty
                                 (map '(vector (unsigned-byte 8)) #'char-code "OK")))
             (#x01 (setf (mock-title term) "t")
              (tp:call-host term #'tp:host-title-changed "t"))
             (#x02 (tp:call-host term (lambda (host term)
                                        (declare (ignore host))
                                        (tp:terminal-feed term (octets "x"))))))))

(defmethod tp:terminal-close ((term mock-terminal))
  (incf (mock-closes term)))

(defmethod tp:terminal-size ((term mock-terminal))
  (values (mock-cols term) (mock-rows term)))

(defmethod tp:terminal-resize ((term mock-terminal) cols rows &key cell-width-px
                               cell-height-px)
  (declare (ignore cell-width-px cell-height-px))
  (setf (mock-cols term) cols (mock-rows term) rows))

(defmethod tp:terminal-title ((term mock-terminal)) (mock-title term))
(defmethod tp:terminal-pwd ((term mock-terminal)) nil)
(defmethod tp:terminal-active-screen ((term mock-terminal)) :primary)

(defmethod tp:backend-mode ((term mock-terminal) kind number)
  (gethash (list kind number) (mock-modes term)))

(defmethod (setf tp:backend-mode) (value (term mock-terminal) kind number)
  (setf (gethash (list kind number) (mock-modes term)) value))

(defmethod tp:terminal-text ((term mock-terminal) &key (format :plain) region)
  (declare (ignore region))
  (format nil "~(~A~):~A" format (length (mock-fed term))))

(defmethod tp:encode-key ((term mock-terminal) key &key text modifiers action)
  (list key text modifiers action))

(defmethod tp:encode-mouse ((term mock-terminal) button action x y
                            &key modifiers pixel-x pixel-y)
  (declare (ignore pixel-x pixel-y))
  (list button action x y modifiers))

;;; Frame: row y holds one cell whose text is the row number; row 1 is clean.

(defclass mock-frame (tp:frame)
  ((closed :initform nil :accessor mock-frame-closed)))

(defmethod tp:make-frame ((term mock-terminal))
  (make-instance 'mock-frame :terminal term))

(defmethod tp:frame-update ((frame mock-frame)) :full)

(defmethod tp:frame-size ((frame mock-frame))
  (tp:terminal-size (tp:frame-terminal frame)))

(defmethod tp:frame-cursor ((frame mock-frame)) (tp:make-cursor :x 1 :y 0))

(defmethod tp:frame-row ((frame mock-frame) y)
  (let ((cols (tp:terminal-size (tp:frame-terminal frame))))
    (make-instance 'tp:row
                   :y y :dirty-p (/= y 1)
                   :cells (let ((cells (make-array cols)))
                            (dotimes (x cols cells)
                              (setf (aref cells x)
                                    (if (zerop x)
                                        (tp:make-cell :text (princ-to-string y))
                                        (tp:make-cell))))))))

(defmethod tp:frame-close ((frame mock-frame))
  (setf (mock-frame-closed frame) t))

(defun octets (string)
  (map '(vector (unsigned-byte 8)) #'char-code string))

(defmacro with-mock ((var &rest keys) &body body)
  `(let ((tp:*terminal-backend* (make-instance 'mock-backend)))
     (tp:with-terminal (,var ,@keys) ,@body)))

(defclass recording-host (tp:terminal-host)
  ((events :initform '() :accessor host-events)))

(defmethod tp:host-bell ((host recording-host) term)
  (declare (ignore term))
  (push :bell (host-events host)))

(defmethod tp:host-title-changed ((host recording-host) term title)
  (declare (ignore term))
  (push (list :title title) (host-events host)))

(defclass failing-host (recording-host) ())

(defmethod tp:host-bell ((host failing-host) term)
  (declare (ignore term))
  (error "bell broke"))
