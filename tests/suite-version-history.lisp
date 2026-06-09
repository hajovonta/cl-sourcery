(in-package #:cl-sourcery-tests)

(def-suite :version-history :in :cl-sourcery
  :description "Version history tests")

(in-suite :version-history)

(test history-disabled-by-default
  "Without *keep-history*, register-source overwrites."
  (cl-sourcery:clear-registry)
  (let ((cl-sourcery:*keep-history* nil))
    (cl-sourcery::register-source 'vh-fn '(defun vh-fn () 1) :function)
    (cl-sourcery::register-source 'vh-fn '(defun vh-fn () 2) :function)
    (is (= 1 (cl-sourcery:definition-count)))
    (is (equal '(defun vh-fn () 2)
               (cl-sourcery:source-entry-form (cl-sourcery:get-source 'vh-fn))))))

(test history-enabled-keeps-versions
  "With *keep-history* T, multiple definitions are stored."
  (cl-sourcery:clear-registry)
  (let ((cl-sourcery:*keep-history* t))
    (cl-sourcery::register-source 'vh-fn2 '(defun vh-fn2 () 1) :function)
    (cl-sourcery::register-source 'vh-fn2 '(defun vh-fn2 () 2) :function)
    (let ((history (cl-sourcery:get-source-history 'vh-fn2)))
      (is (= 2 (length history)))
      (is (equal '(defun vh-fn2 () 2)
                 (cl-sourcery:source-entry-form (first history))))
      (is (equal '(defun vh-fn2 () 1)
                 (cl-sourcery:source-entry-form (second history)))))))

(test get-source-returns-latest-with-history
  "get-source returns latest even with history enabled."
  (cl-sourcery:clear-registry)
  (let ((cl-sourcery:*keep-history* t))
    (cl-sourcery::register-source 'vh-fn3 '(defun vh-fn3 () 1) :function)
    (cl-sourcery::register-source 'vh-fn3 '(defun vh-fn3 () 2) :function)
    (cl-sourcery::register-source 'vh-fn3 '(defun vh-fn3 () 3) :function)
    (is (equal '(defun vh-fn3 () 3)
               (cl-sourcery:source-entry-form (cl-sourcery:get-source 'vh-fn3))))))

(test history-empty-for-unknown
  "get-source-history returns NIL for unknown symbols."
  (cl-sourcery:clear-registry)
  (is (null (cl-sourcery:get-source-history 'nonexistent))))

(test history-with-hijack
  "Version history works with hijack active."
  (cl-sourcery:clear-registry)
  (let ((cl-sourcery:*keep-history* t))
    (cl-sourcery:activate)
    (unwind-protect
         (progn
           (eval '(defun vh-hijack-test () :v1))
           (eval '(defun vh-hijack-test () :v2))
           (let ((history (cl-sourcery:get-source-history 'vh-hijack-test)))
             (is (= 2 (length history)))
             (is (eq :v2 (funcall 'vh-hijack-test)))))
      (cl-sourcery:deactivate)
      (fmakunbound 'vh-hijack-test))))

(test clear-registry-clears-history
  "clear-registry removes all history."
  (cl-sourcery:clear-registry)
  (let ((cl-sourcery:*keep-history* t))
    (cl-sourcery::register-source 'vh-clr '(defun vh-clr () 1) :function)
    (cl-sourcery::register-source 'vh-clr '(defun vh-clr () 2) :function)
    (cl-sourcery:clear-registry)
    (is (null (cl-sourcery:get-source-history 'vh-clr)))
    (is (= 0 (cl-sourcery:definition-count)))))

(test remove-source-removes-all-history
  "remove-source removes all versions."
  (cl-sourcery:clear-registry)
  (let ((cl-sourcery:*keep-history* t))
    (cl-sourcery::register-source 'vh-rm '(defun vh-rm () 1) :function)
    (cl-sourcery::register-source 'vh-rm '(defun vh-rm () 2) :function)
    (is (cl-sourcery:remove-source 'vh-rm))
    (is (null (cl-sourcery:get-source 'vh-rm)))
    (is (null (cl-sourcery:get-source-history 'vh-rm)))))

(test definition-count-counts-keys-not-versions
  "definition-count counts keys, not individual versions."
  (cl-sourcery:clear-registry)
  (let ((cl-sourcery:*keep-history* t))
    (cl-sourcery::register-source 'vh-c1 '(defun vh-c1 () 1) :function)
    (cl-sourcery::register-source 'vh-c1 '(defun vh-c1 () 2) :function)
    (cl-sourcery::register-source 'vh-c2 '(defun vh-c2 () 1) :function)
    (is (= 2 (cl-sourcery:definition-count)))))
