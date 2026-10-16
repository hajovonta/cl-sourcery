(in-package #:cl-sourcery-tests)

(def-suite :source-text :in :cl-sourcery
  :description "Source text preservation tests")

(in-suite :source-text)

;;; --- Basic text capture ---

(test text-preserves-whitespace
  "Source text preserves original whitespace/indentation."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (let ((source "(defun sourcery-ws-test (a b)
  \"Add two numbers.\"
  (+ a b))"))
         (eval (read-from-string source))
         (let ((entry (cl-sourcery:get-source 'sourcery-ws-test)))
           (is (not (null entry)))
           (is (string= source (cl-sourcery:source-entry-text entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-ws-test)))

(test text-preserves-comments
  "Source text preserves inline comments."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (let ((source "(defun sourcery-comment-test (x)
  ;; double the input
  (* x 2))"))
         (eval (read-from-string source))
         (let ((entry (cl-sourcery:get-source 'sourcery-comment-test)))
           (is (not (null entry)))
           (is (string= source (cl-sourcery:source-entry-text entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-comment-test)))

(test text-preserves-block-comments
  "Source text preserves #| ... |# block comments."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (let ((source "(defun sourcery-block-comment-test (x)
  #| This is a
     block comment |#
  x)"))
         (eval (read-from-string source))
         (let ((entry (cl-sourcery:get-source 'sourcery-block-comment-test)))
           (is (not (null entry)))
           (is (string= source (cl-sourcery:source-entry-text entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-block-comment-test)))

(test text-preserves-strings-with-parens
  "Source text handles strings containing parentheses correctly."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (let ((source "(defun sourcery-paren-str-test ()
  \"Returns a string with (parens) inside\")"))
         (eval (read-from-string source))
         (let ((entry (cl-sourcery:get-source 'sourcery-paren-str-test)))
           (is (not (null entry)))
           (is (string= source (cl-sourcery:source-entry-text entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-paren-str-test)))

(test text-preserves-escaped-chars
  "Source text handles escaped characters in strings."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (let ((source "(defun sourcery-escape-test ()
  \"A string with \\\"quotes\\\" inside\")"))
         (eval (read-from-string source))
         (let ((entry (cl-sourcery:get-source 'sourcery-escape-test)))
           (is (not (null entry)))
           (is (string= source (cl-sourcery:source-entry-text entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-escape-test)))

(test text-captured-for-defclass
  "Source text captured for defclass."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (let ((source "(defclass sourcery-text-cls ()
  ((name :initarg :name
         :accessor cls-name)
   ;; Age in years
   (age :initarg :age)))"))
         (eval (read-from-string source))
         (let ((entry (cl-sourcery:get-source 'sourcery-text-cls)))
           (is (not (null entry)))
           (is (string= source (cl-sourcery:source-entry-text entry)))))
    (cl-sourcery:deactivate)))

(test text-nil-when-not-available
  "Source text is NIL when registered without text (e.g. direct register-source call)."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source 'no-text-sym '(defun no-text-sym () nil) :function)
  (let ((entry (cl-sourcery:get-source 'no-text-sym)))
    (is (null (cl-sourcery:source-entry-text entry)))))

(test text-from-stream-input
  "Source text captured when reading from a stream (simulating file load)."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (let ((source "(defun sourcery-stream-test (x)
  ;; from a stream
  (1+ x))"))
         (with-input-from-string (s source)
           (let ((*readtable* cl-sourcery::*sourcery-readtable*))
             (eval (read s))))
         (let ((entry (cl-sourcery:get-source 'sourcery-stream-test)))
           (is (not (null entry)))
           (is (string= source (cl-sourcery:source-entry-text entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-stream-test)))

;;; --- source-entry-from-text (in-memory, no file) ---

(test from-text-builds-entry-matching-fields
  "source-entry-from-text builds an entry matching text/form/type/file/package."
  (let* ((text "(defun f (x) (eval x))")
         (entry (cl-sourcery:source-entry-from-text text :file "my-uri" :package "CL-USER")))
    (is (string= text (cl-sourcery:source-entry-text entry)))
    (is (equal '(defun f (x) (eval x)) (cl-sourcery:source-entry-form entry)))
    (is (eq :function (cl-sourcery:source-entry-type entry)))
    (is (equal "my-uri" (cl-sourcery:source-entry-file entry)))
    (is (equal "CL-USER" (cl-sourcery:source-entry-package entry)))))

(test from-text-defaults-file-and-package
  "source-entry-from-text defaults :file to a placeholder and :package to *package*."
  (let* ((text "(defvar *x* 1)")
         (entry (cl-sourcery:source-entry-from-text text)))
    (is (equal "<in-memory>" (cl-sourcery:source-entry-file entry)))
    (is (string= (package-name *package*) (cl-sourcery:source-entry-package entry)))))

(test from-text-unparseable-text-keeps-text-nil-form
  "source-entry-from-text tolerates unparseable TEXT (nil form/type, text preserved)."
  (let* ((text "(defun broken (")
         (entry (cl-sourcery:source-entry-from-text text)))
    (is (string= text (cl-sourcery:source-entry-text entry)))
    (is (null (cl-sourcery:source-entry-form entry)))
    (is (null (cl-sourcery:source-entry-type entry)))))

(test from-text-matches-scan-file-on-same-source
  "source-entry-from-text produces the same form/type/text as scanning an equivalent file."
  (let* ((source "(defun sourcery-from-text-cmp (x) (+ x 1))")
         (tmp (merge-pathnames "cl-sourcery-from-text-cmp.lisp" (uiop:temporary-directory))))
    (with-open-file (out tmp :direction :output :if-exists :supersede)
      (write-string source out))
    (unwind-protect
         (let ((file-entry (first (cl-sourcery:scan-file tmp)))
               (text-entry (cl-sourcery:source-entry-from-text source)))
           (is (equal (cl-sourcery:source-entry-form file-entry)
                      (cl-sourcery:source-entry-form text-entry)))
           (is (eq (cl-sourcery:source-entry-type file-entry)
                   (cl-sourcery:source-entry-type text-entry)))
           (is (string= (cl-sourcery:source-entry-text file-entry)
                        (cl-sourcery:source-entry-text text-entry))))
      (delete-file tmp))))
