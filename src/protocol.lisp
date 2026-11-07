(in-package #:terminal-protocol)

;;; ------------------------------------------------------------------
;;; Backend

(defclass terminal-backend () ()
  (:documentation "Selects an emulator implementation. Backends subclass it
and set *TERMINAL-BACKEND* when they load."))

(defvar *terminal-backend* nil)

(defgeneric backend-supports-p (backend feature)
  (:documentation "True if BACKEND implements FEATURE: :SCROLLBACK
:ALTERNATE-SCREEN :KITTY-KEYBOARD :OSC-52 :OSC-133 :FORMAT-VT :FORMAT-HTML.")
  (:method ((backend terminal-backend) feature)
    (declare (ignore feature))
    nil))

(defgeneric backend-make-terminal (backend &key cols rows host scrollback-lines
                                     &allow-other-keys)
  (:documentation "→ a fresh TERMINAL. Called by MAKE-TERMINAL with validated
:COLS, :ROWS and :HOST."))

;;; ------------------------------------------------------------------
;;; Terminal

(defclass terminal ()
  ((backend :initarg :backend :reader terminal-backend-of)
   (host :initarg :host :reader terminal-host-of)
   (closed-p :initform nil :accessor %terminal-closed-p))
  (:documentation "One emulated terminal. Backends subclass it. A terminal
has one owner thread; the protocol does not lock."))

(defun %positive-dimension (name value)
  (loop until (typep value '(integer 1 65535))
        do (setf value (invalid-argument name value)))
  value)

(defun make-terminal (&rest keys &key (backend *terminal-backend*)
                                      (cols 80) (rows 24) host
                      &allow-other-keys)
  "→ a TERMINAL from BACKEND. HOST defaults to a fresh BUFFERING-HOST. Other
keys (:SCROLLBACK-LINES, …) pass through to BACKEND-MAKE-TERMINAL."
  (unless backend
    (error 'terminal-no-backend))
  (let ((keys (copy-list keys)))
    (remf keys :backend)
    (remf keys :cols)
    (remf keys :rows)
    (remf keys :host)
    (apply #'backend-make-terminal backend
           :cols (%positive-dimension 'cols cols)
           :rows (%positive-dimension 'rows rows)
           :host (or host (make-instance 'buffering-host))
           keys)))

(defgeneric terminal-closed-p (terminal)
  (:method ((terminal terminal))
    (%terminal-closed-p terminal)))

(defgeneric terminal-close (terminal)
  (:documentation "Free the terminal. Idempotent.")
  (:method ((terminal terminal))
    nil)
  (:method :around ((terminal terminal))
    (unless (%terminal-closed-p terminal)
      (unwind-protect (call-next-method)
        (setf (%terminal-closed-p terminal) t)))
    nil))

(defmacro with-terminal ((var &rest keys) &body body)
  "Bind VAR to (MAKE-TERMINAL ,@KEYS) around BODY, closing it afterwards."
  `(let ((,var (make-terminal ,@keys)))
     (unwind-protect (progn ,@body)
       (terminal-close ,var))))

(defun %check-open (terminal)
  (when (%terminal-closed-p terminal)
    (error 'terminal-closed-error :terminal terminal)))

(defmacro define-terminal-generic (name lambda-list &body options)
  "DEFGENERIC whose first argument is a TERMINAL, plus an :AROUND method that
signals TERMINAL-CLOSED-ERROR once the terminal is closed."
  (let* ((rest-args (gensym "ARGS"))
         (required (loop for arg in lambda-list
                         until (member arg lambda-list-keywords)
                         collect arg))
         ;; Congruence: only take &REST when the generic has optional parts.
         (tail (when (nthcdr (length required) lambda-list)
                 (list '&rest rest-args))))
    `(progn
       (defgeneric ,name ,lambda-list ,@options)
       (defmethod ,name :around ((,(first required) terminal) ,@(rest required)
                                 ,@tail)
         (declare (ignore ,@(rest required) ,@(rest tail)))
         (%check-open ,(first required))
         (call-next-method)))))

;;; ------------------------------------------------------------------
;;; Host dispatch

(defvar *feeding* '()
  "Terminals whose TERMINAL-FEED is running in this thread.")

(defvar *host-error-sink* nil
  "Inside TERMINAL-FEED: a function receiving conditions raised by host methods.")

(defun call-host (terminal function &rest args)
  "Call host effect FUNCTION (e.g. #'HOST-BELL) with TERMINAL's host, TERMINAL
and ARGS. Backends deliver every effect through this.

While a feed is running, a native parser may be on the stack, and a
non-local exit through foreign frames is undefined. So inside TERMINAL-FEED
a SERIOUS-CONDITION from the host method is recorded and NIL is returned.
TERMINAL-FEED re-signals it as TERMINAL-HOST-ERROR after the backend
returns. Outside a feed, conditions propagate as usual."
  (let ((host (terminal-host-of terminal))
        (sink *host-error-sink*))
    (if sink
        (handler-case (apply function host terminal args)
          (serious-condition (c)
            (funcall sink c)
            nil))
        (apply function host terminal args))))

;;; ------------------------------------------------------------------
;;; Program → terminal

(defgeneric terminal-feed (terminal octets &key start end)
  (:documentation "Parse OCTETS[START, END) as program output. Sequences split
across calls resume. → NIL."))

(defmethod terminal-feed :around ((terminal terminal) octets &key (start 0) end)
  (%check-open terminal)
  (unless (typep octets '(vector (unsigned-byte 8)))
    (error 'type-error :datum octets :expected-type '(vector (unsigned-byte 8))))
  (let ((end (or end (length octets))))
    (unless (and (integerp start) (<= 0 start end (length octets)))
      (error 'terminal-invalid-argument :name 'start/end :value (list start end)
                                        :terminal terminal)))
  (when (member terminal *feeding* :test #'eq)
    (error 'terminal-reentrant-feed :terminal terminal))
  (let ((errors '()))
    (let ((*feeding* (cons terminal *feeding*))
          (*host-error-sink* (lambda (c) (push c errors))))
      (call-next-method))
    (dolist (cause (nreverse errors))
      (restart-case (error 'terminal-host-error :terminal terminal :cause cause)
        (continue ()
          :report "Ignore the failed host effect."
          nil)))
    nil))

(define-terminal-generic terminal-resize (terminal cols rows &key cell-width-px
                                                    cell-height-px)
  (:documentation "Resize to COLS × ROWS cells. Pixel sizes feed size reports."))

(defmethod terminal-resize :before ((terminal terminal) cols rows &key
                                    cell-width-px cell-height-px)
  (declare (ignore cell-width-px cell-height-px))
  (%positive-dimension 'cols cols)
  (%positive-dimension 'rows rows))

(define-terminal-generic terminal-reset (terminal)
  (:documentation "Full reset (RIS)."))

;;; ------------------------------------------------------------------
;;; State

(define-terminal-generic terminal-size (terminal)
  (:documentation "→ (values cols rows)."))

(define-terminal-generic terminal-cursor (terminal)
  (:documentation "→ CURSOR in active-screen coordinates."))

(define-terminal-generic terminal-title (terminal)
  (:documentation "OSC 0/2 title → string or NIL."))

(define-terminal-generic terminal-pwd (terminal)
  (:documentation "OSC 7 working directory → string or NIL."))

(define-terminal-generic terminal-active-screen (terminal)
  (:documentation "→ :PRIMARY or :ALTERNATE."))

(define-terminal-generic backend-mode (terminal kind number)
  (:documentation "Backend side of TERMINAL-MODE. KIND is :DEC or :ANSI."))

(defgeneric (setf backend-mode) (value terminal kind number))

(defmethod (setf backend-mode) :around (value (terminal terminal) kind number)
  (declare (ignore value kind number))
  (%check-open terminal)
  (call-next-method))

(defun terminal-mode (terminal mode)
  "True if MODE is set. MODE is a keyword from +MODE-NAMES+, (:DEC n) or (:ANSI n)."
  (multiple-value-bind (kind number) (normalize-mode mode)
    (backend-mode terminal kind number)))

(defun (setf terminal-mode) (value terminal mode)
  (multiple-value-bind (kind number) (normalize-mode mode)
    (setf (backend-mode terminal kind number) (and value t))))

(define-terminal-generic terminal-mouse-tracking (terminal)
  (:documentation "→ :NONE :X10 :NORMAL :BUTTON or :ANY."))

(define-terminal-generic terminal-scroll-viewport (terminal &key to delta)
  (:documentation "Scroll the viewport. TO is :TOP or :BOTTOM; DELTA is rows
(negative = up, into scrollback)."))

(define-terminal-generic terminal-text (terminal &key format region)
  (:documentation "→ the screen as a string. FORMAT is :PLAIN (default), :VT
or :HTML. REGION is :VIEWPORT (default), :SCREEN or :SCROLLBACK."))

(defmethod terminal-text :before ((terminal terminal) &key (format :plain)
                                                          (region :viewport))
  (unless (member format '(:plain :vt :html))
    (invalid-argument 'format format terminal))
  (unless (member region '(:viewport :screen :scrollback))
    (invalid-argument 'region region terminal)))

;;; ------------------------------------------------------------------
;;; Frames

(defclass frame ()
  ((terminal :initarg :terminal :reader frame-terminal))
  (:documentation "A reusable snapshot of the viewport. Backends subclass it."))

(defclass row ()
  ((y :initarg :y :reader row-y)
   (dirty-p :initarg :dirty-p :initform t :accessor row-dirty-p)
   (cells :initarg :cells :reader row-cells))
  (:documentation "One viewport row: Y, dirty flag and a vector of CELL."))

(define-terminal-generic make-frame (terminal)
  (:documentation "→ a FRAME for TERMINAL. Call FRAME-UPDATE before reading it."))

(defgeneric frame-update (frame)
  (:documentation "Refresh FRAME from its terminal. → :NONE, :PARTIAL or :FULL."))

(defmethod frame-update :around ((frame frame))
  (%check-open (frame-terminal frame))
  (call-next-method))

(defgeneric frame-size (frame)
  (:documentation "→ (values cols rows)."))

(defgeneric frame-cursor (frame)
  (:documentation "→ CURSOR in viewport coordinates, or NIL if it is off-screen."))

(defgeneric frame-colors (frame)
  (:documentation "→ TERMINAL-COLORS."))

(defgeneric frame-row (frame y)
  (:documentation "→ ROW Y of the viewport (0 = top)."))

(defgeneric frame-mark-clean (frame)
  (:documentation "Clear the frame's and every row's dirty flag."))

(defgeneric frame-close (frame)
  (:documentation "Free native resources held by FRAME. Idempotent.")
  (:method ((frame frame))
    nil))

(defgeneric map-frame-rows (function frame &key dirty-only)
  (:documentation "Call FUNCTION on each ROW, top to bottom.")
  (:method (function (frame frame) &key dirty-only)
    (multiple-value-bind (cols rows) (frame-size frame)
      (declare (ignore cols))
      (dotimes (y rows)
        (let ((row (frame-row frame y)))
          (when (or (not dirty-only) (row-dirty-p row))
            (funcall function row)))))
    nil))

(defmacro do-frame-rows ((row frame &key dirty-only) &body body)
  `(block nil
     (map-frame-rows (lambda (,row) ,@body) ,frame :dirty-only ,dirty-only)))

(defmacro with-frame ((var terminal) &body body)
  "Bind VAR to a fresh, updated frame of TERMINAL around BODY."
  `(let ((,var (make-frame ,terminal)))
     (unwind-protect (progn (frame-update ,var) ,@body)
       (frame-close ,var))))

;;; ------------------------------------------------------------------
;;; Input encoding (terminal → program). Results are octet vectors, empty
;;; when the event produces no bytes in the terminal's current modes.

(defun %check-modifiers (modifiers terminal)
  (loop until (and (listp modifiers)
                   (every (lambda (m) (member m +modifiers+)) modifiers))
        do (setf modifiers (invalid-argument 'modifiers modifiers terminal)))
  modifiers)

(define-terminal-generic encode-key (terminal key &key text modifiers action)
  (:documentation "Encode a key event. KEY is from +KEY-NAMES+. TEXT is the
layout-resolved text, or NIL. ACTION is :PRESS (default), :REPEAT or :RELEASE."))

(defmethod encode-key :around ((terminal terminal) key &key text modifiers
                                                         (action :press))
  ;; Replaces the closed-check :AROUND from DEFINE-TERMINAL-GENERIC.
  (%check-open terminal)
  (loop until (key-name-p key)
        do (setf key (invalid-argument 'key key terminal)))
  (unless (typep text '(or null string))
    (setf text (invalid-argument 'text text terminal)))
  (loop until (member action +key-actions+)
        do (setf action (invalid-argument 'action action terminal)))
  (call-next-method terminal key :text text
                                 :modifiers (%check-modifiers modifiers terminal)
                                 :action action))

(define-terminal-generic encode-mouse (terminal button action x y &key modifiers
                                                pixel-x pixel-y)
  (:documentation "Encode a mouse event at cell X, Y (0-based) in the
terminal's mouse tracking mode and format. BUTTON is from +MOUSE-BUTTONS+;
ACTION is :PRESS, :RELEASE or :MOTION."))

(defmethod encode-mouse :around ((terminal terminal) button action x y
                                 &key modifiers pixel-x pixel-y)
  (%check-open terminal)
  (loop until (member button +mouse-buttons+)
        do (setf button (invalid-argument 'button button terminal)))
  (loop until (member action +mouse-actions+)
        do (setf action (invalid-argument 'action action terminal)))
  (loop until (typep x '(integer 0))
        do (setf x (invalid-argument 'x x terminal)))
  (loop until (typep y '(integer 0))
        do (setf y (invalid-argument 'y y terminal)))
  (call-next-method terminal button action x y
                    :modifiers (%check-modifiers modifiers terminal)
                    :pixel-x pixel-x :pixel-y pixel-y))

(define-terminal-generic encode-focus (terminal focused-p)
  (:documentation "Encode focus in/out. Empty unless focus events are enabled."))

(define-terminal-generic encode-paste (terminal string)
  (:documentation "Encode pasted STRING, bracketed when bracketed paste is on."))

(defun paste-safe-p (string)
  "False if STRING has a line terminator or the bracketed-paste end sequence.
Same rule as libghostty-vt's ghostty_paste_is_safe."
  (check-type string string)
  (not (or (find #\Newline string)
           (find #\Return string)
           (search (coerce '(#\Esc #\[ #\2 #\0 #\1 #\~) 'string) string))))

(defun terminal-take-replies (terminal)
  "→ the replies TERMINAL's BUFFERING-HOST collected, and clear them."
  (host-take-replies (terminal-host-of terminal)))

(defmethod host-take-replies ((host terminal-host))
  (unsupported :take-replies))
