(in-package #:cl-sourcery-tests)

(def-suite :hijack :in :cl-sourcery
  :description "Hijack macro installation and behavior tests")

(in-suite :hijack)

;;; --- Activation / Deactivation ---

(test activate-sets-active-p
  "activate makes active-p return T."
  (cl-sourcery:deactivate)
  (is (not (cl-sourcery:active-p)))
  (cl-sourcery:activate)
  (is (cl-sourcery:active-p))
  (cl-sourcery:deactivate))

(test deactivate-clears-active-p
  "deactivate makes active-p return NIL."
  (cl-sourcery:activate)
  (cl-sourcery:deactivate)
  (is (not (cl-sourcery:active-p))))

(test activate-is-idempotent
  "Calling activate twice doesn't break anything."
  (cl-sourcery:deactivate)
  (cl-sourcery:activate)
  (cl-sourcery:activate)
  (is (cl-sourcery:active-p))
  (cl-sourcery:deactivate))

(test deactivate-is-idempotent
  "Calling deactivate twice doesn't break anything."
  (cl-sourcery:activate)
  (cl-sourcery:deactivate)
  (cl-sourcery:deactivate)
  (is (not (cl-sourcery:active-p))))

;;; --- defun hijack ---

(test hijack-captures-defun
  "After activate, defun captures source in registry."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defun sourcery-test-fn-1 (a b) (+ a b)))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-fn-1)))
           (is (not (null entry)))
           (is (equal '(defun sourcery-test-fn-1 (a b) (+ a b))
                      (cl-sourcery:source-entry-form entry)))
           (is (eq :function (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-fn-1)))

(test hijack-defun-still-defines-function
  "Hijacked defun still creates a working function."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defun sourcery-test-fn-2 (x) (* x 2)))
         (is (= 10 (funcall 'sourcery-test-fn-2 5))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-fn-2)))

(test hijack-defun-with-docstring
  "Hijacked defun preserves docstring in both function and source."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defun sourcery-test-fn-3 (x) "Doubles X." (* x 2)))
         (is (string= "Doubles X." (documentation 'sourcery-test-fn-3 'function)))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-fn-3)))
           (is (equal '(defun sourcery-test-fn-3 (x) "Doubles X." (* x 2))
                      (cl-sourcery:source-entry-form entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-fn-3)))

(test hijack-defun-with-declarations
  "Hijacked defun preserves declare forms."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defun sourcery-test-fn-4 (x)
                  (declare (type integer x))
                  (1+ x)))
         (is (= 6 (funcall 'sourcery-test-fn-4 5)))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-fn-4)))
           (is (equal '(defun sourcery-test-fn-4 (x)
                         (declare (type integer x))
                         (1+ x))
                      (cl-sourcery:source-entry-form entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-fn-4)))

;;; --- defmacro hijack ---

(test hijack-captures-defmacro
  "After activate, defmacro captures source in registry."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defmacro sourcery-test-mac-1 (x) (list 'quote x)))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-mac-1)))
           (is (not (null entry)))
           (is (equal '(defmacro sourcery-test-mac-1 (x) (list 'quote x))
                      (cl-sourcery:source-entry-form entry)))
           (is (eq :macro (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-mac-1)))

(test hijack-defmacro-still-works
  "Hijacked defmacro creates a working macro."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defmacro sourcery-test-mac-2 (x) (list '+ x 1)))
         (is (= 6 (eval '(sourcery-test-mac-2 5)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-mac-2)))

;;; --- defvar hijack ---

(test hijack-captures-defvar
  "After activate, defvar captures source in registry."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defvar *sourcery-test-var-1* 42 "A test var"))
         (let ((entry (cl-sourcery:get-source '*sourcery-test-var-1*)))
           (is (not (null entry)))
           (is (equal '(defvar *sourcery-test-var-1* 42 "A test var")
                      (cl-sourcery:source-entry-form entry)))
           (is (eq :variable (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)
    (makunbound '*sourcery-test-var-1*)))

(test hijack-defvar-still-defines-variable
  "Hijacked defvar still creates the special variable."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defvar *sourcery-test-var-2* 99))
         (is (= 99 (symbol-value '*sourcery-test-var-2*))))
    (cl-sourcery:deactivate)
    (makunbound '*sourcery-test-var-2*)))

;;; --- defparameter hijack ---

(test hijack-captures-defparameter
  "After activate, defparameter captures source in registry."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defparameter *sourcery-test-param-1* "hello"))
         (let ((entry (cl-sourcery:get-source '*sourcery-test-param-1*)))
           (is (not (null entry)))
           (is (equal '(defparameter *sourcery-test-param-1* "hello")
                      (cl-sourcery:source-entry-form entry)))
           (is (eq :parameter (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)
    (makunbound '*sourcery-test-param-1*)))

(test hijack-defparameter-still-defines-variable
  "Hijacked defparameter still creates and sets the variable."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defparameter *sourcery-test-param-2* "world"))
         (is (string= "world" (symbol-value '*sourcery-test-param-2*))))
    (cl-sourcery:deactivate)
    (makunbound '*sourcery-test-param-2*)))

;;; --- Deactivation restores originals ---

(test deactivate-stops-capturing
  "After deactivate, defun no longer captures source."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (cl-sourcery:deactivate)
  (eval '(defun sourcery-test-fn-nocap () :not-captured))
  (is (null (cl-sourcery:get-source 'sourcery-test-fn-nocap)))
  (fmakunbound 'sourcery-test-fn-nocap))

(test deactivate-defun-still-works
  "After deactivate, defun still works normally."
  (cl-sourcery:activate)
  (cl-sourcery:deactivate)
  (eval '(defun sourcery-test-fn-normal () :works))
  (is (eq :works (funcall 'sourcery-test-fn-normal)))
  (fmakunbound 'sourcery-test-fn-normal))
