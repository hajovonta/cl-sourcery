# cl-sourcery

Transparent source capture for Common Lisp definitions.

Intercepts all standard CL definition forms (`defun`, `defmacro`, `defclass`, `defstruct`, etc.) to capture and store the exact source as written — including whitespace, comments, and formatting. Definitions are stored verbatim with full metadata, enabling introspection, IDE tooling, and distributed system foundations without modifying existing code.

## Quick Start

```lisp
(ql:quickload :cl-sourcery)

;; Activate — all subsequent definitions are captured transparently
(cl-sourcery:activate)

;; Write normal CL code — nothing changes
(defun add (a b)
  "Add two numbers."
  ;; simple addition
  (+ a b))

;; Retrieve exact source (preserves whitespace, comments, formatting)
(cl-sourcery:get-source 'add)
;; => #S(SOURCE-ENTRY
;;      :FORM (DEFUN ADD (A B) "Add two numbers." (+ A B))
;;      :TEXT "(defun add (a b)
;;   \"Add two numbers.\"
;;   ;; simple addition
;;   (+ a b))"
;;      :TIMESTAMP 3987869235
;;      :PACKAGE "COMMON-LISP-USER"
;;      :FILE NIL
;;      :TYPE :FUNCTION)

;; Deactivate when done
(cl-sourcery:deactivate)
```

## Features

- **Zero-change adoption** — Activate once, all definitions in the image are captured. Existing libraries work unmodified.
- **Verbatim source text** — Preserves whitespace, comments, indentation exactly as written via custom readtable.
- **Two activation modes** — Non-conforming hijack mode (default) or fully conforming `*macroexpand-hook*` mode.
- **Full metadata** — Timestamp, package, source file, definition type.
- **All definition forms** — 13 standard CL forms captured (see table below).
- **Method-aware** — Methods keyed by `(name qualifiers . specializers)`.
- **Version history** — Optionally keep all versions of redefined symbols.
- **File scanner** — Extract definitions from source files without hijack active.
- **Hardened scanner** — Optional clean-readtable mode for scanning untrusted code.
- **Safe activation** — `activate`/`deactivate` cleanly install and restore state.

## Activation Modes

```lisp
;; Hijack mode (default) — replaces CL macros directly
;; Most reliable capture, but modifies the CL package (non-conforming)
(cl-sourcery:activate :mode :hijack)

;; Conforming mode — uses *macroexpand-hook*
;; Fully standards-conforming, no package modification
(cl-sourcery:activate :mode :conforming)
```

Both modes capture source text, support version history, and handle all 13 definition forms identically.

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
(cl-sourcery:activate)                   ;; Default hijack mode
(cl-sourcery:activate :mode :conforming) ;; Standards-conforming mode
(cl-sourcery:deactivate)                 ;; Restore originals
(cl-sourcery:active-p)                   ;; Check status
```

### Query

```lisp
(cl-sourcery:get-source 'my-function)          ;; Latest entry
(cl-sourcery:get-source 'my-gf :method)        ;; All method entries
(cl-sourcery:get-all-sources 'my-gf)           ;; All entries for symbol
(cl-sourcery:list-definitions)                  ;; All keys
(cl-sourcery:list-definitions :function)        ;; Filtered by type
(cl-sourcery:definition-count)                  ;; Count of keys
```

### Version History

```lisp
;; Enable history — redefinitions are kept, not overwritten
(setf cl-sourcery:*keep-history* t)

;; Retrieve all versions (most recent first)
(cl-sourcery:get-source-history 'my-function)
;; => (#S(SOURCE-ENTRY :FORM (DEFUN MY-FUNCTION ...) :TIMESTAMP 123 ...)
;;     #S(SOURCE-ENTRY :FORM (DEFUN MY-FUNCTION ...) :TIMESTAMP 100 ...))

;; get-source always returns the latest
(cl-sourcery:get-source 'my-function) ;; => latest entry
```

### Registry Management

```lisp
(cl-sourcery:clear-registry)              ;; Wipe all entries
(cl-sourcery:remove-source 'sym)          ;; Remove specific entry
(cl-sourcery:remove-source 'sym :method)  ;; Remove all methods for sym
```

### Entry Accessors

```lisp
(cl-sourcery:source-entry-form entry)       ;; Parsed source form (list)
(cl-sourcery:source-entry-text entry)       ;; Raw source text (string) with comments
(cl-sourcery:source-entry-timestamp entry)  ;; Universal-time of definition
(cl-sourcery:source-entry-package entry)    ;; Package name (string)
(cl-sourcery:source-entry-file entry)       ;; Source file path or NIL
(cl-sourcery:source-entry-type entry)       ;; Type keyword
```

## File Scanner

For code already loaded (without hijack active), extract source directly from files:

```lisp
(cl-sourcery:scan-file #P"my-file.lisp")             ;; Returns list of entries
(cl-sourcery:scan-file-to-registry #P"my-file.lisp") ;; Populates global registry
```

### Hardened Scanner

For scanning untrusted code, bind `*hardened-reader*` to prevent custom reader macros from executing:

```lisp
(let ((cl-sourcery:*hardened-reader* t))
  (cl-sourcery:scan-file #P"untrusted-library.lisp"))
```

### Extending the Scanner

```lisp
(push "define-application-frame" cl-sourcery:*extra-definition-forms*)
(push "define-command" cl-sourcery:*extra-definition-forms*)
```

## How It Works

### Hijack Mode

1. `activate` unlocks the CL package, saves original macro-functions
2. Installs new macro-functions that call the saved originals then register source
3. `deactivate` restores the saved originals and re-locks

### Conforming Mode

1. `activate` saves `*macroexpand-hook*` and installs `sourcery-macroexpand-hook`
2. The hook checks if the form is a definition, registers it, then delegates
3. A `*registering*` guard prevents double-registration from nested expansions
4. `deactivate` restores the previous hook

### Source Text Capture (both modes)

A custom readtable with a `(` reader macro reads the raw characters (tracking balanced parens, strings, comments, escapes), stores the text in `*last-source-text*`, then delegates to the standard reader. This preserves whitespace, comments, and formatting that the Lisp reader normally discards.

## Compatibility

Portable across CL implementations:

- **SBCL**, **CCL**, **ECL**, **LispWorks**, **Allegro CL**, **Clasp** — package lock abstraction provided
- **Conforming mode** — works on any implementation without package lock support
- **ABCL** and others — conforming mode works without any special handling

## Dependencies

None. Pure Common Lisp.

## Tests

```lisp
(ql:quickload :cl-sourcery-tests)
(fiveam:run! :cl-sourcery)
;; 183 checks, all passing
```

## License

MIT
