(in-package #:cl-sourcery-tests)

(def-suite :scanner :in :cl-sourcery
  :description "Tests for the file scanner")

(in-suite :scanner)

(defvar *test-file* nil)

(defun make-test-file (content)
  (let ((path (merge-pathnames "cl-sourcery-scanner-test.lisp" (uiop:temporary-directory))))
    (with-open-file (out path :direction :output :if-exists :supersede)
      (write-string content out))
    path))

(test scan-file-finds-defun
  (let ((path (make-test-file "(in-package #:cl-user)

(defun foo (x) (+ x 1))

(defun bar (y) (* y 2))
")))
    (unwind-protect
         (let ((entries (scan-file path)))
           (is (= 2 (length entries)))
           (is (eq :function (source-entry-type (first entries))))
           (is (string= "FOO" (string (cadr (source-entry-form (first entries)))))))
      (delete-file path))))

(test scan-file-handles-character-literals
  (let ((path (make-test-file "(in-package #:cl-user)

(defun csv-parse (ch)
  (case ch
    (#\\\" :quote)
    (#\\, :comma)
    (#\\Newline :newline)
    (t :other)))
")))
    (unwind-protect
         (let ((entries (scan-file path)))
           (is (= 1 (length entries)))
           (is (search "#\\\"" (source-entry-text (first entries)))))
      (delete-file path))))

(test scan-file-handles-read-eval-fallback
  (let ((path (make-test-file "(in-package #:cl-user)

(defun uses-read-eval (x)
  (= x #.(+ 1 2)))
")))
    (unwind-protect
         (let ((entries (scan-file path)))
           (is (= 1 (length entries)))
           (is (search "defun uses-read-eval" (source-entry-text (first entries)))))
      (delete-file path))))

(test scan-file-extra-definition-forms
  (let ((*extra-definition-forms* (cons "my-defwidget" *extra-definition-forms*))
        (path (make-test-file "(in-package #:cl-user)

(my-defwidget fancy-button (base-widget)
  (:style :rounded))
")))
    (unwind-protect
         (let ((entries (scan-file path)))
           (is (= 1 (length entries)))
           (is (eq :other (source-entry-type (first entries))))
           (is (search "my-defwidget" (source-entry-text (first entries)))))
      (delete-file path))))

(test scan-file-to-registry-extra-forms
  (let ((*extra-definition-forms* (cons "my-defwidget" *extra-definition-forms*))
        (path (make-test-file "(in-package #:cl-user)

(my-defwidget fancy-button (base-widget)
  (:style :rounded))
")))
    (unwind-protect
         (progn
           (clear-registry)
           (scan-file-to-registry path)
           (is (= 1 (definition-count)))
           (is (not (null (get-source 'cl-user::fancy-button)))))
      (progn (clear-registry) (delete-file path)))))

(test scan-file-trailing-comment-preserved
  (let ((path (make-test-file "(in-package #:cl-user)

(defstruct point
  (x 0)
  (y 0)) ; 2D point
")))
    (unwind-protect
         (let ((entries (scan-file path)))
           (is (= 1 (length entries)))
           (is (search "; 2D point" (source-entry-text (first entries)))))
      (delete-file path))))

(test scan-file-vector-literal
  (let ((path (make-test-file "(in-package #:cl-user)

(defvar *table* #(1 2 3 4 5))

(defun next-fn () t)
")))
    (unwind-protect
         (let ((entries (scan-file path)))
           (is (= 2 (length entries)))
           (is (search "#(1 2 3 4 5)" (source-entry-text (first entries)))))
      (delete-file path))))
