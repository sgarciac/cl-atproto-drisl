;;;; cl-atproto-drisl.asd

(asdf:defsystem #:cl-atproto-drisl
  :description "atproto flavoured DRISL serialization"
  :author "Sergio Garcia <sergio.garcia@gmail.com>"
  :license  "GPL 3.0"
  :version "0.0.1"
  :serial t
  :depends-on (#:flexi-streams)
  :components ((:file "package")
               (:file "utils")
               (:file "cl-atproto-drisl")))
