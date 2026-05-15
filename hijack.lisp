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
         (register-source ',name ',form ,type *last-source-text*)
         ,original-expansion))))

;;; --- Method specializer extraction ---

(defun extract-specializers (lambda-list)
  "Extract specializer names from a method lambda-list.
   (x (y string) (z integer)) => (T STRING INTEGER)"
  (mapcar (lambda (param)
            (cond
              ((member param lambda-list-keywords) (return-from extract-specializers nil))
              ((consp param) (cadr param))
              (t t)))
          (loop for p in lambda-list
                until (member p lambda-list-keywords)
                collect p)))

(defun extract-qualifiers-and-lambda-list (args)
  "From defmethod args after name, extract qualifiers and lambda-list.
   (:before (x string)) => (:before), (x string)
   ((x string)) => nil, (x string)"
  (let ((qualifiers '()))
    (loop for rest on args
          do (if (listp (car rest))
                 (return (values (nreverse qualifiers) (car rest)))
                 (push (car rest) qualifiers)))))

(defun make-method-hijack-expander (original-macro-fn)
  "Create a macro-function for defmethod that keys by (name qualifiers . specializers)."
  (lambda (form env)
    (let* ((name (cadr form))
           (rest (cddr form))
           (original-expansion (funcall original-macro-fn form env)))
      (multiple-value-bind (qualifiers lambda-list)
          (extract-qualifiers-and-lambda-list rest)
        (let ((specializers (extract-specializers lambda-list)))
          `(progn
             (register-source (method-key ',name '(,@qualifiers ,@specializers))
                              ',form :method *last-source-text*)
             ,original-expansion))))))

(defun make-struct-hijack-expander (original-macro-fn)
  "Create a macro-function for defstruct that extracts name from possibly-options form."
  (lambda (form env)
    (let* ((name-or-options (cadr form))
           (name (if (consp name-or-options)
                     (car name-or-options)
                     name-or-options))
           (original-expansion (funcall original-macro-fn form env)))
      `(progn
         (register-source ',name ',form :struct *last-source-text*)
         ,original-expansion))))

(defun make-defpackage-hijack-expander (original-macro-fn)
  "Create a macro-function for defpackage that keys by package keyword."
  (lambda (form env)
    (let* ((name (cadr form))
           (key (intern (string name) :keyword))
           (original-expansion (funcall original-macro-fn form env)))
      `(progn
         (register-source ,key ',form :package *last-source-text*)
         ,original-expansion))))

(defun make-compiler-macro-hijack-expander (original-macro-fn)
  "Create a macro-function for define-compiler-macro that keys by (name . :compiler-macro)."
  (lambda (form env)
    (let* ((name (cadr form))
           (key (cons name :compiler-macro))
           (original-expansion (funcall original-macro-fn form env)))
      `(progn
         (register-source ',key ',form :compiler-macro *last-source-text*)
         ,original-expansion))))

(defvar *original-readtable* nil
  "Saved readtable before activation.")

;;; --- Activation / Deactivation ---

(defun activate ()
  "Install hijack macros on CL definition forms and source-preserving readtable."
  (when *active*
    (return-from activate t))
  ;; Save original readtable
  (setf *original-readtable* *readtable*)
  ;; Install source-preserving readtable
  (setf *readtable* *sourcery-readtable*)
  ;; Save originals
  (dolist (sym '(cl:defun cl:defmacro cl:defvar cl:defparameter
                 cl:defgeneric cl:defmethod cl:defclass
                 cl:defconstant cl:defstruct cl:define-condition
                 cl:deftype cl:defpackage cl:define-compiler-macro))
    (setf (gethash sym *original-macro-functions*)
          (macro-function sym)))
  ;; Unlock CL package and install hijacks
  (unlock-cl-package)
  (setf (macro-function 'cl:defun)
        (make-hijack-expander (gethash 'cl:defun *original-macro-functions*) :function))
  (setf (macro-function 'cl:defmacro)
        (make-hijack-expander (gethash 'cl:defmacro *original-macro-functions*) :macro))
  (setf (macro-function 'cl:defvar)
        (make-hijack-expander (gethash 'cl:defvar *original-macro-functions*) :variable))
  (setf (macro-function 'cl:defparameter)
        (make-hijack-expander (gethash 'cl:defparameter *original-macro-functions*) :parameter))
  (setf (macro-function 'cl:defgeneric)
        (make-hijack-expander (gethash 'cl:defgeneric *original-macro-functions*) :generic))
  (setf (macro-function 'cl:defmethod)
        (make-method-hijack-expander (gethash 'cl:defmethod *original-macro-functions*)))
  (setf (macro-function 'cl:defclass)
        (make-hijack-expander (gethash 'cl:defclass *original-macro-functions*) :class))
  (setf (macro-function 'cl:defconstant)
        (make-hijack-expander (gethash 'cl:defconstant *original-macro-functions*) :constant))
  (setf (macro-function 'cl:defstruct)
        (make-struct-hijack-expander (gethash 'cl:defstruct *original-macro-functions*)))
  (setf (macro-function 'cl:define-condition)
        (make-hijack-expander (gethash 'cl:define-condition *original-macro-functions*) :condition))
  (setf (macro-function 'cl:deftype)
        (make-hijack-expander (gethash 'cl:deftype *original-macro-functions*) :type))
  (setf (macro-function 'cl:defpackage)
        (make-defpackage-hijack-expander (gethash 'cl:defpackage *original-macro-functions*)))
  (setf (macro-function 'cl:define-compiler-macro)
        (make-compiler-macro-hijack-expander (gethash 'cl:define-compiler-macro *original-macro-functions*)))
  (lock-cl-package)
  (setf *active* t))

(defun deactivate ()
  "Restore original CL macros and readtable."
  (unless *active*
    (return-from deactivate t))
  ;; Restore readtable
  (when *original-readtable*
    (setf *readtable* *original-readtable*))
  (unlock-cl-package)
  (dolist (sym '(cl:defun cl:defmacro cl:defvar cl:defparameter
                 cl:defgeneric cl:defmethod cl:defclass
                 cl:defconstant cl:defstruct cl:define-condition
                 cl:deftype cl:defpackage cl:define-compiler-macro))
    (let ((original (gethash sym *original-macro-functions*)))
      (when original
        (setf (macro-function sym) original))))
  (lock-cl-package)
  (setf *active* nil)
  t)
