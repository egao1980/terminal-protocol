(defpackage #:terminal-protocol
  (:use #:cl)
  (:nicknames #:stack-terminal)
  (:export
   ;; conditions
   #:terminal-error
   #:terminal-error-terminal
   #:terminal-closed-error
   #:terminal-unsupported
   #:terminal-unsupported-feature
   #:terminal-invalid-argument
   #:terminal-invalid-argument-name
   #:terminal-invalid-argument-value
   #:terminal-out-of-memory
   #:terminal-reentrant-feed
   #:terminal-host-error
   #:terminal-host-error-cause
   #:terminal-native-unavailable
   #:terminal-native-unavailable-library
   #:terminal-native-unavailable-reason
   #:terminal-no-backend
   #:unsupported

   ;; value types
   #:color
   #:rgb #:make-rgb #:rgb-p #:rgb-r #:rgb-g #:rgb-b
   #:style #:make-style #:style-p #:copy-style
   #:style-foreground #:style-background #:style-underline-color
   #:style-bold #:style-faint #:style-italic #:style-blink #:style-inverse
   #:style-invisible #:style-strikethrough #:style-overline #:style-underline
   #:style-hyperlink
   #:+default-style+
   #:cell #:make-cell #:cell-p #:cell-text #:cell-width #:cell-style
   #:cursor #:make-cursor #:cursor-p #:cursor-x #:cursor-y #:cursor-visible-p
   #:cursor-style #:cursor-blinking-p #:cursor-wide-tail-p
   #:terminal-colors #:make-terminal-colors #:terminal-colors-p
   #:terminal-colors-foreground #:terminal-colors-background
   #:terminal-colors-cursor #:terminal-colors-palette

   ;; keys / mouse / modes
   #:+key-names+ #:key-name-p
   #:+modifiers+ #:+key-actions+
   #:+mouse-buttons+ #:+mouse-actions+
   #:+mode-names+ #:normalize-mode

   ;; backend
   #:terminal-backend
   #:*terminal-backend*
   #:backend-supports-p
   #:backend-make-terminal

   ;; terminal
   #:terminal
   #:terminal-backend-of
   #:terminal-host-of
   #:make-terminal
   #:with-terminal
   #:terminal-close
   #:terminal-closed-p
   #:terminal-feed
   #:terminal-resize
   #:terminal-reset
   #:terminal-size
   #:terminal-cursor
   #:terminal-title
   #:terminal-pwd
   #:terminal-active-screen
   #:terminal-mode
   #:backend-mode
   #:terminal-mouse-tracking
   #:terminal-scroll-viewport
   #:terminal-text

   ;; frames
   #:frame
   #:frame-terminal
   #:make-frame
   #:frame-update
   #:frame-size
   #:frame-cursor
   #:frame-colors
   #:frame-row
   #:map-frame-rows
   #:do-frame-rows
   #:frame-mark-clean
   #:frame-close
   #:with-frame
   #:row
   #:row-y
   #:row-dirty-p
   #:row-cells

   ;; input encoding
   #:encode-key
   #:encode-mouse
   #:encode-focus
   #:encode-paste
   #:paste-safe-p

   ;; host
   #:terminal-host
   #:buffering-host
   #:call-host
   #:host-write-pty
   #:host-bell
   #:host-title-changed
   #:host-pwd-changed
   #:host-clipboard-write
   #:host-clipboard-read
   #:host-notify
   #:host-color-scheme
   #:host-prompt-mark
   #:host-take-replies
   #:terminal-take-replies

   ;; snapshot
   #:terminal-snapshot))
