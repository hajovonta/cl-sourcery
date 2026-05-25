# cl-sourcery

Transparent source capture for Common Lisp definitions via macro hijacking.

Intercepts all standard CL definition forms (`defun`, `defmacro`, `defclass`, `defstruct`, etc.) to capture and store the exact source as written. Definitions are stored verbatim as lists with full metadata — enabling introspection, IDE tooling, and distributed system foundations without modifying existing code.

## Quick Start

```lisp
(ql:quickload :cl-sourcery)

;; Activate — all subsequent definitions are captured transparently
(cl-sourcery:activate)

;; Write normal CL code — nothing changes
(defun add (a b) (+ a b))

(defclass person ()
  ((name :initarg :name :accessor person-name)
   (age :initarg :age :accessor person-age)))

;; Retrieve exact source
(cl-sourcery:get-source 'add)
;; => #S(SOURCE-ENTRY
;;      :FORM (DEFUN ADD (A B) (+ A B))
;;      :TIMESTAMP 3953164800
;;      :PACKAGE "COMMON-LISP-USER"
;;      :FILE NIL
;;      :TYPE :FUNCTION)

;; Deactivate when done
(cl-sourcery:deactivate)
```

## Features

- **Zero-change adoption** — Activate once, all definitions in the image are captured. Existing libraries work unmodified.
- **Verbatim source** — Stores the exact form as written, not what `function-lambda-expression` returns.
- **Full metadata** — Timestamp, package, source file (`*load-pathname*` / `*compile-file-pathname*`), definition type.
- **All definition forms** — 13 standard CL forms hijacked (see table below).
- **Method-aware** — Methods keyed by `(name qualifiers . specializers)` — multiple methods per GF stored independently.
- **Safe activation** — `activate`/`deactivate` cleanly install and restore original macros.

## Captured Forms

| Form | Type keyword | Key |
|------|-------------|-----|
| `defun` | `:function` | symbol |
| `defmacro` | `:macro` | symbol |
| `defvar` | `:variable` | symbol |
| `defparameter` | `:parameter` | symbol |
| `defconstant` | `:constant` | symbol |
| `defgeneric` | `:generic` | symbol |
| `defmethod` | `:method` | `(name qualifiers . specializers)` |
| `defclass` | `:class` | symbol |
| `defstruct` | `:struct` | symbol |
| `define-condition` | `:condition` | symbol |
| `deftype` | `:type` | symbol |
| `defpackage` | `:package` | keyword |
| `define-compiler-macro` | `:compiler-macro` | `(name . :compiler-macro)` |

## API

### Activation

```lisp
(cl-sourcery:activate)    ;; Install hijack macros
(cl-sourcery:deactivate)  ;; Restore originals
(cl-sourcery:active-p)    ;; Check status
```

### Query

```lisp
;; Get source entry for a symbol
(cl-sourcery:get-source 'my-function)
;; => #S(SOURCE-ENTRY ...)

;; Get all method entries for a generic function
(cl-sourcery:get-source 'my-gf :method)
;; => (#S(SOURCE-ENTRY ...) #S(SOURCE-ENTRY ...))

;; Get all entries (function + methods + generic) for a symbol
(cl-sourcery:get-all-sources 'my-gf)

;; List all captured definitions, optionally filtered by type
(cl-sourcery:list-definitions)
(cl-sourcery:list-definitions :function)

;; Count
(cl-sourcery:definition-count)
```

### Registry Management

```lisp
(cl-sourcery:clear-registry)              ;; Wipe all entries
(cl-sourcery:remove-source 'sym)          ;; Remove specific entry
(cl-sourcery:remove-source 'sym :method)  ;; Remove all methods for sym
```

### Entry Accessors

```lisp
(cl-sourcery:source-entry-form entry)       ;; The full source form (list)
(cl-sourcery:source-entry-timestamp entry)  ;; Universal-time of definition
(cl-sourcery:source-entry-package entry)    ;; Package name (string)
(cl-sourcery:source-entry-file entry)       ;; Source file path or NIL
(cl-sourcery:source-entry-type entry)       ;; Type keyword
```

## How It Works

No source parsing. No reader tricks. The mechanism is simple:

1. **`activate`** unlocks the `COMMON-LISP` package (via `sb-ext:unlock-package`)
2. Saves the original `macro-function` for each definition form
3. Installs new macro-functions that:
   - Call the **saved original** macro-function to get the standard expansion
   - Wrap it in `(progn (register-source ...) <original-expansion>)`
4. **`deactivate`** restores the saved originals and re-locks the package

The key insight: hijack macros never reference `cl:defun` etc. by symbol (which would recurse infinitely). Instead they `funcall` the saved original macro-function directly.

## Use Cases

- **IDE/GUI introspection** — Display definitions exactly as written
- **Documentation generation** — Extract source for all exported symbols
- **Hot-reload tracking** — Know what changed and when
- **Foundation for RPC** — Paired with a REST layer, any captured function can be network-exposed
- **Audit trail** — Track all definitions with timestamps and source files

## File Scanner

For projects already loaded (without hijack active), the scanner extracts source text directly from files:

```lisp
;; Scan a file — returns list of source-entry structs
(cl-sourcery:scan-file #P"/path/to/my-file.lisp")

;; Scan and populate the registry (for later lookup via get-source)
(cl-sourcery:scan-file-to-registry #P"/path/to/my-file.lisp")
```

The scanner handles `in-package` forms, character literals (`#\"`), block comments (`#|...|#`), vector literals (`#(...)`), and read-eval (`#.`) gracefully.

### Extending the Scanner

Register custom definition forms via `*extra-definition-forms*`:

```lisp
;; Recognize CLIM's define-application-frame and define-command
(push "define-application-frame" cl-sourcery:*extra-definition-forms*)
(push "define-command" cl-sourcery:*extra-definition-forms*)
```

Forms listed here are treated like `defun` — the second element is used as the definition name. `alexandria:define-constant` is included by default.

## Compatibility

Tested on SBCL. Portable to any implementation with package locks:

- **SBCL** — `sb-ext:unlock-package` / `sb-ext:lock-package`
- **CCL** — `ccl:package-lock`
- **ECL** — `ext:package-lock`
- **LispWorks** — `hcl:set-package-lock`
- **Allegro CL** — `excl:package-lock`
- **Clasp** — `ext:package-lock`

Implementations without package locks (ABCL, etc.) work without any special handling.

## Dependencies

None. Pure Common Lisp (plus the implementation-specific package lock abstraction).

## Tests

```lisp
(ql:quickload :cl-sourcery-tests)
(fiveam:run! :cl-sourcery)
;; 146 checks, all passing
```

## License

MIT
