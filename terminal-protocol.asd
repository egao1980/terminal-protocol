(defsystem "terminal-protocol"
  :version "0.1.0"
  :description "CLOS headless terminal-emulator protocol for cl-stack (feed octets, frames, input encoding, host effects)"
  :author "egao1980"
  :license "MIT"
  :depends-on ()
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "types")
               (:file "keys")
               (:file "modes")
               (:file "host")
               (:file "protocol")
               (:file "snapshot"))
  :in-order-to ((test-op (test-op "terminal-protocol/tests"))))

(defsystem "terminal-protocol/tests"
  :depends-on ("terminal-protocol" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "mock-backend")
               (:file "types-test")
               (:file "protocol-test")
               (:file "host-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
