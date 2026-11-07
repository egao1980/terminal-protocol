(in-package #:terminal-protocol)

(define-condition terminal-error (error)
  ((terminal :initarg :terminal :initform nil :reader terminal-error-terminal))
  (:report (lambda (c s)
             (format s "Terminal error~@[ on ~A~]" (terminal-error-terminal c)))))

(define-condition terminal-closed-error (terminal-error) ()
  (:report (lambda (c s)
             (format s "Terminal ~A is closed" (terminal-error-terminal c)))))

(define-condition terminal-unsupported (terminal-error)
  ((feature :initarg :feature :reader terminal-unsupported-feature))
  (:report (lambda (c s)
             (format s "Terminal backend does not support ~S"
                     (terminal-unsupported-feature c)))))

(define-condition terminal-invalid-argument (terminal-error)
  ((name :initarg :name :reader terminal-invalid-argument-name)
   (value :initarg :value :reader terminal-invalid-argument-value))
  (:report (lambda (c s)
             (format s "Invalid terminal argument ~A: ~S"
                     (terminal-invalid-argument-name c)
                     (terminal-invalid-argument-value c)))))

(define-condition terminal-out-of-memory (terminal-error storage-condition) ()
  (:report (lambda (c s)
             (format s "Terminal backend ran out of memory~@[ on ~A~]"
                     (terminal-error-terminal c)))))

(define-condition terminal-reentrant-feed (terminal-error) ()
  (:report (lambda (c s)
             (format s "TERMINAL-FEED on ~A called from inside its own host effect"
                     (terminal-error-terminal c)))))

(define-condition terminal-host-error (terminal-error)
  ((cause :initarg :cause :reader terminal-host-error-cause))
  (:report (lambda (c s)
             (format s "Host effect failed on ~A: ~A"
                     (terminal-error-terminal c) (terminal-host-error-cause c)))))

(define-condition terminal-no-backend (terminal-error) ()
  (:report (lambda (c s)
             (declare (ignore c))
             (format s "*TERMINAL-BACKEND* is NIL. Load terminal-backend-ghostty or terminal-backend-lisp."))))

(define-condition terminal-native-unavailable (terminal-error)
  ((library :initarg :library :initform nil :reader terminal-native-unavailable-library)
   (reason :initarg :reason :initform nil :reader terminal-native-unavailable-reason))
  (:report (lambda (c s)
             (format s "Native terminal library~@[ ~A~] unavailable~@[: ~A~]"
                     (terminal-native-unavailable-library c)
                     (terminal-native-unavailable-reason c)))))

(defun invalid-argument (name value &optional terminal)
  "Signal TERMINAL-INVALID-ARGUMENT. A USE-VALUE restart returns its value."
  (restart-case (error 'terminal-invalid-argument :name name :value value
                                                  :terminal terminal)
    (use-value (replacement)
      :report "Supply a replacement value."
      :interactive (lambda ()
                     (format *query-io* "Replacement value: ")
                     (force-output *query-io*)
                     (list (read *query-io*)))
      replacement)))

(defun unsupported (feature &optional terminal)
  "Signal TERMINAL-UNSUPPORTED for FEATURE. Backends call this from a method
that cannot honour the request. A USE-VALUE restart returns its value as the
method's result."
  (restart-case (error 'terminal-unsupported :feature feature :terminal terminal)
    (use-value (value)
      :report "Return a value instead."
      value)))
