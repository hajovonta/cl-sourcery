(in-package #:cl-sourcery)

;;; --- Data Structures ---

(defstruct source-entry
  "A captured definition."
  (form nil :type list)
  (text nil :type (or null string))
  (timestamp 0 :type integer)
  (package "" :type string)
  (file nil :type (or null pathname string))
  (type nil :type (or null keyword)))

;;; --- Storage ---

;; For defun, defmacro, defvar, defparameter, defgeneric: symbol → source-entry
;; For defmethod: (symbol . specializers) → source-entry
(defvar *registry* (make-hash-table :test 'equal)
  "Global registry of captured source definitions.")

;;; --- Internal API ---

(defun register-source (key form type &optional text)
  "Store a source entry in the registry."
  (setf (gethash key *registry*)
        (make-source-entry
         :form form
         :text text
         :timestamp (get-universal-time)
         :package (package-name *package*)
         :file (or *compile-file-pathname* *load-pathname*)
         :type type)))

(defun method-key (name specializers)
  "Create a registry key for a method: (name . specializers)."
  (cons name specializers))

;;; --- Public Query API ---

(defun get-source (symbol &optional type)
  "Get the source entry for SYMBOL. If TYPE is :method, returns a list of all method entries."
  (if (eq type :method)
      (loop for key being the hash-keys of *registry*
            using (hash-value entry)
            when (and (consp key)
                      (eq (car key) symbol)
                      (eq (source-entry-type entry) :method))
            collect entry)
      (gethash (if type
                   symbol
                   symbol)
               *registry*)))

(defun get-all-sources (symbol)
  "Get all source entries for SYMBOL across all types (including methods)."
  (let ((results '()))
    ;; Direct entry (defun, defmacro, defvar, defparameter, defgeneric)
    (let ((entry (gethash symbol *registry*)))
      (when entry (push entry results)))
    ;; Method entries
    (loop for key being the hash-keys of *registry*
          using (hash-value entry)
          when (and (consp key) (eq (car key) symbol))
          do (push entry results))
    (nreverse results)))

(defun list-definitions (&optional type)
  "List all registered definition keys. If TYPE given, filter by type."
  (let ((results '()))
    (maphash (lambda (key entry)
               (when (or (null type)
                         (eq (source-entry-type entry) type))
                 (push key results)))
             *registry*)
    (nreverse results)))

(defun definition-count ()
  "Return the number of stored definitions."
  (hash-table-count *registry*))

(defun clear-registry ()
  "Remove all stored definitions."
  (clrhash *registry*)
  nil)

(defun remove-source (symbol &optional type)
  "Remove a source entry. Returns T if something was removed."
  (if (eq type :method)
      (let ((removed nil))
        (maphash (lambda (key entry)
                   (when (and (consp key)
                              (eq (car key) symbol)
                              (eq (source-entry-type entry) :method))
                     (remhash key *registry*)
                     (setf removed t)))
                 *registry*)
        removed)
      (when (gethash symbol *registry*)
        (remhash symbol *registry*)
        t)))
