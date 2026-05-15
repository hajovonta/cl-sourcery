# cl-sourcery

Transparent source capture for Common Lisp definitions.

## Overview

cl-sourcery hijacks standard CL definition forms (`defun`, `defmacro`, `defvar`, `defparameter`, `defgeneric`, `defmethod`) to capture and store the exact source as written. This enables:

- Full source introspection from a running image
- IDE/GUI tools that display definitions verbatim
- Foundation for distributed systems (paired with a REST exposure layer)

## Usage

```lisp
(ql:quickload :cl-sourcery)

;; Activate hijack — all subsequent definitions are captured
(cl-sourcery:activate)

;; Define things normally
(defun add (a b) (+ a b))

;; Retrieve the source
(cl-sourcery:get-source 'add)
;; => #S(SOURCE-ENTRY :FORM (DEFUN ADD (A B) (+ A B)) ...)

;; Deactivate when done
(cl-sourcery:deactivate)
```

## API

- `(activate)` — Install hijack macros
- `(deactivate)` — Restore original CL macros
- `(active-p)` — Check if hijack is active
- `(get-source symbol &optional type)` — Get source entry
- `(get-all-sources symbol)` — Get all entries for a symbol
- `(list-definitions &optional type)` — List all captured definitions
- `(definition-count)` — Count of stored definitions
- `(clear-registry)` — Wipe all stored definitions
- `(remove-source symbol &optional type)` — Remove specific entry

## License

MIT
