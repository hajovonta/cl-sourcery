(in-package #:cl-sourcery)

;;; --- File Scanner ---
;;;
;;; Scans a source file and extracts all toplevel definition forms
;;; with their raw text preserved. Does not require hijack to be active.

(defun scan-file (pathname)
  "Scan PATHNAME for toplevel definition forms. Returns a list of source-entry structs.
Each entry has :text (raw source), :form (parsed), :type, and :file set.
Respects in-package forms to resolve symbols correctly."
  (let ((results '())
        (path (pathname pathname))
        (*package* *package*))
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
                               (let ((*read-eval* nil))
                                 (read-from-string text))
                             (error () nil))))
                 (cond
                   ;; in-package — switch *package* for subsequent reads
                   ((and form (consp form)
                         (string-equal (car form) "in-package"))
                    (let ((pkg (find-package (cadr form))))
                      (when pkg (setf *package* pkg))))
                   ;; Definition form — capture
                   ((and form (consp form) (definition-form-p (car form)))
                    (push (make-source-entry
                           :form form
                           :text text
                           :type (form-type (car form))
                           :file path
                           :timestamp (file-write-date path)
                           :package (package-name *package*))
                          results))
                   ;; Read failed but text looks like a definition — capture with partial info
                   ((and (null form) (text-looks-like-definition-p text))
                    (multiple-value-bind (type name) (extract-def-from-text text)
                      (when name
                        (push (make-source-entry
                               :form (list type name)
                               :text text
                               :type (form-type type)
                               :file path
                               :timestamp (file-write-date path)
                               :package (package-name *package*))
                              results))))
                   ;; Otherwise skip
                   (t nil)))))
            ;; Reader macro dispatch (#)
            ((char= ch #\#)
             (handler-case (read stream)
               (error () (read-char stream))))
            ;; Anything else — read and discard
            (t
             (handler-case (read stream)
               (error () (read-char stream))))))))
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

(defun definition-form-p (head)
  "Return T if HEAD names a definition form we should capture."
  (member head '(defun defmacro defgeneric defmethod defclass
                 defstruct defvar defparameter defconstant
                 deftype defpackage define-condition
                 define-compiler-macro define-method-combination)
          :test #'string-equal))

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
