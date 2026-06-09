(in-package #:cl-sourcery-tests)

(def-suite :conforming-mode :in :cl-sourcery
  :description "Conforming *macroexpand-hook* mode tests")

(in-suite :conforming-mode)

;;; --- Activation ---

(test conforming-activate-sets-active
  "activate :mode :conforming sets active-p."
  (cl-sourcery:deactivate)
  (cl-sourcery:activate :mode :conforming)
  (is (cl-sourcery:active-p))
  (cl-sourcery:deactivate))

(test conforming-deactivate-restores-hook
  "deactivate restores the previous *macroexpand-hook*."
  (let ((original-hook *macroexpand-hook*))
    (cl-sourcery:activate :mode :conforming)
    (cl-sourcery:deactivate)
    (is (eq original-hook *macroexpand-hook*))))

;;; --- Capture ---

(test conforming-captures-defun
  "Conforming mode captures defun source."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate :mode :conforming)
  (unwind-protect
       (progn
         (eval '(defun conforming-test-fn-1 (x) (+ x 1)))
         (let ((entry (cl-sourcery:get-source 'conforming-test-fn-1)))
           (is (not (null entry)))
           (is (equal '(defun conforming-test-fn-1 (x) (+ x 1))
                      (cl-sourcery:source-entry-form entry)))
           (is (eq :function (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'conforming-test-fn-1)))

(test conforming-defun-still-works
  "Conforming mode defun still creates a working function."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate :mode :conforming)
  (unwind-protect
       (progn
         (eval '(defun conforming-test-fn-2 (x) (* x 3)))
         (is (= 15 (funcall 'conforming-test-fn-2 5))))
    (cl-sourcery:deactivate)
    (fmakunbound 'conforming-test-fn-2)))

(test conforming-captures-defmacro
  "Conforming mode captures defmacro."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate :mode :conforming)
  (unwind-protect
       (progn
         (eval '(defmacro conforming-test-mac (x) (list '+ x 1)))
         (let ((entry (cl-sourcery:get-source 'conforming-test-mac)))
           (is (not (null entry)))
           (is (eq :macro (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'conforming-test-mac)))

(test conforming-captures-defvar
  "Conforming mode captures defvar."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate :mode :conforming)
  (unwind-protect
       (progn
         (eval '(defvar *conforming-test-var* 42))
         (let ((entry (cl-sourcery:get-source '*conforming-test-var*)))
           (is (not (null entry)))
           (is (eq :variable (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)
    (makunbound '*conforming-test-var*)))

(test conforming-captures-defclass
  "Conforming mode captures defclass."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate :mode :conforming)
  (unwind-protect
       (progn
         (eval '(defclass conforming-test-cls () ((x :initarg :x))))
         (let ((entry (cl-sourcery:get-source 'conforming-test-cls)))
           (is (not (null entry)))
           (is (eq :class (cl-sourcery:source-entry-type entry)))))
    (cl-sourcery:deactivate)))

(test conforming-captures-text
  "Conforming mode captures raw source text via readtable."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate :mode :conforming)
  (unwind-protect
       (let ((source "(defun conforming-text-test (a b)
  ;; add them
  (+ a b))"))
         (eval (read-from-string source))
         (let ((entry (cl-sourcery:get-source 'conforming-text-test)))
           (is (not (null entry)))
           (is (string= source (cl-sourcery:source-entry-text entry)))))
    (cl-sourcery:deactivate)
    (fmakunbound 'conforming-text-test)))

(test conforming-deactivate-stops-capture
  "After deactivate, definitions are no longer captured."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate :mode :conforming)
  (cl-sourcery:deactivate)
  (eval '(defun conforming-no-capture () nil))
  (is (null (cl-sourcery:get-source 'conforming-no-capture)))
  (fmakunbound 'conforming-no-capture))

(test conforming-no-double-registration
  "Nested macroexpansions don't cause double registration."
  (cl-sourcery:clear-registry)
  (cl-sourcery:activate :mode :conforming)
  (unwind-protect
       (progn
         ;; defun expands internally — should only register once
         (eval '(defun conforming-no-dupe () (when t :ok)))
         (let ((cl-sourcery:*keep-history* t))
           ;; Re-register check: only 1 entry
           (is (= 1 (length (cl-sourcery:get-source-history 'conforming-no-dupe))))))
    (cl-sourcery:deactivate)
    (fmakunbound 'conforming-no-dupe)))
