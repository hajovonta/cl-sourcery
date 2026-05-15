(in-package #:cl-sourcery-tests)

(def-suite :registry :in :cl-sourcery
  :description "Source registry storage and query tests")

(in-suite :registry)

;;; --- register-source and get-source ---

(test register-and-retrieve-function
  "Registering a function source and retrieving it."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source 'foo '(defun foo (x) (+ x 1)) :function)
  (let ((entry (cl-sourcery:get-source 'foo)))
    (is (not (null entry)))
    (is (equal '(defun foo (x) (+ x 1))
               (cl-sourcery:source-entry-form entry)))
    (is (eq :function (cl-sourcery:source-entry-type entry)))
    (is (stringp (cl-sourcery:source-entry-package entry)))
    (is (integerp (cl-sourcery:source-entry-timestamp entry)))))

(test register-and-retrieve-macro
  "Registering a macro source."
  (cl-sourcery:clear-registry)
  (let ((form '(defmacro my-mac (x) (list 'quote x))))
    (cl-sourcery::register-source 'my-mac form :macro)
    (let ((entry (cl-sourcery:get-source 'my-mac)))
      (is (not (null entry)))
      (is (equal form (cl-sourcery:source-entry-form entry)))
      (is (eq :macro (cl-sourcery:source-entry-type entry))))))

(test register-and-retrieve-variable
  "Registering defvar and defparameter sources."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source '*my-var* '(defvar *my-var* 42 "A var") :variable)
  (cl-sourcery::register-source '*my-param* '(defparameter *my-param* "hello") :parameter)
  (let ((var-entry (cl-sourcery:get-source '*my-var*))
        (param-entry (cl-sourcery:get-source '*my-param*)))
    (is (not (null var-entry)))
    (is (eq :variable (cl-sourcery:source-entry-type var-entry)))
    (is (not (null param-entry)))
    (is (eq :parameter (cl-sourcery:source-entry-type param-entry)))))

(test get-source-returns-nil-for-unknown
  "get-source returns NIL for unregistered symbols."
  (cl-sourcery:clear-registry)
  (is (null (cl-sourcery:get-source 'nonexistent-symbol))))

(test register-overwrites-existing
  "Registering the same symbol again overwrites the previous entry."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source 'bar '(defun bar () 1) :function)
  (cl-sourcery::register-source 'bar '(defun bar () 2) :function)
  (let ((entry (cl-sourcery:get-source 'bar)))
    (is (equal '(defun bar () 2) (cl-sourcery:source-entry-form entry)))))

;;; --- Metadata ---

(test timestamp-is-recorded
  "Timestamp is a recent universal-time."
  (cl-sourcery:clear-registry)
  (let ((before (get-universal-time)))
    (cl-sourcery::register-source 'ts-test '(defun ts-test () nil) :function)
    (let* ((entry (cl-sourcery:get-source 'ts-test))
           (ts (cl-sourcery:source-entry-timestamp entry)))
      (is (>= ts before))
      (is (<= ts (get-universal-time))))))

(test package-is-recorded
  "Package name at definition time is captured."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source 'pkg-test '(defun pkg-test () nil) :function)
  (let ((entry (cl-sourcery:get-source 'pkg-test)))
    (is (string= (package-name *package*)
                 (cl-sourcery:source-entry-package entry)))))

;;; --- Methods ---

(test register-method-entries
  "Methods are keyed by (name . specializers)."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source
   (cl-sourcery::method-key 'greet '(string))
   '(defmethod greet ((x string)) (format nil "Hello ~a" x))
   :method)
  (cl-sourcery::register-source
   (cl-sourcery::method-key 'greet '(integer))
   '(defmethod greet ((x integer)) (format nil "Hi ~d" x))
   :method)
  ;; get-source with :method type returns list
  (let ((entries (cl-sourcery:get-source 'greet :method)))
    (is (= 2 (length entries)))
    (is (every (lambda (e) (eq :method (cl-sourcery:source-entry-type e)))
               entries))))

(test method-entries-independent-of-function
  "A method entry doesn't interfere with a same-named function entry."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source 'dual '(defun dual () "fn") :function)
  (cl-sourcery::register-source
   (cl-sourcery::method-key 'dual '(string))
   '(defmethod dual ((x string)) "method")
   :method)
  (let ((fn-entry (cl-sourcery:get-source 'dual))
        (method-entries (cl-sourcery:get-source 'dual :method)))
    (is (equal '(defun dual () "fn") (cl-sourcery:source-entry-form fn-entry)))
    (is (= 1 (length method-entries)))))

;;; --- get-all-sources ---

(test get-all-sources-combines-types
  "get-all-sources returns function + method entries for same symbol."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source 'multi '(defun multi () nil) :function)
  (cl-sourcery::register-source
   (cl-sourcery::method-key 'multi '(string))
   '(defmethod multi ((x string)) nil)
   :method)
  (let ((all (cl-sourcery:get-all-sources 'multi)))
    (is (= 2 (length all)))))

(test get-all-sources-empty
  "get-all-sources returns empty list for unknown symbol."
  (cl-sourcery:clear-registry)
  (is (null (cl-sourcery:get-all-sources 'ghost))))

;;; --- list-definitions ---

(test list-definitions-all
  "list-definitions returns all keys."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source 'a '(defun a () nil) :function)
  (cl-sourcery::register-source 'b '(defvar b 1) :variable)
  (cl-sourcery::register-source
   (cl-sourcery::method-key 'c '(string))
   '(defmethod c ((x string)) nil)
   :method)
  (is (= 3 (length (cl-sourcery:list-definitions)))))

(test list-definitions-filtered-by-type
  "list-definitions with type filter."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source 'f1 '(defun f1 () nil) :function)
  (cl-sourcery::register-source 'f2 '(defun f2 () nil) :function)
  (cl-sourcery::register-source 'v1 '(defvar v1 nil) :variable)
  (is (= 2 (length (cl-sourcery:list-definitions :function))))
  (is (= 1 (length (cl-sourcery:list-definitions :variable))))
  (is (= 0 (length (cl-sourcery:list-definitions :macro)))))

;;; --- definition-count ---

(test definition-count-tracks-entries
  "definition-count reflects registry size."
  (cl-sourcery:clear-registry)
  (is (= 0 (cl-sourcery:definition-count)))
  (cl-sourcery::register-source 'x '(defun x () nil) :function)
  (is (= 1 (cl-sourcery:definition-count)))
  (cl-sourcery::register-source 'y '(defvar y 1) :variable)
  (is (= 2 (cl-sourcery:definition-count))))

;;; --- clear-registry ---

(test clear-registry-empties-all
  "clear-registry removes everything."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source 'z '(defun z () nil) :function)
  (cl-sourcery::register-source
   (cl-sourcery::method-key 'z '(t))
   '(defmethod z ((x t)) nil)
   :method)
  (is (= 2 (cl-sourcery:definition-count)))
  (cl-sourcery:clear-registry)
  (is (= 0 (cl-sourcery:definition-count)))
  (is (null (cl-sourcery:get-source 'z))))

;;; --- remove-source ---

(test remove-source-function
  "remove-source removes a function entry."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source 'rm-fn '(defun rm-fn () nil) :function)
  (is (cl-sourcery:remove-source 'rm-fn))
  (is (null (cl-sourcery:get-source 'rm-fn))))

(test remove-source-methods
  "remove-source with :method removes all method entries for that symbol."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source
   (cl-sourcery::method-key 'rm-m '(string))
   '(defmethod rm-m ((x string)) nil)
   :method)
  (cl-sourcery::register-source
   (cl-sourcery::method-key 'rm-m '(integer))
   '(defmethod rm-m ((x integer)) nil)
   :method)
  (is (= 2 (length (cl-sourcery:get-source 'rm-m :method))))
  (is (cl-sourcery:remove-source 'rm-m :method))
  (is (null (cl-sourcery:get-source 'rm-m :method))))

(test remove-source-returns-nil-for-unknown
  "remove-source returns NIL if nothing was removed."
  (cl-sourcery:clear-registry)
  (is (not (cl-sourcery:remove-source 'never-defined))))

(test remove-source-does-not-affect-other-types
  "Removing a function entry doesn't remove method entries for same symbol."
  (cl-sourcery:clear-registry)
  (cl-sourcery::register-source 'mixed '(defun mixed () nil) :function)
  (cl-sourcery::register-source
   (cl-sourcery::method-key 'mixed '(string))
   '(defmethod mixed ((x string)) nil)
   :method)
  (cl-sourcery:remove-source 'mixed)
  (is (null (cl-sourcery:get-source 'mixed)))
  (is (= 1 (length (cl-sourcery:get-source 'mixed :method)))))
