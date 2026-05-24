(defpackage #:cl-sourcery
  (:use #:cl)
  (:export
   ;; Entry struct accessors
   #:source-entry
   #:source-entry-form
   #:source-entry-timestamp
   #:source-entry-package
   #:source-entry-file
   #:source-entry-type
   #:source-entry-text
   ;; Query API
   #:get-source
   #:get-all-sources
   #:list-definitions
   #:definition-count
   ;; Registry management
   #:clear-registry
   #:remove-source
   ;; Activation
   #:activate
   #:deactivate
   #:active-p
   ;; Scanner
   #:scan-file
   #:scan-file-to-registry))
