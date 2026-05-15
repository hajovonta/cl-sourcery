(in-package #:cl-sourcery-tests)

(def-suite :defclass :in :cl-sourcery
  :description "defclass hijack tests")

(in-suite :defclass)

(test hijack-captures-defclass
  "After activate, defclass captures source in registry."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defclass sourcery-test-cls-1 ()
                  ((name :initarg :name :accessor cls1-name))))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-cls-1)))
           (is (not (null entry)))
           (is (equal '(defclass sourcery-test-cls-1 ()
                         ((name :initarg :name :accessor cls1-name)))
                      (cl-sourcery:source-entry-form entry)))
           (is (eq :class (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)))

(test hijack-defclass-still-works
  "Hijacked defclass creates a usable class."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defclass sourcery-test-cls-2 ()
                  ((value :initarg :value :reader cls2-value))))
         (let ((obj (eval '(make-instance 'sourcery-test-cls-2 :value 42))))
           (is (= 42 (eval `(cls2-value ,obj))))))
    (cl-sourcery:deactivate)))

(test hijack-defclass-with-superclasses
  "defclass with superclasses is captured correctly."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defclass sourcery-test-cls-base () ()))
         (eval '(defclass sourcery-test-cls-child (sourcery-test-cls-base)
                  ((x :initarg :x))))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-cls-child)))
           (is (equal '(defclass sourcery-test-cls-child (sourcery-test-cls-base)
                         ((x :initarg :x)))
                      (cl-sourcery:source-entry-form entry)))))
    (cl-sourcery:deactivate)))

(test hijack-defclass-with-options
  "defclass with metaclass and documentation is captured."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defclass sourcery-test-cls-3 ()
                  ((slot1 :initform nil))
                  (:documentation "A documented class")))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-cls-3)))
           (is (equal '(defclass sourcery-test-cls-3 ()
                         ((slot1 :initform nil))
                         (:documentation "A documented class"))
                      (cl-sourcery:source-entry-form entry)))))
    (cl-sourcery:deactivate)))

(test hijack-defclass-redefine-overwrites
  "Redefining a class overwrites the registry entry."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defclass sourcery-test-cls-4 () ((a :initform 1))))
         (eval '(defclass sourcery-test-cls-4 () ((b :initform 2))))
         (let ((entry (cl-sourcery:get-source 'sourcery-test-cls-4)))
           (is (equal '(defclass sourcery-test-cls-4 () ((b :initform 2)))
                      (cl-sourcery:source-entry-form entry)))))
    (cl-sourcery:deactivate)))

(test hijack-defclass-listed-by-type
  "defclass entries appear in list-definitions filtered by :class."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate)
  (unwind-protect
       (progn
         (eval '(defclass sourcery-test-cls-5 () ()))
         (eval '(defun sourcery-test-fn-cls () nil))
         (is (= 1 (length (cl-sourcery:list-definitions :class))))
         (is (= 1 (length (cl-sourcery:list-definitions :function)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'sourcery-test-fn-cls)))
