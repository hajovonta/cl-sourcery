(in-package #:cl-sourcery)

;;; --- Hijack State ---

(defvar *active* nil "Whether hijack macros are currently installed.")
(defvar *original-macro-functions* (make-hash-table :test 'eq)
  "Saved original macro-functions before hijacking.")

(defun active-p ()
  "Return whether cl-sourcery hijack is currently active."
  *active*)

;;; --- Hijack macro builder ---
;;; We can't use (cl:defun ...) in the expansion because cl:defun IS our hijack.
;;; Instead, we funcall the saved original macro-function to get the expansion,
;;; then splice that expansion together with our registration call.

(defun make-hijack-expander (original-macro-fn type)
  "Create a macro-function that captures source then delegates to ORIGINAL-MACRO-FN."
  (lambda (form env)
    (let* ((name (cadr form))
           (original-expansion (funcall original-macro-fn form env)))
      `(progn
         (register-source ',name ',form ,type)
         ,original-expansion))))

;;; --- Activation / Deactivation ---

(defun activate ()
  "Install hijack macros on CL:DEFUN, CL:DEFMACRO, CL:DEFVAR, CL:DEFPARAMETER."
  (when *active*
    (return-from activate t))
  ;; Save originals
  (dolist (sym '(cl:defun cl:defmacro cl:defvar cl:defparameter))
    (setf (gethash sym *original-macro-functions*)
          (macro-function sym)))
  ;; Unlock CL package and install hijacks
  (sb-ext:unlock-package :cl)
  (setf (macro-function 'cl:defun)
        (make-hijack-expander (gethash 'cl:defun *original-macro-functions*) :function))
  (setf (macro-function 'cl:defmacro)
        (make-hijack-expander (gethash 'cl:defmacro *original-macro-functions*) :macro))
  (setf (macro-function 'cl:defvar)
        (make-hijack-expander (gethash 'cl:defvar *original-macro-functions*) :variable))
  (setf (macro-function 'cl:defparameter)
        (make-hijack-expander (gethash 'cl:defparameter *original-macro-functions*) :parameter))
  (sb-ext:lock-package :cl)
  (setf *active* t))

(defun deactivate ()
  "Restore original CL macros."
  (unless *active*
    (return-from deactivate t))
  (sb-ext:unlock-package :cl)
  (dolist (sym '(cl:defun cl:defmacro cl:defvar cl:defparameter))
    (let ((original (gethash sym *original-macro-functions*)))
      (when original
        (setf (macro-function sym) original))))
  (sb-ext:lock-package :cl)
  (setf *active* nil)
  t)
