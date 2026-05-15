(defsystem #:cl-sourcery
  :description "Transparent source capture for Common Lisp definitions"
  :version "0.1.0"
  :license "MIT"
  :serial t
  :components ((:file "package")
               (:file "registry")
               (:file "hijack")))
