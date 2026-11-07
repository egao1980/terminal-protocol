(in-package #:terminal-protocol/tests)

(deftest value-types-compare-with-equalp
  (ok (equalp (tp:make-cell :text "a") (tp:make-cell :text "a")))
  (ng (equalp (tp:make-cell :text "a")
              (tp:make-cell :text "a" :style (tp:make-style :bold t))))
  (ok (equalp (tp:make-rgb 1 2 3) (tp:make-rgb 1 2 3)))
  (ok (typep (tp:make-rgb 1 2 3) 'tp:color))
  (ok (typep :default 'tp:color))
  (ok (typep 255 'tp:color))
  (ng (typep 256 'tp:color)))

(deftest key-names-are-w3c-codes
  (ok (tp:key-name-p :a))
  (ok (tp:key-name-p :arrow-up))
  (ok (tp:key-name-p :numpad-enter))
  (ok (tp:key-name-p :f25))
  (ng (tp:key-name-p :up))
  (ng (tp:key-name-p "a"))
  (ok (= (length tp:+key-names+)
         (length (remove-duplicates tp:+key-names+)))))

(deftest normalize-mode-designators
  (ok (equal (multiple-value-list (tp:normalize-mode :bracketed-paste)) '(:dec 2004)))
  (ok (equal (multiple-value-list (tp:normalize-mode :insert)) '(:ansi 4)))
  (ok (equal (multiple-value-list (tp:normalize-mode '(:dec 25))) '(:dec 25)))
  (ok (signals (tp:normalize-mode :nope) 'tp:terminal-invalid-argument))
  (ok (signals (tp:normalize-mode '(:dec -1)) 'tp:terminal-invalid-argument)))

(deftest normalize-mode-use-value-restart
  (ok (equal (handler-bind ((tp:terminal-invalid-argument
                              (lambda (c) (use-value :cursor-visible c))))
               (multiple-value-list (tp:normalize-mode :nope)))
             '(:dec 25))))

(deftest paste-safety
  (ok (tp:paste-safe-p "ls -la"))
  (ng (tp:paste-safe-p (format nil "rm -rf /~%")))
  (ng (tp:paste-safe-p (format nil "a~Cb" #\Return)))
  (ng (tp:paste-safe-p (format nil "x~C[201~~y" #\Esc))))
