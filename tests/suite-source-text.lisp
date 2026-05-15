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
