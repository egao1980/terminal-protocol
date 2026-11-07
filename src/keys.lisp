(in-package #:terminal-protocol)

;;; Physical key names: the W3C UI Events KeyboardEvent.code values, kebab-cased
;;; (KeyA → :A, ArrowUp → :ARROW-UP, Digit1 → :DIGIT-1, NumpadEnter →
;;; :NUMPAD-ENTER). Layout-resolved text goes in ENCODE-KEY's :TEXT.

(defparameter +key-names+
  '(
    :unidentified :backquote :backslash :bracket-left :bracket-right :comma 
    :digit-0 :digit-1 :digit-2 :digit-3 :digit-4 :digit-5 :digit-6 :digit-7 
    :digit-8 :digit-9 :equal :intl-backslash :intl-ro :intl-yen :a :b :c :d :e 
    :f :g :h :i :j :k :l :m :n :o :p :q :r :s :t :u :v :w :x :y :z :minus 
    :period :quote :semicolon :slash :alt-left :alt-right :backspace :caps-lock 
    :context-menu :control-left :control-right :enter :meta-left :meta-right 
    :shift-left :shift-right :space :tab :convert :kana-mode :non-convert 
    :delete :end :help :home :insert :page-down :page-up :arrow-down 
    :arrow-left :arrow-right :arrow-up :num-lock :numpad-0 :numpad-1 :numpad-2 
    :numpad-3 :numpad-4 :numpad-5 :numpad-6 :numpad-7 :numpad-8 :numpad-9 
    :numpad-add :numpad-backspace :numpad-clear :numpad-clear-entry 
    :numpad-comma :numpad-decimal :numpad-divide :numpad-enter :numpad-equal 
    :numpad-memory-add :numpad-memory-clear :numpad-memory-recall 
    :numpad-memory-store :numpad-memory-subtract :numpad-multiply 
    :numpad-paren-left :numpad-paren-right :numpad-subtract :numpad-separator 
    :numpad-up :numpad-down :numpad-right :numpad-left :numpad-begin 
    :numpad-home :numpad-end :numpad-insert :numpad-delete :numpad-page-up 
    :numpad-page-down :escape :f1 :f2 :f3 :f4 :f5 :f6 :f7 :f8 :f9 :f10 :f11 
    :f12 :f13 :f14 :f15 :f16 :f17 :f18 :f19 :f20 :f21 :f22 :f23 :f24 :f25 :fn 
    :fn-lock :print-screen :scroll-lock :pause :browser-back :browser-favorites 
    :browser-forward :browser-home :browser-refresh :browser-search 
    :browser-stop :eject :launch-app-1 :launch-app-2 :launch-mail 
    :media-play-pause :media-select :media-stop :media-track-next 
    :media-track-previous :power :sleep :audio-volume-down :audio-volume-mute 
    :audio-volume-up :wake-up :copy :cut :paste )
  "Every physical key name ENCODE-KEY accepts.")

(defparameter +modifiers+ '(:shift :ctrl :alt :super :caps-lock :num-lock)
  "Modifier keywords for ENCODE-KEY and ENCODE-MOUSE.")

(defparameter +key-actions+ '(:press :repeat :release))

(defparameter +mouse-buttons+
  '(nil :left :middle :right :wheel-up :wheel-down :wheel-left :wheel-right
    :back :forward :button-10 :button-11)
  "Mouse buttons for ENCODE-MOUSE. NIL is motion with no button held.
The wheel names are xterm buttons 4-7. :BACK and :FORWARD are 8 and 9.")

(defparameter +mouse-actions+ '(:press :release :motion))

(defun key-name-p (object)
  (and (keywordp object) (member object +key-names+ :test #'eq) t))
