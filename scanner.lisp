(in-package #:cl-sourcery)

;;; --- File Scanner ---
;;;
;;; Scans a source file and extracts all toplevel definition forms
;;; with their raw text preserved. Does not require hijack to be active.

(defun scan-file (pathname &key all-branches)
  "Scan PATHNAME for toplevel definition forms. Returns a list of source-entry structs.
Each entry has :text (raw source), :form (parsed), :type, and :file set.
Respects in-package forms to resolve symbols correctly.
When ALL-BRANCHES is true, scans twice — second pass uses a patched readtable
where #+ and #- always read both branches, capturing platform-guarded forms."
  (let ((results (scan-file-once pathname)))
    (if all-branches
        (handler-case
            (let* ((alt-results (scan-file-all-branches pathname))
                   (seen (make-hash-table :test 'equal)))
              (dolist (r results)
                (let ((key (entry-dedup-key r)))
                  (when key (setf (gethash key seen) t))))
              (dolist (r alt-results)
                (let ((key (entry-dedup-key r)))
                  (unless (or (null key) (gethash key seen))
                    (push r results))))
              results)
          (storage-condition () results))
        results)))

(defun entry-dedup-key (entry)
  "Lightweight dedup key: type + name of defined symbol. Avoids printing deep forms."
  (let ((form (source-entry-form entry)))
    (when (and (consp form) (consp (cdr form)))
      (let ((name (cadr form)))
        (format nil "~A:~A" (source-entry-type entry)
                (if (consp name) (car name) name))))))

(defun make-all-branches-readtable ()
  "Create a readtable where #+ and #- always read the form (never skip).
The feature expression is read and discarded."
  (let ((rt (copy-readtable nil)))
    (set-dispatch-macro-character #\# #\+
      (lambda (stream char n)
        (declare (ignore char n))
        (read stream t nil t)
        (read stream t nil t))
      rt)
    (set-dispatch-macro-character #\# #\-
      (lambda (stream char n)
        (declare (ignore char n))
        (read stream t nil t)
        (read stream t nil t))
      rt)
    rt))

(defun scan-file-all-branches (pathname)
  "Scan with patched readtable that captures all #+/- branches."
  (let ((*readtable* (make-all-branches-readtable)))
    (scan-file-once pathname)))

(defun preamble-form-p (form)
  "Return T if FORM is a preamble candidate — a toplevel form that should be attached to the next definition.
Covers declaim, eval-when, and print-object methods."
  (when (consp form)
    (or (string-equal (car form) "declaim")
        (string-equal (car form) "eval-when")
        (and (string-equal (car form) "defmethod")
             (>= (length form) 3)
             (string-equal (second form) "print-object")))))

(defun scan-file-once (pathname)
  "Single-pass scan of PATHNAME for toplevel definition forms.
Preamble forms (declaim, eval-when, print-object methods) immediately preceding a definition
are captured in the source-entry's preamble slot."
  (let ((results '())
        (path (pathname pathname))
        (*package* *package*)
        (pending-preamble nil))
    (with-open-file (stream path :direction :input)
      (loop
        (skip-whitespace-and-comments stream)
        (let ((ch (peek-char nil stream nil nil)))
          (unless ch (return))
          (cond
            ;; List form — potential definition
            ((char= ch #\()
             (read-char stream) ; consume the (
             (let ((text (read-balanced-form stream)))
               (let ((form (handler-case
                               (let ((*read-eval* nil)
                                     (*readtable* (if *hardened-reader*
                                                      (copy-readtable nil)
                                                      *readtable*)))
                                 (read-from-string text))
                             (error () nil))))
                 (cond
                   ;; in-package — switch *package* for subsequent reads
                   ((and form (consp form)
                         (symbolp (car form))
                         (string-equal (car form) "in-package"))
                    (let ((pkg (find-package (cadr form))))
                      (when pkg (setf *package* pkg)))
                    (setf pending-preamble nil))
                   ;; Definition form — capture (with any pending preamble)
                   ((and form (consp form)
                         (symbolp (car form))
                         (definition-form-p (car form)))
                    (push (make-source-entry
                           :form form
                           :text text
                           :preamble pending-preamble
                           :type (form-type (car form))
                           :file path
                           :timestamp (file-write-date path)
                           :package (package-name *package*))
                          results)
                    (setf pending-preamble nil))
                   ;; Read failed but text looks like a definition — capture with partial info
                   ((and (null form) (text-looks-like-definition-p text))
                    (multiple-value-bind (type name) (extract-def-from-text text)
                      (when name
                        (push (make-source-entry
                               :form (list type name)
                               :text text
                               :preamble pending-preamble
                               :type (form-type type)
                               :file path
                               :timestamp (file-write-date path)
                               :package (package-name *package*))
                              results)))
                    (setf pending-preamble nil))
                   ;; Preamble candidate — buffer for next definition
                   ((preamble-form-p form)
                    (setf pending-preamble
                          (if pending-preamble
                              (concatenate 'string pending-preamble (string #\Newline) text)
                              text)))
                   ;; Otherwise skip (flush preamble — unrelated form breaks the chain)
                   (t (setf pending-preamble nil))))))
            ;; Reader macro dispatch (#)
            ((char= ch #\#)
             (let ((form (handler-case
                             (let ((*read-eval* nil))
                               (read stream nil nil))
                           (error () nil))))
               (when (consp form)
                 (cond
                   ;; Direct definition after reader conditional: #+feat (defun ...)
                   ((and (symbolp (car form))
                         (definition-form-p (car form)))
                    (push (make-source-entry
                           :form form
                           :text nil
                           :preamble pending-preamble
                           :type (form-type (car form))
                           :file path
                           :timestamp (file-write-date path)
                           :package (package-name *package*))
                          results)
                    (setf pending-preamble nil))
                   ;; progn wrapping definitions: #+feat (progn (defun ...) ...)
                   ((and (symbolp (car form))
                         (string-equal (car form) "progn"))
                    (dolist (subform (cdr form))
                      (when (and (consp subform)
                                 (symbolp (car subform)))
                        (cond
                          ((string-equal (car subform) "in-package")
                           (let ((pkg (find-package (cadr subform))))
                             (when pkg (setf *package* pkg))))
                          ((definition-form-p (car subform))
                           (push (make-source-entry
                                  :form subform
                                  :text nil
                                  :preamble pending-preamble
                                  :type (form-type (car subform))
                                  :file path
                                  :timestamp (file-write-date path)
                                  :package (package-name *package*))
                                 results)))))
                    (setf pending-preamble nil))))))
            ;; Anything else — read and discard
            (t
             (handler-case (let ((*read-eval* nil))
                             (read stream nil nil))
               (error () (read-char stream nil nil)))
             (setf pending-preamble nil))))))
    (nreverse results)))

(defun skip-whitespace-and-comments (stream)
  "Skip whitespace and ;-comments in STREAM."
  (loop
    (let ((ch (peek-char nil stream nil nil)))
      (unless ch (return))
      (cond
        ((member ch '(#\Space #\Tab #\Newline #\Return))
         (read-char stream))
        ((char= ch #\;)
         ;; Skip to end of line
         (read-line stream nil nil))
        (t (return))))))

(defvar *extra-definition-forms* '("define-constant")
  "Additional definition form names to recognize during scanning.
Push form names (strings, case-insensitive) to extend the scanner:
  (push \"define-application-frame\" cl-sourcery:*extra-definition-forms*)
Forms listed here are treated like defun — the second element is the name.")

(defvar *hardened-reader* nil
  "When T, scan-file binds *readtable* to (copy-readtable nil) during read-from-string,
preventing custom reader macros from executing. Use when scanning untrusted code.")

(defun definition-form-p (head)
  "Return T if HEAD names a definition form we should capture."
  (or (member head '(defun defmacro defgeneric defmethod defclass
                     defstruct defvar defparameter defconstant
                     deftype defpackage define-condition
                     define-compiler-macro define-method-combination)
              :test #'string-equal)
      (member (string head) *extra-definition-forms* :test #'string-equal)))

(defun form-type (head)
  "Map a definition form head to a keyword type."
  (cond
    ((string-equal head "defun") :function)
    ((string-equal head "defmacro") :macro)
    ((string-equal head "defgeneric") :generic)
    ((string-equal head "defmethod") :method)
    ((string-equal head "defclass") :class)
    ((string-equal head "defstruct") :struct)
    ((string-equal head "defvar") :variable)
    ((string-equal head "defparameter") :parameter)
    ((string-equal head "defconstant") :constant)
    ((string-equal head "deftype") :type)
    ((string-equal head "defpackage") :package)
    ((string-equal head "define-condition") :condition)
    ((string-equal head "define-compiler-macro") :compiler-macro)
    ((string-equal head "define-constant") :constant)
    (t :other)))

(defun scan-file-to-registry (pathname &optional (package *package*))
  "Scan PATHNAME and register all found definitions in the global registry.
Uses PACKAGE as the initial package for symbol resolution during read."
  (let ((*package* (or (find-package package) *package*))
        (count 0))
    (dolist (entry (scan-file pathname))
      (let* ((form (source-entry-form entry))
             (key (definition-key (car form) (cdr form))))
        (when key
          (setf (gethash key *registry*) entry)
          (incf count))))
    count))

(defun definition-key (head args)
  "Extract the registry key for a definition form."
  (let ((name (string head)))
    (cond
      ((member name '("DEFUN" "DEFMACRO" "DEFGENERIC" "DEFCLASS" "DEFTYPE"
                       "DEFVAR" "DEFPARAMETER" "DEFCONSTANT" "DEFINE-CONDITION")
               :test #'string-equal)
       (car args))
      ((string-equal name "DEFSTRUCT")
       (let ((name-or-opts (car args)))
         (if (consp name-or-opts) (car name-or-opts) name-or-opts)))
      ((string-equal name "DEFMETHOD")
       (let ((mname (car args)))
         (multiple-value-bind (qualifiers lambda-list)
             (extract-qualifiers-and-lambda-list (cdr args))
           (let ((specs (extract-specializers lambda-list)))
             (method-key mname (append qualifiers specs))))))
      ((string-equal name "DEFPACKAGE")
       (intern (string (car args)) :keyword))
      ((string-equal name "DEFINE-COMPILER-MACRO")
       (cons (car args) :compiler-macro))
      ;; Extra user-registered forms — default to (car args) as key
      ((member name *extra-definition-forms* :test #'string-equal)
       (car args))
      (t nil))))

(defun text-looks-like-definition-p (text)
  "Check if TEXT starts with a known definition form keyword."
  (and (> (length text) 5)
       (char= (char text 0) #\()
       (let ((space (position #\Space text)))
         (when space
           (definition-form-p (subseq text 1 space))))))

(defun extract-def-from-text (text)
  "Extract the definition type symbol and name symbol from raw text.
Returns (values type-symbol name-symbol) or NIL."
  (let* ((space1 (position #\Space text))
         (head (when space1 (subseq text 1 space1)))
         (rest-start (when space1 (position-if-not (lambda (c) (member c '(#\Space #\Newline #\Tab #\Return)))
                                                   text :start (1+ space1)))))
    (when (and head rest-start)
      (let* ((name-end (position-if (lambda (c) (member c '(#\Space #\( #\Newline #\Tab #\Return)))
                                    text :start rest-start))
             (name-str (subseq text rest-start (or name-end (length text))))
             (type-sym (intern (string-upcase head) :cl))
             (name-sym (intern (string-upcase name-str) *package*)))
        (values type-sym name-sym)))))
