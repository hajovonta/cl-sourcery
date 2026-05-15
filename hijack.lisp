(in-package #:cl-sourcery)

;;; --- Hijack State ---

(defvar *active* nil "Whether hijack macros are currently installed.")
(defvar *original-macros* (make-hash-table :test 'eq)
  "Saved original macro-functions before hijacking.")

(defun active-p ()
  "Return whether cl-sourcery hijack is currently active."
  *active*)

;;; --- Activation / Deactivation ---

(defun activate ()
  "Install hijack macros on CL:DEFUN, CL:DEFMACRO, etc."
  (when *active*
    (return-from activate t))
  ;; Save originals and install — implementation in Phase 2
  (setf *active* t))

(defun deactivate ()
  "Restore original CL macros."
  (unless *active*
    (return-from deactivate t))
  ;; Restore originals — implementation in Phase 2
  (setf *active* nil)
  t)
