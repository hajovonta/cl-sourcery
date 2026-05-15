(in-package #:cl-sourcery-tests)

(def-suite :more-forms :in :cl-sourcery
  :description "Additional definition form hijack tests")

(in-suite :more-forms)

;;; --- defconstant ---

(test hijack-captures-defconstant
  "After activate, defconstant captures source."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defconstant +sourcery-test-const-1+ 3.14))
         (let ((entry (cl-sourcery:get-source '+sourcery-test-const-1+)))
           (is (not (null entry)))
           (is (equal '(defconstant +sourcery-test-const-1+ 3.14)
                      (cl-sourcery:source-entry-form entry)))
           (is (eq :constant (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)))

(test hijack-defconstant-still-works
  "Hijacked defconstant still defines the constant."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defconstant +sourcery-test-const-2+ 99))
         (is (= 99 (symbol-value '+sourcery-test-const-2+))))
    (cl-sourcery:deactivate)))

;;; --- defstruct ---

(test hijack-captures-defstruct
  "After activate, defstruct captures source."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defstruct sourcery-test-struct-1
                  (x 0)
                  (y 0)))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-struct-1)))
           (is (not (null entry)))
           (is (equal '(defstruct sourcery-test-struct-1 (x 0) (y 0))
                      (cl-sourcery:source-entry-form entry)))
           (is (eq :struct (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)))

(test hijack-defstruct-still-works
  "Hijacked defstruct creates a usable struct."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defstruct sourcery-test-struct-2 (val 42)))
         (let ((obj (eval '(make-sourcery-test-struct-2))))
           (is (= 42 (eval `(sourcery-test-struct-2-val ,obj))))))
    (cl-sourcery:deactivate)))

(test hijack-defstruct-with-options
  "defstruct with options is captured correctly."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defstruct (sourcery-test-struct-3 (:conc-name st3-))
                  (name "unnamed")))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-struct-3)))
           (is (equal '(defstruct (sourcery-test-struct-3 (:conc-name st3-))
                         (name "unnamed"))
                      (cl-sourcery:source-entry-form entry)))))
    (cl-sourcery:deactivate)))

;;; --- define-condition ---

(test hijack-captures-define-condition
  "After activate, define-condition captures source."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(define-condition sourcery-test-cond-1 (error)
                  ((msg :initarg :msg :reader cond1-msg))
                  (:report (lambda (c s) (format s "~a" (cond1-msg c))))))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-cond-1)))
           (is (not (null entry)))
           (is (eq :condition (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)))

(test hijack-define-condition-still-works
  "Hijacked define-condition creates a signalable condition."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(define-condition sourcery-test-cond-2 (error)
                  ((info :initarg :info :reader cond2-info))))
         (is (subtypep 'sourcery-test-cond-2 'error)))
    (cl-sourcery:deactivate)))

;;; --- deftype ---

(test hijack-captures-deftype
  "After activate, deftype captures source."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(deftype sourcery-test-type-1 ()
                  '(integer 0 100)))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-type-1)))
           (is (not (null entry)))
           (is (eq :type (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)))

(test hijack-deftype-still-works
  "Hijacked deftype creates a usable type."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(deftype sourcery-test-type-2 ()
                  '(or string symbol)))
         (is (typep "hello" 'sourcery-test-type-2))
         (is (typep 'foo 'sourcery-test-type-2))
         (is (not (typep 42 'sourcery-test-type-2))))
    (cl-sourcery:deactivate)))

;;; --- defpackage ---

(test hijack-captures-defpackage
  "After activate, defpackage captures source."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defpackage #:sourcery-test-pkg-1
                  (:use #:cl)
                  (:export #:foo)))
         (let ((entry (cl-sourcery:get-source :sourcery-test-pkg-1)))
           (is (not (null entry)))
           (is (eq :package (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)
    (delete-package :sourcery-test-pkg-1)))

(test hijack-defpackage-still-works
  "Hijacked defpackage creates a usable package."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defpackage #:sourcery-test-pkg-2 (:use #:cl)))
         (is (find-package :sourcery-test-pkg-2)))
    (cl-sourcery:deactivate)
    (delete-package :sourcery-test-pkg-2)))

;;; --- define-compiler-macro ---

(test hijack-captures-define-compiler-macro
  "After activate, define-compiler-macro captures source."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defun sourcery-test-cm-fn (x) (+ x 1)))
         (eval '(define-compiler-macro sourcery-test-cm-fn (&whole form x)
                  (if (constantp x)
                      (+ (eval x) 1)
                      form)))
         ;; Compiler macro keyed by (name . :compiler-macro)
         (let ((entry (gethash '(sourcery-test-cm-fn . :compiler-macro)
                               cl-sourcery::*registry*)))
           (is (not (null entry)))
           (is (eq :compiler-macro (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-cm-fn)))
