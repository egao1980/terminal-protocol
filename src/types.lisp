(in-package #:terminal-protocol)

;;; Value types are plain structures: EQUALP compares them, so snapshots from
;;; different backends can be compared directly.

(defstruct (rgb (:constructor make-rgb (r g b)))
  (r 0 :type (unsigned-byte 8) :read-only t)
  (g 0 :type (unsigned-byte 8) :read-only t)
  (b 0 :type (unsigned-byte 8) :read-only t))

(deftype color ()
  "A colour: :DEFAULT, a palette index 0-255, or an RGB."
  '(or (eql :default) (integer 0 255) rgb))

(deftype underline-kind ()
  '(member nil :single :double :curly :dotted :dashed))

(defstruct style
  (foreground :default :type color)
  (background :default :type color)
  (underline-color :default :type color)
  (bold nil :type boolean)
  (faint nil :type boolean)
  (italic nil :type boolean)
  (blink nil :type boolean)
  (inverse nil :type boolean)
  (invisible nil :type boolean)
  (strikethrough nil :type boolean)
  (overline nil :type boolean)
  (underline nil :type underline-kind)
  (hyperlink nil :type (or null string)))

(defparameter +default-style+ (make-style)
  "The style of a cell nothing has painted. Do not mutate it.")

(deftype cell-width ()
  "Columns a cell occupies. :SPACER is the right half of a wide character."
  '(member :narrow :wide :spacer))

(defstruct cell
  (text "" :type string)
  (width :narrow :type cell-width)
  (style +default-style+ :type style))

(deftype cursor-style ()
  '(member :block :bar :underline :block-hollow))

(defstruct cursor
  (x 0 :type (integer 0))
  (y 0 :type (integer 0))
  (visible-p t :type boolean)
  (style :block :type cursor-style)
  (blinking-p nil :type boolean)
  (wide-tail-p nil :type boolean))

(defstruct terminal-colors
  (foreground (make-rgb 255 255 255) :type rgb)
  (background (make-rgb 0 0 0) :type rgb)
  (cursor nil :type (or null rgb))
  (palette (make-array 256 :initial-element (make-rgb 0 0 0))
   :type (simple-vector 256)))
