# terminal-protocol

CLOS **headless terminal emulator** protocol for [cl-stack](https://github.com/egao1980/cl-stack). Feed it the bytes a program writes. Read back cells, cursor, modes and title. Encode keys, mouse, focus and paste into the bytes the program expects.

There's no PTY, no rendering and no fonts. Brief: [`cl-stack/docs/capabilities/terminal.md`](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/terminal.md) ([#264](https://github.com/egao1980/cl-stack/issues/264)).

| System | Role | Repo |
|--------|------|------|
| `terminal-protocol` (`stack-terminal`) | GFs, value types, conditions, host protocol | this repo |
| `terminal-backend-ghostty` | Default: [libghostty-vt 1.0](https://mitchellh.com/writing/libghostty-1-0) through [`ghostty-vt`](https://github.com/egao1980/ghostty-vt) | [`egao1980/terminal-backend-ghostty`](https://github.com/egao1980/terminal-backend-ghostty) |
| `terminal-backend-lisp` | Pure CL, VT core subset | [`egao1980/terminal-backend-lisp`](https://github.com/egao1980/terminal-backend-lisp) |
| `terminal-parity` | Golden corpus run against every backend | [`egao1980/terminal-parity`](https://github.com/egao1980/terminal-parity) |

```lisp
(asdf:load-system "terminal-backend-ghostty")

(stack-terminal:with-terminal (term :cols 80 :rows 24)
  (stack-terminal:terminal-feed
   term (babel:string-to-octets (format nil "Hello, ~C[1;32mworld~C[0m!" #\Esc #\Esc)))
  (stack-terminal:terminal-text term))
;; ⇒ "Hello, world!"
```

## Rules a backend inherits

- **Bytes in.** `terminal-feed` takes `(vector (unsigned-byte 8))` and `:start` / `:end`.
- **Effects go through `call-host`.** Replies, bell, title, clipboard and notifications are generic functions on a `terminal-host`. The default `buffering-host` keeps replies for `terminal-take-replies`.
- **No unwinding through the parser.** Inside a feed, `call-host` catches a host method's condition and `terminal-feed` re-signals it afterwards as `terminal-host-error`, with a `continue` restart.
- **No reentrancy.** Feeding a terminal from inside its own host effect signals `terminal-reentrant-feed`. Feeding a *different* terminal is fine.
- **One owner thread** per terminal. Nothing locks.
- **Closed terminals** signal `terminal-closed-error` from every operation. `terminal-close` is idempotent.
- **Keys** are W3C `KeyboardEvent.code` names, kebab-cased (`:a`, `:arrow-up`, `:numpad-enter`). **Modes** are keywords (`:bracketed-paste`), `(:dec n)` or `(:ansi n)`.
- Bad arguments signal `terminal-invalid-argument` with a `use-value` restart. Missing features signal `terminal-unsupported`.

`terminal-search` (→ `terminal-match` x/y/end, in cell columns) and `terminal-selection-text` (linear or `:rectangular`, like a mouse copy) work over the viewport. The protocol defines them once on top of frames, so every backend has them.

`terminal-snapshot` builds a backend-neutral plist (lines, cells, cursor, title, screen) from protocol calls only. Parity suites compare snapshots with `equalp`.

## License

MIT
