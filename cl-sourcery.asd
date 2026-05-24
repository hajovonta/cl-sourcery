(defsystem #:cl-sourcery
  :description "Transparent source capture for Common Lisp definitions"
  :version "0.2.0"
  :license "MIT"
  :serial t
  :components ((:file "package")
               (:file "compat")
               (:file "registry")
               (:file "reader")
               (:file "hijack")
               (:file "scanner")))
