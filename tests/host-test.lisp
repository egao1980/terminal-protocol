(in-package #:terminal-protocol/tests)

(deftest buffering-host-collects-replies
  (with-mock (term)
    (tp:terminal-feed term (octets (format nil "a~Cb~C" (code-char 5) (code-char 5))))
    (ok (equalp (tp:terminal-take-replies term) (octets "OKOK")))
    (ok (equalp (tp:terminal-take-replies term) (octets "")))))

(deftest effects-reach-host
  (let ((host (make-instance 'recording-host)))
    (with-mock (term :host host)
      (tp:terminal-feed term (octets (coerce (list (code-char 7) (code-char 1)) 'string)))
      (ok (equal (reverse (host-events host)) '(:bell (:title "t"))))
      (ok (equal (tp:terminal-title term) "t")))))

(deftest take-replies-needs-buffering-host
  (with-mock (term :host (make-instance 'recording-host))
    (ok (signals (tp:terminal-take-replies term) 'tp:terminal-unsupported))))

(deftest host-error-resignalled-after-feed
  (let ((host (make-instance 'failing-host)))
    (with-mock (term :host host)
      (let ((condition (handler-case
                           (tp:terminal-feed term (octets (coerce (list (code-char 7) (code-char 1)) 'string)))
                         (tp:terminal-host-error (c) c))))
        (ok (typep condition 'tp:terminal-host-error))
        (ok (search "bell broke" (princ-to-string (tp:terminal-host-error-cause condition))))
        ;; The feed ran to completion: the title effect after the bell still fired.
        (ok (equal (host-events host) '((:title "t"))))))))

(deftest host-error-continue-restart
  (with-mock (term :host (make-instance 'failing-host))
    (ok (null (handler-bind ((tp:terminal-host-error
                               (lambda (c) (continue c))))
                (tp:terminal-feed term (octets (string (code-char 7)))))))))

(deftest reentrant-feed-is-refused
  (with-mock (term)
    (let ((condition (handler-case (tp:terminal-feed term (octets (string (code-char 2))))
                       (tp:terminal-host-error (c) c))))
      (ok (typep (tp:terminal-host-error-cause condition) 'tp:terminal-reentrant-feed))
      ;; The inner "x" was never fed.
      (ok (equal (mock-fed term) (list 2))))))

(defclass forwarding-host (tp:terminal-host)
  ((target :initarg :target :reader forwarding-target)))

(defmethod tp:host-bell ((host forwarding-host) term)
  (declare (ignore term))
  (tp:terminal-feed (forwarding-target host) (octets "fwd")))

(deftest feeding-another-terminal-from-host-is-fine
  (let ((tp:*terminal-backend* (make-instance 'mock-backend)))
    (tp:with-terminal (other)
      (tp:with-terminal (term :host (make-instance 'forwarding-host :target other))
        (tp:terminal-feed term (octets (string (code-char 7))))
        (ok (= 3 (length (mock-fed other))))))))

(deftest call-host-outside-feed-propagates
  (with-mock (term :host (make-instance 'failing-host))
    (ok (signals (tp:call-host term #'tp:host-bell) 'simple-error))))
