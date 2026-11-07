(in-package #:terminal-protocol)

;;; The host receives effects the emulator pushes while it parses: replies to
;;; the program, bells, title changes, clipboard requests and notifications.
;;; Every method has a do-nothing default; subclass TERMINAL-HOST and specialise
;;; the ones you care about.

(defclass terminal-host () ()
  (:documentation "Receives terminal effects. Defaults ignore everything."))

(defclass buffering-host (terminal-host)
  ((replies :initform (make-array 0 :element-type '(unsigned-byte 8)
                                    :adjustable t :fill-pointer 0)
            :reader %host-replies))
  (:documentation "Default host: collects HOST-WRITE-PTY replies for
TERMINAL-TAKE-REPLIES and ignores every other effect."))

(defgeneric host-write-pty (host terminal octets)
  (:documentation "Bytes the terminal sends back to the program (DA, DSR,
XTVERSION and other replies). OCTETS is only valid during the call; copy it.")
  (:method ((host terminal-host) terminal octets)
    (declare (ignore terminal octets))
    nil)
  (:method ((host buffering-host) terminal octets)
    (declare (ignore terminal))
    (let ((buffer (%host-replies host)))
      (loop for octet across octets do (vector-push-extend octet buffer)))
    nil))

(defgeneric host-bell (host terminal)
  (:method ((host terminal-host) terminal)
    (declare (ignore terminal))
    nil))

(defgeneric host-title-changed (host terminal title)
  (:method ((host terminal-host) terminal title)
    (declare (ignore terminal title))
    nil))

(defgeneric host-pwd-changed (host terminal pwd)
  (:method ((host terminal-host) terminal pwd)
    (declare (ignore terminal pwd))
    nil))

(defgeneric host-clipboard-write (host terminal clipboard string)
  (:documentation "OSC 52 set. CLIPBOARD is :CLIPBOARD or :PRIMARY.")
  (:method ((host terminal-host) terminal clipboard string)
    (declare (ignore terminal clipboard string))
    nil))

(defgeneric host-clipboard-read (host terminal clipboard)
  (:documentation "OSC 52 query. Return a string to answer, or NIL to deny.")
  (:method ((host terminal-host) terminal clipboard)
    (declare (ignore terminal clipboard))
    nil))

(defgeneric host-notify (host terminal title body)
  (:documentation "Desktop notification (OSC 9 / OSC 777). TITLE may be NIL.")
  (:method ((host terminal-host) terminal title body)
    (declare (ignore terminal title body))
    nil))

(defgeneric host-color-scheme (host terminal)
  (:documentation "Answer a colour-scheme query: :LIGHT, :DARK or NIL (unknown).")
  (:method ((host terminal-host) terminal)
    (declare (ignore terminal))
    nil))

(defgeneric host-prompt-mark (host terminal kind)
  (:documentation "OSC 133 semantic prompt mark. KIND is :PROMPT-START,
:INPUT-START, :OUTPUT-START or :COMMAND-END.")
  (:method ((host terminal-host) terminal kind)
    (declare (ignore terminal kind))
    nil))

(defgeneric host-take-replies (host)
  (:documentation "→ the replies buffered so far as a fresh octet vector, and
clear the buffer.")
  (:method ((host buffering-host))
    (let* ((buffer (%host-replies host))
           (out (make-array (length buffer) :element-type '(unsigned-byte 8))))
      (replace out buffer)
      (setf (fill-pointer buffer) 0)
      out)))
