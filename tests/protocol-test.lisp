(in-package #:terminal-protocol/tests)

(deftest no-backend-signals
  (let ((tp:*terminal-backend* nil))
    (ok (signals (tp:make-terminal) 'tp:terminal-no-backend))))

(deftest make-terminal-defaults
  (with-mock (term)
    (ok (equal (multiple-value-list (tp:terminal-size term)) '(80 24)))
    (ok (typep (tp:terminal-host-of term) 'tp:buffering-host))
    (ok (typep (tp:terminal-backend-of term) 'mock-backend))))

(deftest make-terminal-validates-size
  (let ((tp:*terminal-backend* (make-instance 'mock-backend)))
    (ok (signals (tp:make-terminal :cols 0) 'tp:terminal-invalid-argument))
    (let ((term (handler-bind ((tp:terminal-invalid-argument
                                 (lambda (c) (use-value 40 c))))
                  (tp:make-terminal :cols -3 :rows 10))))
      (ok (equal (multiple-value-list (tp:terminal-size term)) '(40 10))))))

(deftest close-is-idempotent-and-guards
  (let* ((tp:*terminal-backend* (make-instance 'mock-backend))
         (term (tp:make-terminal)))
    (tp:terminal-close term)
    (tp:terminal-close term)
    (ok (= 1 (mock-closes term)))
    (ok (tp:terminal-closed-p term))
    (ok (signals (tp:terminal-feed term (octets "a")) 'tp:terminal-closed-error))
    (ok (signals (tp:terminal-size term) 'tp:terminal-closed-error))
    (ok (signals (tp:encode-key term :a) 'tp:terminal-closed-error))
    (ok (signals (tp:encode-mouse term :left :press 0 0) 'tp:terminal-closed-error))
    (ok (signals (tp:make-frame term) 'tp:terminal-closed-error))))

(deftest with-terminal-closes-on-unwind
  (let ((tp:*terminal-backend* (make-instance 'mock-backend))
        (seen nil))
    (ignore-errors
     (tp:with-terminal (term)
       (setf seen term)
       (error "boom")))
    (ok (tp:terminal-closed-p seen))))

(deftest feed-checks-arguments
  (with-mock (term)
    (ok (signals (tp:terminal-feed term "abc") 'type-error))
    (ok (signals (tp:terminal-feed term (octets "abc") :start 2 :end 1)
                 'tp:terminal-invalid-argument))
    (tp:terminal-feed term (octets "abcd") :start 1 :end 3)
    (ok (equal (reverse (mock-fed term)) (coerce (octets "bc") 'list)))))

(deftest modes-round-trip
  (with-mock (term)
    (ng (tp:terminal-mode term :bracketed-paste))
    (setf (tp:terminal-mode term :bracketed-paste) :yes)
    (ok (eq t (tp:terminal-mode term '(:dec 2004))))))

(deftest resize-validates
  (with-mock (term)
    (tp:terminal-resize term 100 30)
    (ok (equal (multiple-value-list (tp:terminal-size term)) '(100 30)))
    (ok (signals (tp:terminal-resize term 0 30) 'tp:terminal-invalid-argument))))

(deftest text-validates-format
  (with-mock (term)
    (ok (equal (tp:terminal-text term) "plain:0"))
    (ok (signals (tp:terminal-text term :format :pdf) 'tp:terminal-invalid-argument))
    (ok (signals (tp:terminal-text term :region :all) 'tp:terminal-invalid-argument))))

(deftest encode-key-normalises
  (with-mock (term)
    (ok (equal (tp:encode-key term :a :text "a") '(:a "a" nil :press)))
    (ok (equal (tp:encode-key term :enter :modifiers '(:ctrl) :action :release)
               '(:enter nil (:ctrl) :release)))
    (ok (signals (tp:encode-key term :up) 'tp:terminal-invalid-argument))
    (ok (signals (tp:encode-key term :a :modifiers '(:hyper))
                 'tp:terminal-invalid-argument))
    (ok (signals (tp:encode-key term :a :action :hold) 'tp:terminal-invalid-argument))
    (ok (equal (handler-bind ((tp:terminal-invalid-argument
                                (lambda (c) (use-value :arrow-up c))))
                 (tp:encode-key term :up))
               '(:arrow-up nil nil :press)))))

(deftest encode-mouse-validates
  (with-mock (term)
    (ok (equal (tp:encode-mouse term :left :press 3 4) '(:left :press 3 4 nil)))
    (ok (equal (tp:encode-mouse term nil :motion 0 0) '(nil :motion 0 0 nil)))
    (ok (signals (tp:encode-mouse term :thumb :press 0 0) 'tp:terminal-invalid-argument))
    (ok (signals (tp:encode-mouse term :left :press -1 0) 'tp:terminal-invalid-argument))))

(deftest frames-and-snapshot
  (with-mock (term :cols 3 :rows 3)
    (let ((ys '()))
      (tp:with-frame (frame term)
        (tp:do-frame-rows (row frame :dirty-only t)
          (push (tp:row-y row) ys)))
      (ok (equal (nreverse ys) '(0 2))))
    (let ((snap (tp:terminal-snapshot term)))
      (ok (equal (getf snap :lines) '("0" "1" "2")))
      (ok (= 3 (getf snap :cols)))
      (ok (equalp (getf snap :cursor) (tp:make-cursor :x 1 :y 0)))
      (ok (= 3 (length (aref (getf snap :cells) 0)))))
    (ng (getf (tp:terminal-snapshot term :cells nil) :cells))))

(deftest with-frame-closes
  (with-mock (term)
    (let ((seen nil))
      (tp:with-frame (frame term) (setf seen frame))
      (ok (mock-frame-closed seen)))))
