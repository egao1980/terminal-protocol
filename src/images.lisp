(in-package #:terminal-protocol)

;;; Images (Kitty graphics protocol). Feature :KITTY-GRAPHICS. Backends
;;; without it keep the defaults: no placements, TERMINAL-IMAGE unsupported.

(deftype image-layer () '(member :below-background :below-text :above-text))
(deftype image-format () '(member :rgb :rgba :gray :gray-alpha))

(defstruct image-placement
  "Where to draw (part of) an image in the viewport. X and Y are the top-left
cell and can be negative for an image that starts off-screen. COLS × ROWS
cells are covered. Draw the SOURCE-* rectangle of the image at
PIXEL-WIDTH × PIXEL-HEIGHT, shifted CELL-OFFSET-* pixels into the first
cell. Lower Z is drawn first within a LAYER."
  (image-id 0 :type (integer 0))
  (placement-id 0 :type (integer 0))
  (x 0 :type integer)
  (y 0 :type integer)
  (cols 0 :type (integer 0))
  (rows 0 :type (integer 0))
  (z 0 :type integer)
  (layer :above-text :type image-layer)
  (cell-offset-x 0 :type (integer 0))
  (cell-offset-y 0 :type (integer 0))
  (pixel-width 0 :type (integer 0))
  (pixel-height 0 :type (integer 0))
  (source-x 0 :type (integer 0))
  (source-y 0 :type (integer 0))
  (source-width 0 :type (integer 0))
  (source-height 0 :type (integer 0)))

(defstruct terminal-image
  "A stored image: WIDTH × HEIGHT pixels in FORMAT (PNG arrives decoded to
:RGBA). PIXELS is a fresh octet vector."
  (id 0 :type (integer 0))
  (width 0 :type (integer 0))
  (height 0 :type (integer 0))
  (format :rgba :type image-format)
  (pixels (make-array 0 :element-type '(unsigned-byte 8))
   :type (simple-array (unsigned-byte 8) (*))))

(defgeneric frame-images (frame)
  (:documentation "→ the image placements visible in FRAME, as IMAGE-PLACEMENT
structs in drawing order. Empty for backends without :KITTY-GRAPHICS.")
  (:method ((frame frame)) '()))

(define-terminal-generic terminal-image (terminal image-id)
  (:documentation "→ the TERMINAL-IMAGE stored under IMAGE-ID, or NIL if there
is none. Signals TERMINAL-UNSUPPORTED on backends without :KITTY-GRAPHICS."))

(defmethod terminal-image ((terminal terminal) image-id)
  (declare (ignore image-id))
  (unsupported :kitty-graphics terminal))
