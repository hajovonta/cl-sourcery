(in-package #:cl-sourcery-tests)

(def-suite :methods :in :cl-sourcery
  :description "defgeneric and defmethod hijack tests")

(in-suite :methods)

;;; --- defgeneric ---

(test hijack-captures-defgeneric
  "After activate, defgeneric captures source in registry."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defgeneric sourcery-test-gf-1 (x)
                  (:documentation "A test GF")))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-gf-1)))
           (is (not (null entry)))
           (is (equal '(defgeneric sourcery-test-gf-1 (x)
                         (:documentation "A test GF"))
                      (cl-sourcery:source-entry-form entry)))
           (is (eq :generic (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-gf-1)))

(test hijack-defgeneric-still-works
  "Hijacked defgeneric creates a working generic function."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defgeneric sourcery-test-gf-2 (x)))
         (is (typep (fdefinition 'sourcery-test-gf-2) 'generic-function)))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-gf-2)))

;;; --- defmethod ---

(test hijack-captures-defmethod
  "After activate, defmethod captures source keyed by specializers."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defgeneric sourcery-test-gf-3 (x)))
         (eval '(defmethod sourcery-test-gf-3 ((x string))
                  (concatenate 'string "hello " x)))
         (let ((entries (cl-sourcery:get-source 'sourcery-test-gf-3 :method)))
           (is (= 1 (length entries)))
           (is (equal '(defmethod sourcery-test-gf-3 ((x string))
                         (concatenate 'string "hello " x))
                      (cl-sourcery:source-entry-form (first entries))))
           (is (eq :method (cl-sourcery:source-entry-type (first entries))))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-gf-3)))

(test hijack-defmethod-still-works
  "Hijacked defmethod creates a callable method."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defgeneric sourcery-test-gf-4 (x)))
         (eval '(defmethod sourcery-test-gf-4 ((x integer)) (* x 3)))
         (is (= 15 (funcall 'sourcery-test-gf-4 5))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-gf-4)))

(test hijack-multiple-methods-same-gf
  "Multiple methods on the same GF are stored separately."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defgeneric sourcery-test-gf-5 (x)))
         (eval '(defmethod sourcery-test-gf-5 ((x string)) "str"))
         (eval '(defmethod sourcery-test-gf-5 ((x integer)) "int"))
         (eval '(defmethod sourcery-test-gf-5 ((x list)) "list"))
         (let ((entries (cl-sourcery:get-source 'sourcery-test-gf-5 :method)))
           (is (= 3 (length entries)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-gf-5)))

(test hijack-method-does-not-overwrite-generic
  "defmethod entry doesn't overwrite the defgeneric entry."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defgeneric sourcery-test-gf-6 (x)))
         (eval '(defmethod sourcery-test-gf-6 ((x string)) x))
         (let ((gf-entry (cl-sourcery:get-source 'sourcery-test-gf-6)))
           (is (not (null gf-entry)))
           (is (eq :generic (cl-sourcery:source-entry-type gf-entry))))
         (let ((method-entries (cl-sourcery:get-source 'sourcery-test-gf-6 :method)))
           (is (= 1 (length method-entries)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-gf-6)))

(test hijack-method-with-qualifiers
  "defmethod with :before/:after qualifiers is captured."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defgeneric sourcery-test-gf-7 (x)))
         (eval '(defmethod sourcery-test-gf-7 ((x t)) x))
         (eval '(defmethod sourcery-test-gf-7 :before ((x string))
                  (format t "before: ~a~%" x)))
         (let ((entries (cl-sourcery:get-source 'sourcery-test-gf-7 :method)))
           (is (= 2 (length entries)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-gf-7)))

(test hijack-method-redefine-same-specializer
  "Redefining a method with same specializers overwrites the entry."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defgeneric sourcery-test-gf-8 (x)))
         (eval '(defmethod sourcery-test-gf-8 ((x integer)) 1))
         (eval '(defmethod sourcery-test-gf-8 ((x integer)) 2))
         (let ((entries (cl-sourcery:get-source 'sourcery-test-gf-8 :method)))
           (is (= 1 (length entries)))
           (is (equal '(defmethod sourcery-test-gf-8 ((x integer)) 2)
                      (cl-sourcery:source-entry-form (first entries))))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-gf-8)))

(test hijack-get-all-sources-includes-generic-and-methods
  "get-all-sources returns both the defgeneric and defmethod entries."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defgeneric sourcery-test-gf-9 (x)))
         (eval '(defmethod sourcery-test-gf-9 ((x string)) x))
         (eval '(defmethod sourcery-test-gf-9 ((x integer)) x))
         (let ((all (cl-sourcery:get-all-sources 'sourcery-test-gf-9)))
           ;; 1 generic + 2 methods = 3
           (is (= 3 (length all)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-gf-9)))
