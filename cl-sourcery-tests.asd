(defsystem #:cl-sourcery-tests
  :depends-on (#:cl-sourcery #:fiveam)
  :serial t
  :components ((:module "tests"
                :components ((:file "package")
                             (:file "suite-registry")
                             (:file "suite-hijack")
                             (:file "suite-methods")))))
