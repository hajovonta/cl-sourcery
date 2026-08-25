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
   #:source-entry-preamble
   ;; Query API
   #:get-source
   #:get-all-sources
   #:list-definitions
   #:definition-count
   ;; Registry management
   #:clear-registry
   #:remove-source
   ;; Version history
   #:*keep-history*
   #:get-source-history
   ;; Activation
   #:activate
   #:deactivate
   #:active-p
   ;; Scanner
   #:scan-file
   #:scan-file-to-registry
   #:*extra-definition-forms*
   #:*hardened-reader*
   ;; Low-level reader utilities
   #:read-balanced-form
   #:skip-whitespace-and-comments))
