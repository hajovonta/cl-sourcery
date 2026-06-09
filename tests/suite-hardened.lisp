(in-package #:cl-sourcery-tests)

(def-suite :hardened-reader :in :cl-sourcery
  :description "Hardened reader mode tests")

(in-suite :hardened-reader)

(test hardened-blocks-custom-reader-macros
  "With *hardened-reader* T, custom readtable macros are not active during scan."
  ;; Install a dangerous reader macro on current readtable
  (let* ((dangerous-readtable (copy-readtable))
         (triggered nil))
    (set-macro-character #\! (lambda (stream char)
                               (declare (ignore stream char))
                               (setf triggered t)
                               :boom)
                         nil dangerous-readtable)
    ;; Write a file that contains ! which would trigger the macro
    (let ((tmp "/tmp/cl-sourcery-hardened-test.lisp"))
      (with-open-file (s tmp :direction :output :if-exists :supersede)
        (write-string "(defun hardened-test () :safe)" s))
      (unwind-protect
           (let ((*readtable* dangerous-readtable))
             ;; Without hardened mode — scanner uses current readtable (but ! isn't in a form here)
             ;; With hardened mode — uses clean readtable
             (let ((cl-sourcery:*hardened-reader* t))
               (let ((entries (cl-sourcery:scan-file tmp)))
                 (is (= 1 (length entries)))
                 (is (not triggered)))))
        (delete-file tmp)))))

(test hardened-still-parses-standard-code
  "Hardened mode still successfully parses normal CL code."
  (let ((tmp "/tmp/cl-sourcery-hardened-test2.lisp"))
    (with-open-file (s tmp :direction :output :if-exists :supersede)
      (format s "(in-package #:cl-user)~%")
      (format s "(defun hardened-fn (x) (+ x 1))~%")
      (format s "(defvar *hardened-var* 42)~%"))
    (unwind-protect
         (let ((cl-sourcery:*hardened-reader* t))
           (let ((entries (cl-sourcery:scan-file tmp)))
             (is (= 2 (length entries)))
             (is (eq :function (cl-sourcery:source-entry-type (first entries))))
             (is (eq :variable (cl-sourcery:source-entry-type (second entries))))))
      (delete-file tmp))))

(test hardened-default-off
  "*hardened-reader* defaults to NIL."
  (is (null cl-sourcery:*hardened-reader*)))
