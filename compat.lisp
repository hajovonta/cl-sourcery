(in-package #:cl-sourcery)

;;; --- Portable package lock/unlock ---
;;;
;;; Abstracts implementation-specific package locking mechanisms.

(defun unlock-cl-package ()
  "Unlock the COMMON-LISP package to allow macro redefinition."
  #+sbcl (sb-ext:unlock-package :cl)
  #+ccl (setf (ccl:package-lock :cl) nil)
  #+ecl (ext:package-lock :cl nil)
  #+lispworks (hcl:set-package-lock :cl nil)
  #+allegro (setf (excl:package-lock :cl) nil)
  #+clasp (ext:package-lock :cl nil)
  #-(or sbcl ccl ecl lispworks allegro clasp)
  (warn "cl-sourcery: no known package lock mechanism for this implementation"))

(defun lock-cl-package ()
  "Re-lock the COMMON-LISP package."
  #+sbcl (sb-ext:lock-package :cl)
  #+ccl (setf (ccl:package-lock :cl) t)
  #+ecl (ext:package-lock :cl t)
  #+lispworks (hcl:set-package-lock :cl t)
  #+allegro (setf (excl:package-lock :cl) t)
  #+clasp (ext:package-lock :cl t)
  #-(or sbcl ccl ecl lispworks allegro clasp)
  nil)
