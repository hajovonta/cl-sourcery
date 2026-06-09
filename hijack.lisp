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

(defvar *activation-mode* nil
  "The mode used for activation: :hijack or :conforming.")

(defvar *original-macroexpand-hook* nil
  "Saved *macroexpand-hook* before conforming mode activation.")

(defvar *registering* nil
  "Guard against re-entrant registration during nested macroexpansion.")

;;; --- Conforming mode (macroexpand-hook) ---

(defun definition-form-head-p (sym)
  "Return the type keyword if SYM names a definition form, or NIL."
  (case sym
    (cl:defun :function)
    (cl:defmacro :macro)
    (cl:defvar :variable)
    (cl:defparameter :parameter)
    (cl:defconstant :constant)
    (cl:defgeneric :generic)
    (cl:defmethod :method)
    (cl:defclass :class)
    (cl:defstruct :struct)
    (cl:define-condition :condition)
    (cl:deftype :type)
    (cl:defpackage :package)
    (cl:define-compiler-macro :compiler-macro)
    (t nil)))

(defun extract-definition-key (form type)
  "Extract the registry key from a definition FORM given its TYPE."
  (case type
    (:method
     (let ((name (cadr form))
           (rest (cddr form)))
       (multiple-value-bind (qualifiers lambda-list)
           (extract-qualifiers-and-lambda-list rest)
         (let ((specs (extract-specializers lambda-list)))
           (method-key name (append qualifiers specs))))))
    (:struct
     (let ((name-or-opts (cadr form)))
       (if (consp name-or-opts) (car name-or-opts) name-or-opts)))
    (:package
     (intern (string (cadr form)) :keyword))
    (:compiler-macro
     (cons (cadr form) :compiler-macro))
    (t (cadr form))))

(defun sourcery-macroexpand-hook (expander form env)
  "Macroexpand hook that intercepts definition forms and registers source."
  (let ((expansion (funcall expander form env)))
    (when (and (not *registering*) (consp form))
      (let ((type (definition-form-head-p (car form))))
        (when type
          (let ((*registering* t))
            (let ((key (extract-definition-key form type)))
              (when key
                (register-source key form type *last-source-text*)))))))
    expansion))

;;; --- Activation / Deactivation ---

(defun activate (&key (mode :hijack))
  "Install source capture. MODE is :hijack (default) or :conforming."
  (when *active*
    (return-from activate t))
  ;; Save original readtable and install source-preserving one
  (setf *original-readtable* *readtable*)
  (setf *readtable* *sourcery-readtable*)
  (setf *activation-mode* mode)
  (ecase mode
    (:hijack
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
     (lock-cl-package))
    (:conforming
     (setf *original-macroexpand-hook* *macroexpand-hook*)
     (setf *macroexpand-hook* #'sourcery-macroexpand-hook)))
  (setf *active* t))

(defun deactivate ()
  "Restore original CL macros/hook and readtable."
  (unless *active*
    (return-from deactivate t))
  ;; Restore readtable
  (when *original-readtable*
    (setf *readtable* *original-readtable*))
  (ecase *activation-mode*
    (:hijack
     (unlock-cl-package)
     (dolist (sym '(cl:defun cl:defmacro cl:defvar cl:defparameter
                    cl:defgeneric cl:defmethod cl:defclass
                    cl:defconstant cl:defstruct cl:define-condition
                    cl:deftype cl:defpackage cl:define-compiler-macro))
       (let ((original (gethash sym *original-macro-functions*)))
         (when original
           (setf (macro-function sym) original))))
     (lock-cl-package))
    (:conforming
     (setf *macroexpand-hook* (or *original-macroexpand-hook* #'funcall))))
  (setf *active* nil)
  (setf *activation-mode* nil)
  t)
